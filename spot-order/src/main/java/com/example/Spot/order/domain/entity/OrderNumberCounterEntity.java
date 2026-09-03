package com.example.Spot.order.domain.entity;

import java.time.LocalDate;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Entity
@Getter
@Table(name = "p_order_number_counter")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class OrderNumberCounterEntity {
    @Id
    @Column(name = "order_date")
    private LocalDate orderDate;

    @Column(name = "last_order_num", nullable = false)
    private int lastOrderNum;

    // 마지막 주문 번호 1 증가
    public void increaseOrderNum() {
        this.lastOrderNum += 1;
    }
}
