package com.example.Spot.order.domain.entity;

import java.math.BigDecimal;
import java.util.UUID;

import org.hibernate.annotations.UuidGenerator;

import com.example.Spot.global.common.BaseEntity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Entity
@Getter
@Table(name = "p_order_item_option")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class OrderItemOptionEntity extends BaseEntity {

    @Id
    @GeneratedValue
    @UuidGenerator
    @Column(columnDefinition = "UUID")
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "order_item_id", nullable = false)
    private OrderItemEntity orderItem;

    @Column(name = "menu_option_id", nullable = false, columnDefinition = "UUID")
    private UUID menuOptionId;

    @Column(name = "option_name", nullable = false, length = 50)
    private String optionName;

    @Column(name = "option_detail", length = 50)
    private String optionDetail;

    @Column(name = "option_price", nullable = false, precision = 10, scale = 2)
    private BigDecimal optionPrice;

    @Builder
    public OrderItemOptionEntity(UUID menuOptionId, String optionName, String optionDetail, BigDecimal optionPrice) {
        if (menuOptionId == null) {
            throw new IllegalArgumentException("메뉴 옵션 ID는 필수입니다.");
        }
        if (optionName == null || optionName.trim().isEmpty()) {
            throw new IllegalArgumentException("옵션 이름은 필수입니다.");
        }
        if (optionPrice == null || optionPrice.compareTo(BigDecimal.ZERO) < 0) {
            throw new IllegalArgumentException("옵션 가격은 0 이상이어야 합니다.");
        }

        this.menuOptionId = menuOptionId;
        this.optionName = optionName;
        this.optionDetail = optionDetail;
        this.optionPrice = optionPrice;
    }

    protected void setOrderItem(OrderItemEntity orderItem) {
        this.orderItem = orderItem;
    }

    public BigDecimal getSubtotal() {
        return this.optionPrice; // 옵션 하나의 가격
    }
}

