package com.example.Spot.payments.application.service;

import java.time.LocalDateTime;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.Spot.global.presentation.advice.ResourceNotFoundException;
import com.example.Spot.payments.domain.entity.PaymentHistoryEntity;
import com.example.Spot.payments.domain.entity.PaymentKeyEntity;
import com.example.Spot.payments.domain.repository.PaymentHistoryRepository;
import com.example.Spot.payments.domain.repository.PaymentKeyRepository;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

@Slf4j
@Service
@RequiredArgsConstructor
public class PaymentHistoryService {

    private final PaymentHistoryRepository paymentHistoryRepository;
    private final PaymentKeyRepository paymentKeyRepository;

    @Transactional
    public PaymentHistoryEntity recordPaymentReady(UUID paymentId) {

        return createPaymentHistory(paymentId, PaymentHistoryEntity.PaymentStatus.READY);
    }

    @Transactional
    public PaymentHistoryEntity recordCancelProgress(UUID paymentId) {
        PaymentHistoryEntity latestItem =
            paymentHistoryRepository
                .findTopByPaymentIdOrderByCreatedAtDesc(paymentId)
                .orElseThrow(() -> new ResourceNotFoundException("[PaymentService] 결제 이력을 찾을 수 없습니다."));

        if (latestItem.getStatus() != PaymentHistoryEntity.PaymentStatus.DONE) {
            throw new IllegalStateException("[PaymentService] 결제 완료된 내역만 취소 가능합니다.");
        }

        return createPaymentHistory(paymentId, PaymentHistoryEntity.PaymentStatus.CANCELLED_IN_PROGRESS);
    }

    @Transactional
    public PaymentHistoryEntity recordCancelSuccess(UUID paymentId) {
        return createPaymentHistory(paymentId, PaymentHistoryEntity.PaymentStatus.CANCELLED);
    }

    @Transactional
    public void recordCancelFailure(UUID paymentId) {
        createPaymentHistory(paymentId, PaymentHistoryEntity.PaymentStatus.CANCEL_FAILED);
    }

    @Transactional
    public void recordPaymentProgress(UUID paymentId) {
        PaymentHistoryEntity latestItem =
            paymentHistoryRepository
                .findTopByPaymentIdOrderByCreatedAtDesc(paymentId)
                .orElseThrow(() -> new ResourceNotFoundException("[PaymentService] 결제 이력을 찾을 수 없습니다."));

        if (latestItem.getStatus() != PaymentHistoryEntity.PaymentStatus.READY) {
            log.info("[멱등성 패스] 이미 처리 중이거나 완료된 결제입니다. 현재 상태: {}, paymentId: {}",
                    latestItem.getStatus(), paymentId);
            return;
            
        }

        createPaymentHistory(paymentId, PaymentHistoryEntity.PaymentStatus.IN_PROGRESS);
    }

    @Transactional
    public void recordFailure(UUID paymentId) {
        createPaymentHistory(paymentId, PaymentHistoryEntity.PaymentStatus.ABORTED);
    }

    @Transactional
    public PaymentHistoryEntity recordPaymentSuccess(UUID paymentId, String paymentKey) {
        PaymentHistoryEntity paymentHistory =
            createPaymentHistory(paymentId, PaymentHistoryEntity.PaymentStatus.DONE);
        createPaymentKey(paymentId, paymentKey, LocalDateTime.now());

        return paymentHistory;
    }

    private PaymentHistoryEntity createPaymentHistory(
        UUID paymentId, PaymentHistoryEntity.PaymentStatus status) {
        PaymentHistoryEntity paymentHistory =
            PaymentHistoryEntity.builder().paymentId(paymentId).status(status).build();

        return paymentHistoryRepository.save(paymentHistory);
    }

    private PaymentKeyEntity createPaymentKey(
        UUID paymentId, String paymentKey, LocalDateTime confirmedAt) {
        PaymentKeyEntity paymentKeyEntity =
            PaymentKeyEntity.builder()
                .paymentId(paymentId)
                .paymentKey(paymentKey)
                .confirmedAt(confirmedAt)
                .build();
        return paymentKeyRepository.save(paymentKeyEntity);
    }
}
