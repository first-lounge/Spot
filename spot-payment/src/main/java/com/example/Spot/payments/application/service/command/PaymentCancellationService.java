package com.example.Spot.payments.application.service.command;

import java.time.LocalDateTime;
import java.util.Optional;
import java.util.UUID;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.Spot.payments.domain.entity.PaymentEntity;
import com.example.Spot.payments.domain.entity.PaymentKeyEntity;
import com.example.Spot.payments.domain.gateway.PaymentGateway;
import com.example.Spot.payments.domain.repository.PaymentKeyRepository;
import com.example.Spot.payments.domain.repository.PaymentRepository;
import com.example.Spot.payments.infrastructure.aop.Cancel;
import com.example.Spot.payments.infrastructure.dto.TossPaymentResponse;
import com.example.Spot.payments.presentation.dto.request.PaymentRequestDto;
import com.example.Spot.payments.presentation.dto.response.PaymentResponseDto;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

@Slf4j
@Service
@RequiredArgsConstructor
public class PaymentCancellationService {

    private final PaymentGateway paymentGateway;

    @Value("${toss.payments.timeout}")
    private Integer timeout;

    private final PaymentRepository paymentRepository;
    private final PaymentKeyRepository paymentKeyRepository;

    @Transactional
    public boolean refundByOrderId(UUID orderId, String reason) {
        Optional<PaymentEntity> paymentOpt = paymentRepository.findActivePaymentByOrderId(orderId);
        
        if (paymentOpt.isEmpty()) {
            log.info("[환불 스킵] 취소 가능한 결제 내역이 없습니다. (이미 취소됨 혹은 결제 전 실패) OrderID: {}", orderId);
            return true;
        }
        PaymentEntity payment = paymentOpt.get();

        PaymentRequestDto.Cancel cancelRequest = PaymentRequestDto.Cancel.builder()
                .paymentId(payment.getId())
                .cancelReason(reason)
                .build();

        executeCancel(cancelRequest);
        return true;
    }

    @Cancel
    public PaymentResponseDto.Cancel executeCancel(PaymentRequestDto.Cancel request) {
        PaymentKeyEntity paymentKeyEntity = paymentKeyRepository
                .findByPaymentId(request.paymentId())
                .orElseThrow(() -> new IllegalStateException(
                        "[PaymentCancellationService] 결제 키가 없어 취소할 수 없습니다."));
        
        tossPaymentCancel(request.paymentId(), paymentKeyEntity.getPaymentKey(), request.cancelReason());

        return PaymentResponseDto.Cancel.builder()
                .paymentId(request.paymentId())
                .cancelAmount(0L)
                .cancelReason(request.cancelReason())
                .canceledAt(LocalDateTime.now())
                .build();
    }

    // TODO: 구현 필요
    public PaymentResponseDto.PartialCancel executePartialCancel(PaymentRequestDto.PartialCancel request) {
        return null;
    }

    private TossPaymentResponse tossPaymentCancel(UUID paymentId, String paymentKey, String cancelReason) {
        return paymentGateway.cancelPayment(paymentKey, cancelReason, this.timeout);
    }
}
