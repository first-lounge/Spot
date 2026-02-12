package com.example.Spot.payments.domain.entity;

import java.util.UUID;

import org.hibernate.annotations.UuidGenerator;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import com.example.Spot.global.common.BaseEntity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EntityListeners;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Entity
@Getter
@Table(name = "p_payment_history")
@EntityListeners(AuditingEntityListener.class)
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class PaymentHistoryEntity extends BaseEntity {

  @Id
  @GeneratedValue
  @UuidGenerator
  @Column(columnDefinition = "UUID")
  private UUID id;

  @Column(nullable = false, updatable = false, name = "payment_id")
  private UUID paymentId;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false, updatable = false, name = "payment_status")
  private PaymentStatus paymentStatus;

  @Builder
  public PaymentHistoryEntity(UUID paymentId, PaymentStatus status) {

    if (paymentId == null) {
      throw new IllegalArgumentException("사전에 등록된 결제가 있어야 합니다.");
    }

    this.paymentId = paymentId;
    this.paymentStatus = status;
  }

  public PaymentStatus getStatus() {
    return this.paymentStatus;
  }

  public enum PaymentStatus {
    READY, // 결제 준비
    IN_PROGRESS, // 결제 진행중
    WAITING_FOR_DEPOSIT, // 가상계좌 결제 흐름에만 있는 상태
    DONE, // 결제 됨
    CANCELLED, // 결제 취소 됨
    CANCELLED_IN_PROGRESS, // 결제 진행중
    CANCEL_FAILED,
    PARTIAL_CANCELLED, // 승인된 결제가 부분 취소된 상태
    ABORTED, // 결제 승인이 실패한 상태
    EXPIRED // 결제 유효 시간 30분이 지나 거래가 취소 상태. IN_PROGRESS 상태에서 결제 승인 API를 호출하지 않으면 EXPIRED가 됨.
  }
}
