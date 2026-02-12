package com.example.Spot.payments.infrastructure.temporal.workflow;

import java.time.Duration;
import java.util.UUID;

import com.example.Spot.payments.infrastructure.temporal.activity.PaymentActivities;
import com.example.Spot.payments.infrastructure.temporal.config.PaymentConstants;

import io.temporal.activity.ActivityOptions;
import io.temporal.common.RetryOptions;
import io.temporal.spring.boot.WorkflowImpl;
import io.temporal.workflow.Saga;
import io.temporal.workflow.Workflow;
import lombok.extern.slf4j.Slf4j;

@Slf4j
@WorkflowImpl(taskQueues = PaymentConstants.PAYMENT_TASK_QUEUE)
public class PaymentCancelWorkflowImpl implements PaymentCancelWorkflow {
    
    private static final String[] DO_NOT_RETRY_EXCEPTIONS = {
            "com.example.Spot.global.presentation.advice.BillingKeyNotFoundException",
            "com.example.Spot.global.presentation.advice.ResourceNotFoundException",
            "java.lang.IllegalArgumentException"
    };

    private final PaymentActivities activities = Workflow.newActivityStub(
            PaymentActivities.class,
            ActivityOptions.newBuilder()
                    .setStartToCloseTimeout(Duration.ofMinutes(1))
                    .setRetryOptions(RetryOptions.newBuilder()
                            .setInitialInterval(Duration.ofSeconds(5))
                            .setMaximumAttempts(8)
                            .setDoNotRetry(DO_NOT_RETRY_EXCEPTIONS)
                            .build())
                    .build());

    @Override
    public void processCancel(UUID orderId, String reason) {
        UUID paymentId = activities.findActivePaymentIdByOrderId(orderId);
        Saga saga = new Saga(new Saga.Options.Builder().setContinueWithError(false).build());

        try {
            saga.addCompensation(activities::recordCancelFailure, paymentId);
            activities.recordCancelProgress(paymentId);
            activities.refundByOrderId(orderId, reason);
            activities.recordCancelSuccess(paymentId);
            activities.publishRefundSucceeded(orderId);

        } catch (Exception e) {
            log.error("[취소워크플로우] 최종 실패 - OrderID: {}, 사유: {}", orderId, e.getMessage());
            try {
                saga.compensate();
            } catch (Exception se) {
                log.error("[취소사가] 보상 트랜잭션 실행 중 치명적 오류 발생", se);
            }
            throw e;
        }
    }
}
