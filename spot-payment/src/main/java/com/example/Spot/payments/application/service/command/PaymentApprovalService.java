package com.example.Spot.payments.application.service.command;

import java.time.LocalDateTime;
import java.util.UUID;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.Spot.global.feign.OrderClient;
import com.example.Spot.global.feign.UserClient;
import com.example.Spot.global.presentation.advice.BillingKeyNotFoundException;
import com.example.Spot.global.presentation.advice.ResourceNotFoundException;
import com.example.Spot.payments.domain.entity.PaymentEntity;
import com.example.Spot.payments.domain.entity.PaymentHistoryEntity;
import com.example.Spot.payments.domain.entity.PaymentKeyEntity;
import com.example.Spot.payments.domain.entity.UserBillingAuthEntity;
import com.example.Spot.payments.domain.gateway.PaymentGateway;
import com.example.Spot.payments.domain.repository.PaymentHistoryRepository;
import com.example.Spot.payments.domain.repository.PaymentKeyRepository;
import com.example.Spot.payments.domain.repository.PaymentRepository;
import com.example.Spot.payments.domain.repository.UserBillingAuthRepository;
import com.example.Spot.payments.infrastructure.aop.PaymentBillingApproveTrace;
import com.example.Spot.payments.infrastructure.aop.Ready;
import com.example.Spot.payments.infrastructure.dto.TossPaymentResponse;
import com.example.Spot.payments.infrastructure.producer.PaymentEventProducer;
import com.example.Spot.payments.presentation.dto.request.PaymentRequestDto;
import com.example.Spot.payments.presentation.dto.response.PaymentResponseDto;

import io.github.resilience4j.bulkhead.annotation.Bulkhead;
import io.github.resilience4j.circuitbreaker.annotation.CircuitBreaker;
import io.github.resilience4j.retry.annotation.Retry;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

@Slf4j
@Service
@RequiredArgsConstructor
public class PaymentApprovalService {

    private final PaymentGateway paymentGateway;
    private final PaymentEventProducer paymentEventProducer;

    @Value("${toss.payments.timeout}")
    private Integer timeout;

    private final PaymentRepository paymentRepository;
    private final PaymentHistoryRepository paymentHistoryRepository;
    private final PaymentKeyRepository paymentKeyRepository;
    private final UserBillingAuthRepository userBillingAuthRepository;

    private final OrderClient orderClient;
    private final UserClient userClient;

    @Ready
    public UUID ready(Integer userId, UUID orderId, PaymentRequestDto.Confirm request) {
        return paymentRepository.findByOrderId(orderId)
                .map(PaymentEntity::getId)
                .orElseGet(() -> {
                    PaymentEntity payment = PaymentEntity.builder()
                            .userId(userId)
                            .orderId(orderId)
                            .title(request.title())
                            .content(request.content())
                            .paymentMethod(request.paymentMethod())
                            .totalAmount(request.paymentAmount())
                            .build();

                    return paymentRepository.save(payment).getId();
                });
    }

    @PaymentBillingApproveTrace
    public PaymentResponseDto.Confirm createPaymentBillingApprove(UUID paymentId) {
        PaymentEntity payment = findPayment(paymentId);

        UserBillingAuthEntity billingAuth = userBillingAuthRepository
                .findActiveByUserId(payment.getUserId())
                .orElseThrow(() -> new BillingKeyNotFoundException(
                        "[PaymentApprovalService] 등록된 결제 수단이 없습니다. 먼저 결제 수단을 등록해주세요. UserId: " + payment.getUserId()));

        UUID uniqueOrderId = payment.getOrderId();

        TossPaymentResponse response = confirmBillingPayment(payment, billingAuth, uniqueOrderId);
        
        return PaymentResponseDto.Confirm.builder()
                .paymentId(paymentId)
                .amount(response.getTotalAmount())
                .paymentKey(response.getPaymentKey())
                .status("DONE")
                .build();
    }

    private TossPaymentResponse confirmBillingPayment(
            PaymentEntity payment, UserBillingAuthEntity billingAuth, UUID uniqueOrderId) {

        String billingKey = billingAuth.getBillingKey();

        if (billingKey == null || billingKey.isEmpty()) {
            throw new IllegalStateException(
                    "[PaymentApprovalService] 등록된 Billing Key가 없습니다. 먼저 Billing Key를 입력해주세요.");
        }

        return paymentGateway.requestBillingPayment(
                billingKey,
                payment.getTotalAmount(),
                uniqueOrderId,
                payment.getPaymentTitle(),
                billingAuth.getCustomerKey(),
                this.timeout);
    }

    @Transactional
    public PaymentResponseDto.SavedPaymentHistory savePaymentHistory(PaymentRequestDto.SavePaymentHistory request) {

        validateUserExists(request.userId());
        validateOrderExists(request.orderId());

        PaymentEntity payment = PaymentEntity.builder()
                .userId(request.userId())
                .orderId(request.orderId())
                .title(request.title())
                .content(request.content())
                .paymentMethod(request.paymentMethod())
                .totalAmount(request.paymentAmount())
                .build();

        PaymentEntity savedPayment = paymentRepository.save(payment);

        PaymentHistoryEntity history = PaymentHistoryEntity.builder()
                .paymentId(savedPayment.getId())
                .status(PaymentHistoryEntity.PaymentStatus.DONE)
                .build();

        paymentHistoryRepository.save(history);

        PaymentKeyEntity paymentKey = PaymentKeyEntity.builder()
                .paymentId(savedPayment.getId())
                .paymentKey(request.paymentKey())
                .confirmedAt(LocalDateTime.now())
                .build();

        paymentKeyRepository.save(paymentKey);

        paymentEventProducer.reservePaymentSucceededEvent(
                savedPayment.getOrderId(),
                savedPayment.getUserId()
        );

        return PaymentResponseDto.SavedPaymentHistory.builder()
                .paymentId(savedPayment.getId())
                .orderId(savedPayment.getOrderId())
                .status("DONE")
                .amount(savedPayment.getTotalAmount())
                .savedAt(LocalDateTime.now())
                .build();
    }

    private PaymentEntity findPayment(UUID paymentId) {
        return paymentRepository
                .findById(paymentId)
                .orElseThrow(() -> new ResourceNotFoundException("[PaymentApprovalService] 결제를 찾을 수 없습니다."));
    }

    private void validateOrderExists(UUID orderId) {
        if (!orderClient.existsById(orderId)) {
            throw new ResourceNotFoundException("[PaymentApprovalService] 주문을 찾을 수 없습니다.");
        }
    }

    @CircuitBreaker(name = "user_validate_activeUser")
    @Bulkhead(name = "user_validate_activeUser", type = Bulkhead.Type.SEMAPHORE)
    @Retry(name = "user_validate_activeUser")
    private void validateUserExists(Integer userId) {
        if (!userClient.existsById(userId)) {
            throw new ResourceNotFoundException("[PaymentApprovalService] 사용자를 찾을 수 없습니다.");
        }
    }
}
