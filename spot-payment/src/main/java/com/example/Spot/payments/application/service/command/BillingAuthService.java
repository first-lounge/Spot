package com.example.Spot.payments.application.service.command;

import java.time.LocalDateTime;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.Spot.global.feign.UserClient;
import com.example.Spot.global.presentation.advice.ResourceNotFoundException;
import com.example.Spot.payments.domain.entity.UserBillingAuthEntity;
import com.example.Spot.payments.domain.gateway.PaymentGateway;
import com.example.Spot.payments.domain.repository.UserBillingAuthRepository;
import com.example.Spot.payments.infrastructure.dto.TossPaymentResponse;
import com.example.Spot.payments.presentation.dto.request.PaymentRequestDto;
import com.example.Spot.payments.presentation.dto.response.PaymentResponseDto;

import io.github.resilience4j.bulkhead.annotation.Bulkhead;
import io.github.resilience4j.circuitbreaker.annotation.CircuitBreaker;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

@Slf4j
@Service
@RequiredArgsConstructor
public class BillingAuthService {

    private final PaymentGateway paymentGateway;
    private final UserBillingAuthRepository userBillingAuthRepository;
    private final UserClient userClient;

    @Transactional
    public PaymentResponseDto.SavedBillingKey saveBillingKey(PaymentRequestDto.SaveBillingKey request) {
        validateUserExists(request.userId());

        // 기존 빌링 인증 정보가 있다면 비활성화 (사용자당 하나의 활성 인증 정보만 유지)
        userBillingAuthRepository.findActiveByUserId(request.userId())
                .ifPresent(existing -> {
                    existing.deactivate();
                    userBillingAuthRepository.save(existing);
                });

        TossPaymentResponse billingKeyResponse = paymentGateway.issueBillingKey(
                request.authKey(),
                request.customerKey()
        );

        UserBillingAuthEntity billingAuth = UserBillingAuthEntity.builder()
                .userId(request.userId())
                .authKey(request.authKey())
                .customerKey(request.customerKey())
                .billingKey(billingKeyResponse.getBillingKey())
                .issuedAt(LocalDateTime.now())
                .build();

        userBillingAuthRepository.save(billingAuth);

        return PaymentResponseDto.SavedBillingKey.builder()
                .userId(request.userId())
                .customerKey(request.customerKey())
                .billingKey(billingAuth.getBillingKey())
                .savedAt(billingAuth.getIssuedAt())
                .build();
    }

    @Transactional(readOnly = true)
    public boolean hasBillingAuth(Integer userId) {
        boolean exists = userBillingAuthRepository.existsByUserIdAndIsActiveTrue(userId);

        // 상세 조회로 실제 데이터 확인 (디버깅용)
        userBillingAuthRepository.findActiveByUserId(userId)
                .ifPresentOrElse(
                        auth -> log.debug("빌링 인증 데이터 존재 - userId: {}, authKey: {}, isActive: {}",
                                userId, auth.getAuthKey(), auth.getIsActive()),
                        () -> log.debug("빌링 인증 데이터 없음 - userId: {}", userId)
                );

        return exists;
    }

    @Transactional(readOnly = true)
    public UserBillingAuthEntity getActiveBillingAuth(Integer userId) {
        return userBillingAuthRepository.findActiveByUserId(userId)
                .orElseThrow(() -> new ResourceNotFoundException(
                        "[BillingAuthService] 등록된 결제 수단이 없습니다. UserId: " + userId));
    }

    @CircuitBreaker(name = "user_validate_activeUser")
    @Bulkhead(name = "user_validate_activeUser", type = Bulkhead.Type.SEMAPHORE)
    private void validateUserExists(Integer userId) {
        if (!userClient.existsById(userId)) {
            throw new ResourceNotFoundException("[BillingAuthService] 사용자를 찾을 수 없습니다.");
        }
    }
}
