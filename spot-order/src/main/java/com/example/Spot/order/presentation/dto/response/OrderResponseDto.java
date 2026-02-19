package com.example.Spot.order.presentation.dto.response;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

import com.example.Spot.order.domain.entity.OrderEntity;
import com.example.Spot.order.domain.enums.CancelledBy;
import com.example.Spot.order.domain.enums.OrderStatus;
import com.example.Spot.order.presentation.dto.request.OrderCreateRequestDto;

import lombok.AccessLevel;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@Builder
@AllArgsConstructor
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class OrderResponseDto {

    private UUID id;
    private Integer userId;
    private UUID storeId;
    private String storeName;
    private String orderNumber;
    private Boolean needDisposables;
    private String request;
    private LocalDateTime pickupTime;
    private OrderStatus orderStatus;
    private Integer estimatedTime;
    private String reason;
    private CancelledBy cancelledBy;
    
    private LocalDateTime paymentCompletedAt;
    private LocalDateTime paymentFailedAt;
    private LocalDateTime acceptedAt;
    private LocalDateTime rejectedAt;
    private LocalDateTime cookingStartedAt;
    private LocalDateTime cookingCompletedAt;
    private LocalDateTime pickedUpAt;
    private LocalDateTime cancelledAt;
    private LocalDateTime createdAt;
    
    private List<OrderItemResponseDto> orderItems;
    
    private BigDecimal totalAmount;
        
    public static OrderResponseDto from(OrderEntity entity) {
        List<OrderItemResponseDto> orderItemDtos = entity.getOrderItems().stream()
                .map(OrderItemResponseDto::from)
                .collect(Collectors.toList());

        BigDecimal totalAmount = orderItemDtos.stream()
                .map(OrderItemResponseDto::getSubtotal)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        return OrderResponseDto.builder()
                .id(entity.getId())
                .userId(entity.getUserId())
                .storeId(entity.getStoreId())
                .storeName(null) // MSA: Store 서비스에서 별도 조회 필요
                .orderNumber(entity.getOrderNumber())
                .needDisposables(entity.getNeedDisposables())
                .request(entity.getRequest())
                .pickupTime(entity.getPickupTime())
                .orderStatus(entity.getOrderStatus())
                .estimatedTime(entity.getEstimatedTime())
                .reason(entity.getReason())
                .cancelledBy(entity.getCancelledBy())
                .paymentCompletedAt(entity.getPaymentCompletedAt())
                .paymentFailedAt(entity.getPaymentFailedAt())
                .acceptedAt(entity.getAcceptedAt())
                .rejectedAt(entity.getRejectedAt())
                .cookingStartedAt(entity.getCookingStartedAt())
                .cookingCompletedAt(entity.getCookingCompletedAt())
                .pickedUpAt(entity.getPickedUpAt())
                .cancelledAt(entity.getCancelledAt())
                .createdAt(entity.getCreatedAt())
                .orderItems(orderItemDtos)
                .totalAmount(totalAmount)
                .build();
    }

    public static OrderResponseDto from(OrderEntity entity, String storeName) {
        OrderResponseDto dto = from(entity);
        return OrderResponseDto.builder()
                .id(dto.getId())
                .userId(dto.getUserId())
                .storeId(dto.getStoreId())
                .storeName(storeName)
                .orderNumber(dto.getOrderNumber())
                .needDisposables(dto.getNeedDisposables())
                .request(dto.getRequest())
                .pickupTime(dto.getPickupTime())
                .orderStatus(dto.getOrderStatus())
                .estimatedTime(dto.getEstimatedTime())
                .reason(dto.getReason())
                .cancelledBy(dto.getCancelledBy())
                .paymentCompletedAt(dto.getPaymentCompletedAt())
                .paymentFailedAt(dto.getPaymentFailedAt())
                .acceptedAt(dto.getAcceptedAt())
                .rejectedAt(dto.getRejectedAt())
                .cookingStartedAt(dto.getCookingStartedAt())
                .cookingCompletedAt(dto.getCookingCompletedAt())
                .pickedUpAt(dto.getPickedUpAt())
                .cancelledAt(dto.getCancelledAt())
                .createdAt(dto.getCreatedAt())
                .orderItems(dto.getOrderItems())
                .totalAmount(dto.getTotalAmount())
                .build();
    }
    public static OrderResponseDto of(UUID orderId, Integer userId, OrderCreateRequestDto request, OrderContextDto context, BigDecimal totalAmount) {
        return OrderResponseDto.builder()
                .id(orderId)
                .userId(userId)
                .storeId(request.getStoreId())
                .storeName(context.getStore().getName())
                .orderStatus(OrderStatus.PAYMENT_PENDING) // 시작 상태
                .pickupTime(request.getPickupTime())
                .needDisposables(request.getNeedDisposables())
                .request(request.getRequest())
                .totalAmount(totalAmount)
                .createdAt(LocalDateTime.now())
                .build();
    }

    public static OrderResponseDto fromId(UUID orderId, OrderStatus status) {
        return OrderResponseDto.builder()
                .id(orderId)
                .orderStatus(status)
                .build();
    }
}

