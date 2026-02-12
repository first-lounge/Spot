package com.example.Spot.payments.infrastructure.temporal.activity;

import java.util.UUID;

import io.temporal.activity.ActivityInterface;
import io.temporal.activity.ActivityMethod;

@ActivityInterface
public interface PaymentActivities {

    // --- [ 1. 조회 및 검증 ] ---
    @ActivityMethod
    UUID findActivePaymentIdByOrderId(UUID orderId);

    // --- [ 2. 상태 기록 (공통 및 승인) ] ---
    @ActivityMethod
    void recordStatus(UUID paymentId, String status);

    @ActivityMethod
    void recordFailure(UUID paymentId); // 승인 실패용 (ABORTED)

    // --- [ 3. 상태 기록 (취소 전용) ] ---
    @ActivityMethod
    void recordCancelProgress(UUID paymentId);

    @ActivityMethod
    void recordCancelSuccess(UUID paymentId);

    @ActivityMethod
    void recordCancelFailure(UUID paymentId); 

    // --- [ 4. 실제 외부 연동 (PG) ] ---
    @ActivityMethod
    String executePayment(UUID paymentId);

    @ActivityMethod
    void refundByOrderId(UUID orderId, String reason);

    @ActivityMethod
    void refundByPaymentId(UUID paymentId, String reason);

    // --- [ 5. 이벤트 발행 ] ---
    @ActivityMethod
    void publishSucceeded(UUID paymentId);

    @ActivityMethod
    void publishRefundSucceeded(UUID orderId);

    @ActivityMethod
    void publishAuthRequired(UUID paymentId, String message);
}
