package com.example.Spot.order.infrastructure.temporal.activity;

import java.util.UUID;

import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import com.example.Spot.order.domain.entity.OrderEntity;
import com.example.Spot.order.domain.enums.OrderStatus;
import com.example.Spot.order.domain.repository.OrderRepository;
import com.example.Spot.order.infrastructure.producer.OrderEventProducer;
import com.example.Spot.order.infrastructure.temporal.config.OrderConstants;

import io.temporal.spring.boot.ActivityImpl;
import lombok.RequiredArgsConstructor;

@Component
@RequiredArgsConstructor
@ActivityImpl(taskQueues = OrderConstants.ORDER_TASK_QUEUE)
public class OrderActivityImpl implements OrderActivity {
    
    private final OrderRepository orderRepository;
    private final OrderEventProducer orderEventProducer;

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
            order.initiateCancel(reason, null);
            orderEventProducer.reserveOrderCancelled(order.getId(), reason);
        }
    }
    
    @Override
    @Transactional
    public void finalizeOrder(UUID orderId) {
        OrderEntity order = orderRepository.findByIdWithLock(orderId)
                .orElseThrow(() -> new IllegalArgumentException("주문 없음: " + orderId));
        
        order.finalizeCancel();
    }
    
}
