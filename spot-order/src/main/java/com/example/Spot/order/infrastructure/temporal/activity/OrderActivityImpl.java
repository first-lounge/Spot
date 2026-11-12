package com.example.Spot.order.infrastructure.temporal.activity;

import java.util.UUID;

import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import com.example.Spot.order.application.service.OrderCreationService;
import com.example.Spot.order.application.service.OrderNumberCounterService;
import com.example.Spot.order.domain.entity.OrderEntity;
import com.example.Spot.order.domain.enums.CancelledBy;
import com.example.Spot.order.domain.enums.OrderStatus;
import com.example.Spot.order.domain.repository.OrderRepository;
import com.example.Spot.order.infrastructure.producer.OrderEventProducer;
import com.example.Spot.order.infrastructure.temporal.config.OrderConstants;
import com.example.Spot.order.presentation.dto.request.OrderCreateRequestDto;
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
    private final OrderCreationService orderCreationService;
    private final OrderNumberCounterService orderNumberCounterService;

    @Override
    public void createOrderInDb(UUID orderId, Integer userId, OrderCreateRequestDto requestDto, OrderContextDto contextDto) {
        String orderNumber = orderNumberCounterService.issueOrderNumber();
        orderCreationService.saveOrder(orderId, userId, orderNumber, requestDto, contextDto);
    }

    @Override
    public void recordOrderCreationFailure(UUID orderId, Integer userId, OrderCreateRequestDto requestDto, OrderContextDto contextDto) {
        String orderNumber = orderNumberCounterService.issueOrderNumber();
        orderCreationService.saveFailedOrder(orderId, userId, orderNumber, requestDto, contextDto);
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
}
