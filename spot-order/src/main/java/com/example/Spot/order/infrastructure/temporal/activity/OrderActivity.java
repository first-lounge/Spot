package com.example.Spot.order.infrastructure.temporal.activity;

import java.util.UUID;

import com.example.Spot.order.domain.enums.CancelledBy;
import com.example.Spot.order.domain.enums.OrderStatus;
import com.example.Spot.order.presentation.dto.request.OrderCreateRequestDto;
import com.example.Spot.order.presentation.dto.response.OrderContextDto;

import io.temporal.activity.ActivityInterface;
import io.temporal.activity.ActivityMethod;

@ActivityInterface
public interface OrderActivity {
    
    @ActivityMethod
    void createOrderInDb(UUID orderId, Integer userId, OrderCreateRequestDto requestDto, OrderContextDto contextDto);
    
    @ActivityMethod
    void updateOrderStatusInDb(UUID orderId, OrderStatus nextStatus, Integer estimatedTime, String reason, CancelledBy actor);
    
    @ActivityMethod
    OrderStatus getOrderStatus(UUID orderId);

    @ActivityMethod
    void handlePaymentFailure(UUID orderId);

    @ActivityMethod
    void cancelOrder(UUID orderId, String reason);

    @ActivityMethod
    void finalizeOrder(UUID orderId);
    
    @ActivityMethod
    void handleRefundTimeout(UUID orderId);
}
