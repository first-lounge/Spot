package com.example.Spot.order.infrastructure.temporal.dto;

import com.example.Spot.order.domain.enums.CancelledBy;
import com.example.Spot.order.domain.enums.OrderStatus;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@AllArgsConstructor
@NoArgsConstructor
public class OrderStatusUpdate {
    private OrderStatus status;
    private Integer estimatedTime;
    private String reason;
    private CancelledBy cancelledBy;
}
