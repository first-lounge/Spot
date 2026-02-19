package com.example.Spot.order.domain.enums;

public enum OrderStatus {
    PAYMENT_PENDING("결제 대기"),      // 주문 생성 후 결제 진행 중
    PAYMENT_FAILED("결제 실패"),       // 결제 실패
    PENDING("주문 수락 대기"),         // 결제 완료 후 점주 수락 대기
    ACCEPTED("주문 수락"),
    REJECT_PENDING("거절 처리 중"),
    REJECTED("주문 거절"),
    COOKING("조리중"),
    READY("픽업 대기"),
    COMPLETED("픽업 완료"),
    CANCEL_PENDING("취소 처리 중"),
    CANCELLED("주문 취소"),
    REFUND_ERROR("환불 확인 필요");

    private final String description;

    OrderStatus(String description) {
        this.description = description;
    }

    public String getDescription() {
        return description;
    }
    
    public boolean isFinalStatus() {
        return this == COMPLETED || this == CANCELLED || this == REJECTED || this == PAYMENT_FAILED || this == REFUND_ERROR;
    }

    // 상태 전환 가능 여부 검증
    public boolean canTransitionTo(OrderStatus newStatus) {
        return switch (this) {
            case PAYMENT_PENDING -> newStatus == PENDING || newStatus == PAYMENT_FAILED || newStatus == CANCELLED;
            case PAYMENT_FAILED -> newStatus == PAYMENT_PENDING || newStatus == CANCELLED; // 재결제 시도 가능
            
            case PENDING -> newStatus == ACCEPTED || newStatus == REJECT_PENDING || newStatus == CANCEL_PENDING;
            case ACCEPTED -> newStatus == COOKING || newStatus == CANCEL_PENDING;
            case COOKING -> newStatus == READY || newStatus == CANCEL_PENDING;
            case READY -> newStatus == COMPLETED;

            case REJECT_PENDING -> newStatus == REJECTED || newStatus == REFUND_ERROR;
            case CANCEL_PENDING ->  newStatus == CANCELLED || newStatus == REFUND_ERROR;
            default -> false;
        };
    }
}
