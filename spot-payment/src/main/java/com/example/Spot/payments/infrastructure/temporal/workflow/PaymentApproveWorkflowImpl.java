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
public class PaymentApproveWorkflowImpl implements PaymentApproveWorkflow {

    private static final String[] DO_NOT_RETRY_EXCEPTIONS = {
            "com.example.Spot.global.presentation.advice.BillingKeyNotFoundException",
            "java.lang.IllegalArgumentException"
    };

    private final PaymentActivities activities = Workflow.newActivityStub(
            PaymentActivities.class,
            ActivityOptions.newBuilder()
                    .setStartToCloseTimeout(Duration.ofMinutes(1))
                    .setRetryOptions(RetryOptions.newBuilder()
                            .setInitialInterval(Duration.ofSeconds(10))
                            .setBackoffCoefficient(2.0)
                            .setMaximumInterval(Duration.ofMinutes(1))
                            .setMaximumAttempts(6)
                            .setDoNotRetry(DO_NOT_RETRY_EXCEPTIONS)
                            .build())
                    .build());

    @Override
    public void processApprove(UUID orderId) {
        Saga saga = new Saga(new Saga.Options.Builder().setContinueWithError(false).build());

        UUID paymentId = activities.findActivePaymentIdByOrderId(orderId);
        try {
            
            activities.recordStatus(paymentId, "IN_PROGRESS");
            saga.addCompensation(activities::recordFailure, paymentId);
            activities.executePayment(paymentId);
            saga.addCompensation(activities::refundByPaymentId, paymentId, "시스템 오류로 인한 자동 결제 취소");
            activities.publishSucceeded(paymentId);

            log.info("[승인워크플로우] 완료 - PaymentID: {}", paymentId);
            
        } catch (Exception e) {
            log.error("[결제워크플로우] 결제 프로세스 중 에러 발생. ID: {}, 사유: {}", paymentId, e.getMessage());
            try {
                saga.compensate();
            } catch (Exception ce) {
                log.error("[결제사가패턴] 보상 트랜잭션 실행 중 치명적 실패!", ce);
            }
            activities.recordStatus(paymentId, "ABORTED");
            activities.publishAuthRequired(paymentId, e.getMessage());
            throw e;
        }
    }
}
