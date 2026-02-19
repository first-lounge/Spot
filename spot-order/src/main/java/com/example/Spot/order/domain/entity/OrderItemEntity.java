package com.example.Spot.order.domain.entity;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import org.hibernate.annotations.UuidGenerator;

import com.example.Spot.global.common.BaseEntity;

import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.OneToMany;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Entity
@Getter
@Table(name = "p_order_item")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class OrderItemEntity extends BaseEntity {

    @Id
    @GeneratedValue
    @UuidGenerator
    @Column(columnDefinition = "UUID")
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "order_id", nullable = false)
    private OrderEntity order;

    @Column(name = "menu_id", nullable = false, columnDefinition = "UUID")
    private UUID menuId;

    @Column(name = "menu_name", nullable = false)
    private String menuName;

    @Column(name = "menu_price", nullable = false, precision = 10, scale = 2)
    private BigDecimal menuPrice;

    @Column(name = "quantity", nullable = false)
    private Integer quantity;

    @OneToMany(mappedBy = "orderItem", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<OrderItemOptionEntity> orderItemOptions = new ArrayList<>();

    @Builder
    public OrderItemEntity(UUID menuId, String menuName, BigDecimal menuPrice, Integer quantity) {
        if (menuId == null) {
            throw new IllegalArgumentException("메뉴 ID는 필수입니다.");
        }
        if (menuName == null || menuName.trim().isEmpty()) {
            throw new IllegalArgumentException("메뉴 이름은 필수입니다.");
        }
        if (menuPrice == null || menuPrice.compareTo(BigDecimal.ZERO) < 0) {
            throw new IllegalArgumentException("메뉴 가격은 0 이상이어야 합니다.");
        }
        if (quantity == null || quantity <= 0) {
            throw new IllegalArgumentException("수량은 1 이상이어야 합니다.");
        }

        this.menuId = menuId;
        this.menuName = menuName;
        this.menuPrice = menuPrice;
        this.quantity = quantity;
    }

    public void addOrderItemOption(OrderItemOptionEntity orderItemOption) {
        if (orderItemOption == null) {
            throw new IllegalArgumentException("주문 옵션은 null일 수 없습니다.");
        }
        this.orderItemOptions.add(orderItemOption);
        orderItemOption.setOrderItem(this);
    }

    // 양방향 관계 설정을 위한 메서드
    protected void setOrder(OrderEntity order) {
        this.order = order;
    }

    public BigDecimal getTotalPrice() {
        BigDecimal optionsSum = orderItemOptions.stream()
                .map(OrderItemOptionEntity::getSubtotal)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        return this.menuPrice.multiply(BigDecimal.valueOf(this.quantity)).add(optionsSum);
    }
}
