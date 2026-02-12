package com.example.Spot.order.application.service;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

import com.example.Spot.global.feign.PaymentClient;
import com.example.Spot.global.feign.StoreClient;
import com.example.Spot.global.feign.dto.MenuOptionResponse;
import com.example.Spot.global.feign.dto.MenuResponse;
import com.example.Spot.global.feign.dto.PaymentCancelRequest;
import com.example.Spot.global.feign.dto.PaymentResponse;
import com.example.Spot.global.feign.dto.StoreResponse;
import com.example.Spot.order.domain.entity.OrderEntity;
import com.example.Spot.order.domain.entity.OrderItemEntity;
import com.example.Spot.order.domain.entity.OrderItemOptionEntity;
import com.example.Spot.order.domain.enums.CancelledBy;
import com.example.Spot.order.domain.enums.OrderStatus;
import com.example.Spot.order.domain.exception.DuplicateOrderException;
import com.example.Spot.order.domain.repository.OrderItemOptionRepository;
import com.example.Spot.order.domain.repository.OrderRepository;
import com.example.Spot.order.infrastructure.aop.OrderStatusChange;
import com.example.Spot.order.infrastructure.aop.OrderValidationContext;
import com.example.Spot.order.infrastructure.aop.StoreOwnershipRequired;
import com.example.Spot.order.infrastructure.aop.ValidateStoreAndMenu;
import com.example.Spot.order.infrastructure.producer.OrderEventProducer;
import com.example.Spot.order.infrastructure.temporal.config.OrderConstants;
import com.example.Spot.order.infrastructure.temporal.workflow.OrderWorkflow;
import com.example.Spot.order.presentation.dto.request.OrderCreateRequestDto;
import com.example.Spot.order.presentation.dto.request.OrderItemOptionRequestDto;
import com.example.Spot.order.presentation.dto.request.OrderItemRequestDto;
import com.example.Spot.order.presentation.dto.response.OrderResponseDto;
import com.example.Spot.order.presentation.dto.response.OrderStatsResponseDto;

import io.github.resilience4j.bulkhead.annotation.Bulkhead;
import io.github.resilience4j.circuitbreaker.annotation.CircuitBreaker;
import io.github.resilience4j.retry.annotation.Retry;
import io.temporal.client.WorkflowClient;
import io.temporal.client.WorkflowOptions;
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

        StoreResponse store = OrderValidationContext.getStoreResponse();

        checkDuplicateOrder(userId, store.getId(), requestDto);

        String orderNumber = generateOrderNumber();
        OrderEntity order = OrderEntity.builder()
                .storeId(store.getId())
                .userId(userId)
                .orderNumber(orderNumber)
                .pickupTime(requestDto.getPickupTime())
                .needDisposables(requestDto.getNeedDisposables())
                .request(requestDto.getRequest())
                .build();

        for (OrderItemRequestDto itemDto : requestDto.getOrderItems()) {
            MenuResponse menu = OrderValidationContext.getMenuResponse(itemDto.getMenuId());

            OrderItemEntity orderItem = OrderItemEntity.builder()
                    .menuId(menu.getId())
                    .menuName(menu.getName())
                    .menuPrice(BigDecimal.valueOf(menu.getPrice()))
                    .quantity(itemDto.getQuantity())
                    .build();

            for (OrderItemOptionRequestDto optionDto : itemDto.getOptions()) {
                MenuOptionResponse menuOption = OrderValidationContext.getMenuOptionResponse(optionDto.getMenuOptionId());

                OrderItemOptionEntity orderItemOption = OrderItemOptionEntity.builder()
                        .menuOptionId(menuOption.getId())
                        .optionName(menuOption.getName())
                        .optionDetail(menuOption.getDetail())
                        .optionPrice(BigDecimal.valueOf(menuOption.getPrice()))
                        .build();

                orderItem.addOrderItemOption(orderItemOption);
            }

            order.addOrderItem(orderItem);
        }

        OrderEntity savedOrder = orderRepository.save(order);
        OrderResponseDto responseDto = OrderResponseDto.from(savedOrder);

        orderEventProducer.reserveOrderCreated(
                savedOrder.getId(),
                userId,
                responseDto.getTotalAmount().longValue()
        );

        OrderWorkflow workflow = workflowClient.newWorkflowStub(OrderWorkflow.class,
                WorkflowOptions.newBuilder()
                        .setWorkflowId(savedOrder.getId().toString())
                        .setTaskQueue(OrderConstants.ORDER_TASK_QUEUE)
                        .build());

        TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
            @Override
            public void afterCommit() {
                WorkflowClient.start(workflow::processOrder, savedOrder.getId());
            }
        });
        
        return responseDto;
    }


    // *********** //
    // 주문 상태 변경 //
    // *********** //
    @Override
    @Transactional
    @OrderStatusChange("ACCEPT")
    public OrderResponseDto acceptOrder(UUID orderId, Integer estimatedTime) {
        OrderEntity order = OrderValidationContext.getCurrentOrder();
        order.acceptOrder(estimatedTime);
        
        // 주문 수락 이벤트 발행
        orderEventProducer.reserveOrderAccepted(order.getUserId(), order.getId(), estimatedTime);
        sendSignalToWorkflow(orderId, OrderStatus.ACCEPTED);
        
        return OrderResponseDto.from(order);
    }

    @Override
    @Transactional
    @OrderStatusChange("REJECT")
    public OrderResponseDto rejectOrder(UUID orderId, String reason) {
        
        OrderEntity order = OrderValidationContext.getCurrentOrder();
        order.initiateCancel(reason, null);
        orderEventProducer.reserveOrderCancelled(order.getId(), reason);
        sendSignalToWorkflow(orderId, OrderStatus.CANCEL_PENDING);
        log.info("주문 거절 처리 시작 (환불 대기): orderId={}, reason={}", orderId, reason);
        
        return OrderResponseDto.from(order);
    }

    @Override
    @Transactional
    @OrderStatusChange("COOKING")
    public OrderResponseDto startCooking(UUID orderId) {
        
        OrderEntity order = OrderValidationContext.getCurrentOrder();
        order.startCooking();
        sendSignalToWorkflow(orderId, OrderStatus.COOKING);
        
        return OrderResponseDto.from(order);
    }

    @Override
    @Transactional
    @OrderStatusChange("READY")
    public OrderResponseDto readyForPickup(UUID orderId) {
        
        OrderEntity order = OrderValidationContext.getCurrentOrder();
        order.readyForPickup();
        sendSignalToWorkflow(orderId, OrderStatus.READY);
        
        return OrderResponseDto.from(order);
    }

    @Override
    @Transactional
    @OrderStatusChange("COMPLETE")
    public OrderResponseDto completeOrder(UUID orderId) {
        
        OrderEntity order = OrderValidationContext.getCurrentOrder();
        order.completeOrder();
        sendSignalToWorkflow(orderId, OrderStatus.COMPLETED);
        
        return OrderResponseDto.from(order);
    }
    
    // ******* //
    // 주문 취소 //
    // ******* //
    @Override
    @Transactional
    public void completeOrderCancellation(UUID orderId) {
        OrderEntity order = orderRepository.findByIdWithLock(orderId)
                .orElseThrow(() -> new IllegalArgumentException("존재하지 않는 주문입니다."));
        
        if (order.getOrderStatus() == OrderStatus.CANCEL_PENDING) {
            order.finalizeCancel();
            log.info("[보상 트랜잭션 완료] 주문 ID {} 가 최종 확정되었습니다.", orderId);
            sendSignalToWorkflow(orderId, order.getOrderStatus());
        } else {
            log.warn("[무시됨] 주문 ID {} 는 현재 취소 대기 상태가 아닙니다. (현재 상태: {})",
                    orderId, order.getOrderStatus());
        }
    }

    @Override
    @Transactional
    public OrderResponseDto customerCancelOrder(UUID orderId, String reason) {
        OrderEntity order = orderRepository.findByIdWithLock(orderId)
                .orElseThrow(() -> new IllegalArgumentException("존재하지 않는 주문입니다."));

        order.initiateCancel(reason, CancelledBy.CUSTOMER);
        // 주문 취소(거절) 이벤트 발행
        orderEventProducer.reserveOrderCancelled(order.getId(), reason);
        sendSignalToWorkflow(orderId, OrderStatus.CANCEL_PENDING);
        log.info("고객에 의한 취소 처리 시작 (환불 대기): orderId={}, reason={}", orderId, reason);

        // 결제 취소 처리 (Payment 서비스 호출) - 비동기 전환으로 인한 주석처리: 추후 삭제 afterDelete
        // cancelPaymentIfExists(orderId, "고객 주문 취소: " + reason);

        return OrderResponseDto.from(order);
    }

    @Override
    @Transactional
    public OrderResponseDto storeCancelOrder(UUID orderId, String reason) {
        OrderEntity order = orderRepository.findByIdWithLock(orderId)
                .orElseThrow(() -> new IllegalArgumentException("존재하지 않는 주문입니다."));

        order.initiateCancel(reason, CancelledBy.STORE);
        // 주문 취소(거절) 이벤트 발행
        orderEventProducer.reserveOrderCancelled(order.getId(), reason);
        sendSignalToWorkflow(orderId, OrderStatus.CANCEL_PENDING);
        log.info("가게에 의한 취소 처리 시작 (환불 대기): orderId={}, reason={}", orderId, reason);

        return OrderResponseDto.from(order);
    }

    @CircuitBreaker(name = "payment_ready_create")
    @Bulkhead(name = "payment_ready_create", type = Bulkhead.Type.SEMAPHORE)
    @Retry(name = "payment_ready_create")
    private void cancelPaymentIfExists(UUID orderId, String cancelReason) {
        try {
            // Payment 서비스에서 결제 정보 조회
            if (!paymentClient.existsActivePaymentByOrderId(orderId)) {
                log.info("주문 ID {}에 대한 결제 정보가 없습니다. 결제 취소를 건너뜁니다.", orderId);
                return;
            }

            PaymentResponse payment = paymentClient.getPaymentByOrderId(orderId);

            log.info("결제 취소 요청 - 결제 ID: {}, 주문 ID: {}, 사유: {}", payment.getId(), orderId, cancelReason);

            // Payment 서비스에 결제 취소 요청
            PaymentCancelRequest cancelRequest = PaymentCancelRequest.builder()
                    .cancelReason(cancelReason)
                    .build();
            paymentClient.cancelPayment(payment.getId(), cancelRequest);

            log.info("결제 취소 완료 - 결제 ID: {}", payment.getId());

        } catch (Exception e) {
            log.error("결제 취소 실패 - 주문 ID: {}, 오류: {}", orderId, e.getMessage(), e);
            throw new RuntimeException("결제 취소 중 오류가 발생했습니다: " + e.getMessage(), e);
        }
    }

    @Override
    @Transactional
    @OrderStatusChange("COMPLETE_PAYMENT")
    public OrderResponseDto completePayment(UUID orderId) {
        OrderEntity order = orderRepository.findByIdWithLock(orderId)
                .orElseThrow(() -> new IllegalArgumentException("존재하지 않는 주문입니다."));
        
        // 멱등성 보장 결제 처리 로직
        if (order.getOrderStatus() == OrderStatus.PENDING ||
            order.getOrderStatus().isFinalStatus()) {
            if (order.getOrderStatus() == OrderStatus.CANCELLED) {
                log.warn("[주문서비스] 이미 취소된 주문에 결제 성공 이벤트 수신. 환불을 예약합니다. orderId={}", orderId);
                orderEventProducer.reserveOrderCancelled(orderId, "타임아웃 이후 결제 성공 발생");
            } else {
                log.info("[멱등성처리] 이미 처리된 주문입니다. 스킵: orderId={}, status={}", orderId, order.getOrderStatus());
            }
            return OrderResponseDto.from(order); 
        }
        
        // 정상 결제 처리 로직
        log.info("결제 성공 이벤트 수신 - 주문 확정 처리 시작: orderId={}", orderId);
        order.completePayment();
        orderEventProducer.reserveOrderPending(order.getStoreId(), order.getId());
        log.info("결제 처리 및 사장님 알림 이벤트 발행 완료: orderId={}", orderId);
        sendSignalToWorkflow(orderId, OrderStatus.PENDING);
        
        return OrderResponseDto.from(order);
    }

    @Override
    @Transactional
    public OrderResponseDto failPayment(UUID orderId) {
        OrderEntity order = orderRepository.findByIdWithLock(orderId)
                .orElseThrow(() -> new IllegalArgumentException("존재하지 않는 주문입니다."));

        if (order.getOrderStatus() == OrderStatus.PAYMENT_FAILED || order.getOrderStatus().isFinalStatus()) {
            log.info("[멱등성 처리] 이미 실패 처리되었거나 최종 상태인 주문입니다. 스킵: orderId={}", orderId);
            return OrderResponseDto.from(order);
        }

        order.failPayment();
        return OrderResponseDto.from(order);
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

    private String generateOrderNumber() {
        String date = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyyMMdd"));
        String datePattern = "ORDER-" + date + "-%";

        Optional<String> lastOrderNumber = orderRepository.findTopOrderNumberByDatePattern(datePattern);

        int sequence = 1;
        if (lastOrderNumber.isPresent()) {
            String lastNumber = lastOrderNumber.get();
            String lastSeq = lastNumber.substring(lastNumber.lastIndexOf('-') + 1);
            sequence = Integer.parseInt(lastSeq) + 1;
        }

        return String.format("ORDER-%s-%04d", date, sequence);
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
    
    private void sendSignalToWorkflow(UUID orderId, OrderStatus status) {
        TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
            @Override
            public void afterCommit() {
                try {
                    OrderWorkflow workflow = workflowClient.newWorkflowStub(
                            OrderWorkflow.class,
                            orderId.toString()
                    );
                    workflow.signalStatusChanged(status);
                    log.info("워크플로우 시그널 전송 성공: orderId={}, status={}", orderId, status);
                } catch (Exception e) {
                    log.error("워크플로우 시그널 전송 실패: orderId={}, status={}", orderId, status, e);
                }
            }
        });
    }
}
