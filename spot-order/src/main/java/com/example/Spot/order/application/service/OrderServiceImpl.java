package com.example.Spot.order.application.service;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.Spot.global.feign.MenuClient;
import com.example.Spot.global.feign.PaymentClient;
import com.example.Spot.global.feign.StoreClient;
import com.example.Spot.global.feign.dto.MenuOptionResponse;
import com.example.Spot.global.feign.dto.MenuResponse;
import com.example.Spot.global.feign.dto.StoreResponse;
import com.example.Spot.order.domain.entity.OrderEntity;
import com.example.Spot.order.domain.entity.OrderItemEntity;
import com.example.Spot.order.domain.entity.OrderItemOptionEntity;
import com.example.Spot.order.domain.enums.CancelledBy;
import com.example.Spot.order.domain.enums.OrderStatus;
import com.example.Spot.order.domain.exception.DuplicateOrderException;
import com.example.Spot.order.domain.exception.InvalidOrderStatusTransitionException;
import com.example.Spot.order.domain.repository.OrderItemOptionRepository;
import com.example.Spot.order.domain.repository.OrderRepository;
import com.example.Spot.order.infrastructure.aop.OrderValidationContext;
import com.example.Spot.order.infrastructure.aop.StoreOwnershipRequired;
import com.example.Spot.order.infrastructure.aop.ValidateStoreAndMenu;
import com.example.Spot.order.infrastructure.producer.OrderEventProducer;
import com.example.Spot.order.infrastructure.temporal.config.OrderConstants;
import com.example.Spot.order.infrastructure.temporal.dto.OrderStatusUpdate;
import com.example.Spot.order.infrastructure.temporal.workflow.OrderWorkflow;
import com.example.Spot.order.presentation.dto.request.OrderCreateRequestDto;
import com.example.Spot.order.presentation.dto.request.OrderItemOptionRequestDto;
import com.example.Spot.order.presentation.dto.request.OrderItemRequestDto;
import com.example.Spot.order.presentation.dto.response.OrderContextDto;
import com.example.Spot.order.presentation.dto.response.OrderResponseDto;
import com.example.Spot.order.presentation.dto.response.OrderStatsResponseDto;

import io.temporal.client.WorkflowClient;
import io.temporal.client.WorkflowNotFoundException;
import io.temporal.client.WorkflowOptions;
import jakarta.persistence.EntityNotFoundException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class OrderServiceImpl implements OrderService {

    private final OrderRepository orderRepository;
    private final OrderItemOptionRepository orderItemOptionRepository;
    private final PaymentClient paymentClient;
    private final StoreClient storeClient;
    private final OrderEventProducer orderEventProducer;
    private final WorkflowClient workflowClient;
    private final MenuClient menuClient;

    // ******* //
    // 주문 조회 //
    // ******* //
    @Override
    public OrderResponseDto getOrderById(UUID orderId) {

        OrderEntity order = orderRepository.findByIdWithOrderItems(orderId)
                .orElseThrow(() -> new IllegalArgumentException("존재하지 않는 주문입니다."));

        List<UUID> orderItemIds = order.getOrderItems().stream()
                .map(OrderItemEntity::getId)
                .toList();

        List<OrderItemOptionEntity> options = List.of();
        if (!orderItemIds.isEmpty()) {
            options = orderItemOptionRepository.findByOrderItemIdIn(orderItemIds);
        }

        if (!order.getOrderItems().isEmpty() && !options.isEmpty()) {
            System.out.println("Order의 아이템 주소: " + System.identityHashCode(order.getOrderItems().get(0)));
            System.out.println("옵션이 참조하는 아이템 주소: " + System.identityHashCode(options.get(0).getOrderItem()));
        }

        return OrderResponseDto.from(order);
    }

    @Override
    public OrderResponseDto getOrderByOrderNumber(String orderNumber) {
        OrderEntity order = orderRepository.findByOrderNumber(orderNumber)
                .orElseThrow(() -> new IllegalArgumentException("존재하지 않는 주문입니다."));
        return OrderResponseDto.from(order);
    }

    @Override
    public List<OrderResponseDto> getUserActiveOrders(Integer userId) {
        return orderRepository.findActiveOrdersByUserId(userId).stream()
                .map(OrderResponseDto::from)
                .collect(Collectors.toList());
    }

    @Override
    @StoreOwnershipRequired
    public List<OrderResponseDto> getChefTodayOrders(Integer userId) {
        UUID storeId = OrderValidationContext.getCurrentStoreId();
        LocalDateTime[] range = getDateRange(LocalDateTime.now());
        return orderRepository.findTodayActiveOrdersByStoreId(storeId, range[0], range[1]).stream()
                .map(OrderResponseDto::from)
                .collect(Collectors.toList());
    }

    @Override
    @StoreOwnershipRequired
    public List<OrderResponseDto> getMyStoreActiveOrders(Integer userId) {
        UUID storeId = OrderValidationContext.getCurrentStoreId();
        return orderRepository.findActiveOrdersByStoreId(storeId).stream()
                .map(OrderResponseDto::from)
                .collect(Collectors.toList());
    }

    @Override
    public Page<OrderResponseDto> getUserOrders(
            Integer userId,
            UUID storeId,
            LocalDateTime date,
            OrderStatus status,
            Pageable pageable) {

        LocalDateTime[] range = date != null ? getDateRange(date) : new LocalDateTime[]{null, null};

        Page<OrderEntity> orderPage = orderRepository.findUserOrdersWithFilters(
                userId,
                storeId,
                status,
                range[0],
                range[1],
                pageable);

        fetchOrderItemOptions(orderPage.getContent());
        return orderPage.map(OrderResponseDto::from);
    }

    @Override
    @StoreOwnershipRequired
    public Page<OrderResponseDto> getMyStoreOrders(
            Integer userId,
            Integer customerId,
            LocalDateTime date,
            OrderStatus status,
            Pageable pageable) {

        UUID storeId = OrderValidationContext.getCurrentStoreId();
        LocalDateTime[] range = date != null ? getDateRange(date) : new LocalDateTime[]{null, null};

        Page<OrderEntity> orderPage = orderRepository.findStoreOrdersWithFilters(
                storeId,
                customerId,
                status,
                range[0],
                range[1],
                pageable);

        fetchOrderItemOptions(orderPage.getContent());
        return orderPage.map(OrderResponseDto::from);
    }

    @Override
    public Page<OrderResponseDto> getAllOrders(
            UUID storeId,
            LocalDateTime date,
            OrderStatus status,
            Pageable pageable) {

        LocalDateTime[] range = date != null ? getDateRange(date) : new LocalDateTime[]{null, null};

        Page<OrderEntity> orderPage = orderRepository.findAllOrdersWithFilters(
                storeId,
                status,
                range[0],
                range[1],
                pageable);

        fetchOrderItemOptions(orderPage.getContent());
        return orderPage.map(OrderResponseDto::from);
    }

    private void fetchOrderItemOptions(List<OrderEntity> orders) {
        List<UUID> orderItemIds = orders.stream()
                .flatMap(order -> order.getOrderItems().stream())
                .map(OrderItemEntity::getId)
                .toList();

        if (!orderItemIds.isEmpty()) {
            orderItemOptionRepository.findByOrderItemIdIn(orderItemIds);
        }
    }


    // ******* //
    // 주문 생성 //
    // ******* //
    @Override
    @Transactional
    @ValidateStoreAndMenu
    public OrderResponseDto createOrder(OrderCreateRequestDto requestDto, Integer userId) {
        
        OrderContextDto contextDto = fetchOrderContext(requestDto);
        checkDuplicateOrder(userId, contextDto.getStore().getId(), requestDto);
        UUID orderId = UUID.randomUUID();
        BigDecimal totalAmount = contextDto.calculateTotalAmount(requestDto);
        
        OrderWorkflow workflow = workflowClient.newWorkflowStub(OrderWorkflow.class,
                WorkflowOptions.newBuilder()
                        .setWorkflowId(orderId.toString())
                        .setTaskQueue(OrderConstants.ORDER_TASK_QUEUE)
                        .build());

        
        WorkflowClient.start(workflow::processOrder, orderId, userId, requestDto, contextDto);
        
        return OrderResponseDto.of(orderId, userId, requestDto, contextDto, totalAmount);
    }

    // *********** //
    // 주문 상태 변경 //
    // *********** //
    @Override
    public OrderResponseDto acceptOrder(UUID orderId, Integer estimatedTime) {
        OrderWorkflow workflow = workflowClient.newWorkflowStub(OrderWorkflow.class, orderId.toString());
        workflow.signalStatusChanged(new OrderStatusUpdate(OrderStatus.ACCEPTED, estimatedTime, null, null));
        return OrderResponseDto.fromId(orderId, OrderStatus.ACCEPTED);
    }

    @Override
    @Transactional(readOnly = true)
    public OrderResponseDto rejectOrder(UUID orderId, String reason) {
        OrderEntity order = orderRepository.findById(orderId)
                .orElseThrow(() -> new EntityNotFoundException("주문을 찾을 수 없습니다."));
        if (order.getOrderStatus() != OrderStatus.PENDING) {
            throw new InvalidOrderStatusTransitionException(order.getOrderStatus(), OrderStatus.REJECT_PENDING);
        }
        
        OrderWorkflow workflow = workflowClient.newWorkflowStub(OrderWorkflow.class, orderId.toString());
        workflow.signalStatusChanged(new OrderStatusUpdate(OrderStatus.REJECT_PENDING, null, reason, null));
        return OrderResponseDto.fromId(orderId, OrderStatus.REJECT_PENDING);
    }

    @Override
    public OrderResponseDto startCooking(UUID orderId) {
        sendSignal(orderId, OrderStatus.COOKING);
        return OrderResponseDto.fromId(orderId, OrderStatus.COOKING);
    }

    @Override
    public OrderResponseDto readyForPickup(UUID orderId) {
        sendSignal(orderId, OrderStatus.READY);
        return OrderResponseDto.fromId(orderId, OrderStatus.READY);
    }

    @Override
    public OrderResponseDto completeOrder(UUID orderId) {
        OrderWorkflow workflow = workflowClient.newWorkflowStub(OrderWorkflow.class, orderId.toString());
        workflow.signalStatusChanged(new OrderStatusUpdate(OrderStatus.COMPLETED, null, null, null));
        return OrderResponseDto.fromId(orderId, OrderStatus.COMPLETED);
    }
    
    // ******* //
    // 주문 취소 //
    // ******* //
    @Override
    public OrderResponseDto customerCancelOrder(UUID orderId, String reason) {
        OrderWorkflow workflow = workflowClient.newWorkflowStub(OrderWorkflow.class, orderId.toString());
        workflow.signalStatusChanged(new OrderStatusUpdate(OrderStatus.CANCEL_PENDING, null, reason, CancelledBy.CUSTOMER));
        log.info("고객 취소 시그널 전송 완료: orderId={}, reason={}", orderId, reason);
        return OrderResponseDto.fromId(orderId, OrderStatus.CANCEL_PENDING);
    }

    @Override
    public OrderResponseDto storeCancelOrder(UUID orderId, String reason) {
        OrderWorkflow workflow = workflowClient.newWorkflowStub(OrderWorkflow.class, orderId.toString());
        workflow.signalStatusChanged(new OrderStatusUpdate(OrderStatus.CANCEL_PENDING, null, reason, CancelledBy.STORE));
        log.info("가게 취소 시그널 전송 완료: orderId={}, reason={}", orderId, reason);
        return OrderResponseDto.fromId(orderId, OrderStatus.CANCEL_PENDING);
    }
    
    @Override
    public void completeOrderCancellation(UUID orderId) {
        OrderWorkflow workflow = workflowClient.newWorkflowStub(OrderWorkflow.class, orderId.toString());
        workflow.signalRefundCompleted();
        log.info("환불 완료 시그널 전송 성공: orderId={}", orderId);
    }

    @Override
    public OrderResponseDto completePayment(UUID orderId) {
        try {
            OrderWorkflow workflow = workflowClient.newWorkflowStub(OrderWorkflow.class, orderId.toString());
            workflow.signalStatusChanged(new OrderStatusUpdate(OrderStatus.PENDING, null, null, null));
            log.info("결제 완료 시그널 전송: orderId={}", orderId);
        } catch (WorkflowNotFoundException e) {
            log.warn("이미 종료된 워크플로우입니다. orderId={}", orderId);
        }
        return OrderResponseDto.fromId(orderId, OrderStatus.PENDING);
    }

    @Override
    public OrderResponseDto failPayment(UUID orderId) {
        OrderWorkflow workflow = workflowClient.newWorkflowStub(OrderWorkflow.class, orderId.toString());
        workflow.signalStatusChanged(new OrderStatusUpdate(OrderStatus.PAYMENT_FAILED, null, "결제 승인 거절", null));
        return OrderResponseDto.fromId(orderId, OrderStatus.PAYMENT_FAILED);
    }

    private void checkDuplicateOrder(Integer userId, UUID storeId, OrderCreateRequestDto requestDto) {
        List<OrderEntity> existingOrders = orderRepository
                .findActiveOrdersByUserAndStoreAndPickupTime(userId, storeId, requestDto.getPickupTime());

        if (existingOrders.isEmpty()) {
            return;
        }

        Set<String> newOrderItemKeys = requestDto.getOrderItems().stream()
                .map(item -> item.getMenuId() + ":" + item.getQuantity())
                .collect(Collectors.toSet());

        for (OrderEntity existingOrder : existingOrders) {
            Set<String> existingItemKeys = existingOrder.getOrderItems().stream()
                    .map(item -> item.getMenuId() + ":" + item.getQuantity())
                    .collect(Collectors.toSet());

            if (newOrderItemKeys.equals(existingItemKeys)) {
                log.warn("중복 주문 감지: userId={}, storeId={}, pickupTime={}, 기존 주문번호={}",
                        userId, storeId, requestDto.getPickupTime(), existingOrder.getOrderNumber());
                throw new DuplicateOrderException();
            }
        }
    }
    
    private LocalDateTime[] getDateRange(LocalDateTime date) {
        LocalDateTime startOfDay = date.toLocalDate().atStartOfDay();
        LocalDateTime endOfDay = date.toLocalDate().atTime(23, 59, 59);
        return new LocalDateTime[] { startOfDay, endOfDay };
    }

    @Override
    public OrderStatsResponseDto getOrderStats() {
        List<OrderEntity> allOrders = orderRepository.findAll();

        long totalOrders = allOrders.size();

        BigDecimal totalRevenue = allOrders.stream()
                .flatMap(order -> order.getOrderItems().stream())
                .map(item -> item.getMenuPrice().multiply(BigDecimal.valueOf(item.getQuantity())))
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        Map<String, Long> statusCounts = allOrders.stream()
                .collect(Collectors.groupingBy(
                        order -> order.getOrderStatus().name(),
                        Collectors.counting()
                ));

        List<OrderStatsResponseDto.OrderStatusStats> orderStatusStats = statusCounts.entrySet().stream()
                .map(entry -> OrderStatsResponseDto.OrderStatusStats.builder()
                        .status(entry.getKey())
                        .count(entry.getValue())
                        .build())
                .collect(Collectors.toList());

        return OrderStatsResponseDto.builder()
                .totalOrders(totalOrders)
                .totalRevenue(totalRevenue)
                .orderStatusStats(orderStatusStats)
                .build();
    }
    
    private void sendSignal(UUID orderId, OrderStatus status) {
        OrderWorkflow workflow = workflowClient.newWorkflowStub(OrderWorkflow.class, orderId.toString());
        workflow.signalStatusChanged(new OrderStatusUpdate(status, null, null, null));
        log.info("시그널 전송 완료: orderId={}, status={}", orderId, status);
    }
    
    private OrderContextDto fetchOrderContext(OrderCreateRequestDto requestDto) {
        StoreResponse store = storeClient.getStoreById(requestDto.getStoreId());
        if (store == null) {
            throw new IllegalArgumentException("존재하지 않는 가게입니다.");
        }
        
        Map<UUID, MenuResponse> menuMap = new HashMap<>();
        Map<UUID, MenuOptionResponse> optionMap = new HashMap<>();
        
        for (OrderItemRequestDto itemDto : requestDto.getOrderItems()) {
            MenuResponse menu = menuClient.getMenuById(itemDto.getMenuId());
            if (menu == null || menu.isHidden() || menu.isDeleted()) {
                throw new IllegalArgumentException("판매 불가 메뉴입니다: " + itemDto.getMenuId());
            }
            menuMap.put(itemDto.getMenuId(), menu);

            for (OrderItemOptionRequestDto optionDto : itemDto.getOptions()) {
                MenuOptionResponse option = menuClient.getMenuOptionById(optionDto.getMenuOptionId());
                if (option == null || option.isDeleted()) {
                    throw new IllegalArgumentException("판매 불가 옵션입니다.");
                }
                optionMap.put(optionDto.getMenuOptionId(), option);
            }
        }
            return OrderContextDto.builder()
                    .store(store)
                    .menuMap(menuMap)
                    .optionMap(optionMap)
                    .build();
    }
}
