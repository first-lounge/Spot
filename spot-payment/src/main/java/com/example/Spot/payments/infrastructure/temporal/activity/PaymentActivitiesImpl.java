package com.example.Spot.payments.infrastructure.temporal.activity;

import java.util.UUID;

import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import com.example.Spot.global.presentation.advice.ResourceNotFoundException;
import com.example.Spot.payments.application.service.PaymentHistoryService;
import com.example.Spot.payments.application.service.command.PaymentApprovalService;
import com.example.Spot.payments.application.service.command.PaymentCancellationService;
import com.example.Spot.payments.application.service.query.PaymentQueryService;
import com.example.Spot.payments.domain.entity.PaymentEntity;
import com.example.Spot.payments.domain.repository.PaymentRepository;
import com.example.Spot.payments.infrastructure.event.publish.AuthRequiredEvent;
import com.example.Spot.payments.infrastructure.producer.PaymentEventProducer;
import com.example.Spot.payments.infrastructure.temporal.config.PaymentConstants;
import com.example.Spot.payments.presentation.dto.response.PaymentResponseDto;

import io.temporal.spring.boot.ActivityImpl;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

@Component
@RequiredArgsConstructor
@Slf4j
@ActivityImpl(taskQueues = PaymentConstants.PAYMENT_TASK_QUEUE)
public class PaymentActivitiesImpl implements PaymentActivities {
    
    private final PaymentRepository paymentRepository;
    private final PaymentApprovalService paymentApprovalService;
    private final PaymentCancellationService paymentCancellationService;
    private final PaymentQueryService paymentQueryService;
    private final PaymentHistoryService paymentHistoryService;
    private final PaymentEventProducer paymentEventProducer;

    // --- [조회 및 검증] ---
    @Override
    @Transactional(readOnly = true)
    public UUID findActivePaymentIdByOrderId(UUID orderId) {
        PaymentEntity payment = paymentRepository.findActivePaymentByOrderId(orderId)
                .orElseThrow(() -> new ResourceNotFoundException("[Activity] 취소 가능한 결제 내역이 없습니다. OrderID: " + orderId));
        return payment.getId();
    }
    
    // --- [상태 기록] ---
    @Override
    @Transactional
    public void recordStatus(UUID paymentId, String status) {
        if ("IN_PROGRESS".equals(status)) {
            paymentHistoryService.recordPaymentProgress(paymentId);
        } else if ("ABORTED".equals(status)) {
            paymentHistoryService.recordFailure(paymentId);
        }
    }
    
    @Override
    @Transactional
    public void recordCancelProgress(UUID paymentId) {
        paymentHistoryService.recordCancelProgress(paymentId);
    }

    @Override
    @Transactional
    public void recordCancelSuccess(UUID paymentId) {
        paymentHistoryService.recordCancelSuccess(paymentId);
    }

    @Override
    @Transactional
    public void recordFailure(UUID paymentId) {
        log.error("[Activity] 결제 승인 최종 실패 기록 (ABORTED): paymentId={}", paymentId);
        paymentHistoryService.recordFailure(paymentId);
    }

    @Override
    @Transactional
    public void recordCancelFailure(UUID paymentId) {
        log.error("[Activity] 결제 취소 최종 실패 기록 (CANCEL_FAILED): paymentId={}", paymentId);
        paymentHistoryService.recordCancelFailure(paymentId);
    }

    // --- [실제 외부 연동] ---
    @Override
    public String executePayment(UUID paymentId) {
        PaymentResponseDto.Confirm confirm = paymentApprovalService.createPaymentBillingApprove(paymentId);
        return confirm.paymentKey();
    }
    
    @Override
    @Transactional
    public void refundByOrderId(UUID orderId, String reason) {
        log.info("[Activity] 환불 실행: OrderID={}, Reason={}", orderId, reason);
        try {
            paymentCancellationService.refundByOrderId(orderId, reason);
        } catch (Exception e) {
            log.error("[Activity] 환불 실패: OrderID={}, Error={}", orderId, e.getMessage());
            throw e;
        }
    }
    
    @Override
    @Transactional
    public void refundByPaymentId(UUID paymentId, String reason) {
        PaymentEntity payment = paymentQueryService.findPayment(paymentId);
        paymentCancellationService.refundByOrderId(payment.getOrderId(), reason);
    }


    // --- [이벤트 발행] ---
    @Override
    @Transactional
    public void publishSucceeded(UUID paymentId) {
        PaymentEntity payment = paymentRepository.findById(paymentId)
                .orElseThrow(() -> new ResourceNotFoundException("결제 정보를 찾을 수 없습니다."));
        paymentEventProducer.reservePaymentSucceededEvent(payment.getOrderId(), payment.getUserId());
    }

    @Override
    @Transactional
    public void publishRefundSucceeded(UUID orderId) {
        paymentEventProducer.reservePaymentRefundedEvent(orderId);
    }

    @Override
    @Transactional
    public void publishAuthRequired(UUID paymentId, String message) {
        PaymentEntity payment = paymentRepository.findById(paymentId)
                .orElseThrow(() -> new ResourceNotFoundException("결제 정보를 찾을 수 없습니다."));
        AuthRequiredEvent event = AuthRequiredEvent.builder()
                .orderId(payment.getOrderId())
                .userId(payment.getUserId())
                .message(message)
                .build();
        paymentEventProducer.reserveAuthRequiredEvent(event);
    }
}
