package com.example.Spot.order.infrastructure.temporal.activity;

import java.util.UUID;

import com.example.Spot.order.domain.enums.OrderStatus;

import io.temporal.activity.ActivityInterface;
import io.temporal.activity.ActivityMethod;

@ActivityInterface
public interface OrderActivity {
    
    @ActivityMethod
    OrderStatus getOrderStatus(UUID orderId);

    @ActivityMethod
    void handlePaymentFailure(UUID orderId);

    @ActivityMethod
    void cancelOrder(UUID orderId, String reason);

    @ActivityMethod
    void finalizeOrder(UUID orderId);
}
