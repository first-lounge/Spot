package com.example.Spot.order.infrastructure.temporal.activity;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.Optional;
import java.util.UUID;

import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import com.example.Spot.global.feign.dto.MenuOptionResponse;
import com.example.Spot.global.feign.dto.MenuResponse;
import com.example.Spot.order.domain.entity.OrderEntity;
import com.example.Spot.order.domain.entity.OrderItemEntity;
import com.example.Spot.order.domain.entity.OrderItemOptionEntity;
import com.example.Spot.order.domain.enums.CancelledBy;
import com.example.Spot.order.domain.enums.OrderStatus;
import com.example.Spot.order.domain.repository.OrderRepository;
import com.example.Spot.order.infrastructure.producer.OrderEventProducer;
import com.example.Spot.order.infrastructure.temporal.config.OrderConstants;
import com.example.Spot.order.presentation.dto.request.OrderCreateRequestDto;
import com.example.Spot.order.presentation.dto.request.OrderItemOptionRequestDto;
import com.example.Spot.order.presentation.dto.request.OrderItemRequestDto;
import com.example.Spot.order.presentation.dto.response.OrderContextDto;

import io.temporal.spring.boot.ActivityImpl;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

@Slf4j
@Component
@RequiredArgsConstructor
@ActivityImpl(taskQueues = OrderConstants.ORDER_TASK_QUEUE)
public class OrderActivityImpl implements OrderActivity {
    
    private final OrderRepository orderRepository;
    private final OrderEventProducer orderEventProducer;

    @Override
    public void createOrderInDb(UUID orderId, Integer userId, OrderCreateRequestDto requestDto, OrderContextDto contextDto) {
        if (orderRepository.existsById(orderId)) {
            return;
        }

        String orderNumber = generateOrderNumber();
        BigDecimal totalAmount = BigDecimal.ZERO;

        OrderEntity order = OrderEntity.builder()
                .id(orderId)
                .storeId(contextDto.getStore().getId())
                .userId(userId)
                .orderNumber(orderNumber)
                .pickupTime(requestDto.getPickupTime())
                .needDisposables(requestDto.getNeedDisposables())
                .request(requestDto.getRequest())
                .orderStatus(OrderStatus.PAYMENT_PENDING)
                .build();

        for (OrderItemRequestDto itemDto : requestDto.getOrderItems()) {
            MenuResponse menu = contextDto.getMenuMap().get(itemDto.getMenuId());
            BigDecimal itemPrice = BigDecimal.valueOf(menu.getPrice());

            // 총액 합산 로직
            totalAmount = totalAmount.add(itemPrice.multiply(BigDecimal.valueOf(itemDto.getQuantity())));

            OrderItemEntity orderItem = OrderItemEntity.builder()
                    .menuId(menu.getId())
                    .menuName(menu.getName())
                    .menuPrice(itemPrice)
                    .quantity(itemDto.getQuantity())
                    .build();

            for (OrderItemOptionRequestDto optionDto : itemDto.getOptions()) {
                MenuOptionResponse menuOption = contextDto.getOptionMap().get(optionDto.getMenuOptionId());
                BigDecimal optionPrice = BigDecimal.valueOf(menuOption.getPrice());

                // 옵션 총액 합산
                totalAmount = totalAmount.add(optionPrice);

                OrderItemOptionEntity orderItemOption = OrderItemOptionEntity.builder()
                        .menuOptionId(menuOption.getId())
                        .optionName(menuOption.getName())
                        .optionDetail(menuOption.getDetail())
                        .optionPrice(optionPrice)
                        .build();

                orderItem.addOrderItemOption(orderItemOption);
            }
            order.addOrderItem(orderItem);
        }

        orderRepository.save(order);

        orderEventProducer.reserveOrderCreated(
                orderId,
                userId,
                totalAmount.longValue()
        );

        log.info("주문 생성이 완료되었습니다. OrderID: {}, OrderNumber: {}", orderId, orderNumber);
    }
    
    @Override
    @Transactional(propagation = Propagation.REQUIRES_NEW) // 독립적인 트랜잭션 보장
    public void updateOrderStatusInDb(UUID orderId, OrderStatus nextStatus, Integer estimatedTime, String reason, CancelledBy actor) {
        OrderEntity order = orderRepository.findByIdWithLock(orderId)
                .orElseThrow(() -> new IllegalArgumentException("존재하지 않는 주문입니다: " + orderId));
        
        if (!order.getOrderStatus().canTransitionTo(nextStatus)) {
            log.warn("Activity: 유효하지 않은 상태 전환 시도 - current={}, next={}", order.getOrderStatus(), nextStatus);
            return;
        }

        switch (nextStatus) {
            case PENDING -> {
                order.completePayment();
                orderEventProducer.reserveOrderPending(order.getStoreId(), order.getId());
            }
            case ACCEPTED -> {
                order.acceptOrder(estimatedTime);
                orderEventProducer.reserveOrderAccepted(order.getUserId(), order.getId(), estimatedTime);
            }
            case COOKING -> order.startCooking();
            case READY -> order.readyForPickup();
            case COMPLETED -> order.completeOrder();
            case REJECT_PENDING -> {
                order.initiateReject(reason); 
                orderEventProducer.reserveOrderCancelled(order.getId(), reason); // 환불 프로세스 시작
            }
            case CANCEL_PENDING -> {
                order.initiateCancel(reason, actor); 
                orderEventProducer.reserveOrderCancelled(order.getId(), reason); // 환불 프로세스 시작
            }
            default -> log.info("상태 변경: {}", nextStatus);
        }
        
        log.info("Activity: 주문 상태 변경 완료 - orderId={}, changedStatus={}", orderId, order.getOrderStatus());
    }
        
    @Override
    @Transactional
    public OrderStatus getOrderStatus(UUID orderId) {
        return orderRepository.findById(orderId)
                .map(OrderEntity::getOrderStatus)
                .orElse(OrderStatus.CANCELLED);
    }

    @Override
    @Transactional
    public void handlePaymentFailure(UUID orderId) {
        OrderEntity order = orderRepository.findByIdWithLock(orderId)
                .orElseThrow(() -> new IllegalArgumentException("주문 없음: " + orderId));
        order.failPayment();
    }

    @Override
    @Transactional
    public void cancelOrder(UUID orderId, String reason) {
        OrderEntity order = orderRepository.findByIdWithLock(orderId)
                .orElseThrow(() -> new IllegalArgumentException("주문 없음" + orderId));
        
        if (order.getOrderStatus() != OrderStatus.CANCELLED &&
        order.getOrderStatus() != OrderStatus.REJECTED) {
            order.initiateCancel(reason, CancelledBy.SYSTEM);
            orderEventProducer.reserveOrderCancelled(order.getId(), reason);
        }
    }
    
    @Override
    @Transactional
    public void finalizeOrder(UUID orderId) {
        OrderEntity order = orderRepository.findByIdWithLock(orderId)
                .orElseThrow(() -> new IllegalArgumentException("주문 없음: " + orderId));
        
        if (order.getOrderStatus() == OrderStatus.REJECT_PENDING) {
            order.finalizeReject();
            log.info("주문 거절 확정 완료: {}", orderId);
        } else if (order.getOrderStatus() == OrderStatus.CANCEL_PENDING) {
            order.finalizeCancel();
            log.info("주문 취소 확정 완료: {}", orderId);
        }
    }
    
    @Override
    @Transactional
    public void handleRefundTimeout(UUID orderId) {
        OrderEntity order = orderRepository.findByIdWithLock(orderId)
                .orElseThrow(() -> new IllegalArgumentException("주문 없음: " + orderId));
        
        order.markAsRefundError();
        log.error("[환불 타임아웃 발생] 관찰 필요 - OrderID: {}, 현재상태: {}",
                orderId, order.getOrderStatus());
        orderRepository.save(order);
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
}
