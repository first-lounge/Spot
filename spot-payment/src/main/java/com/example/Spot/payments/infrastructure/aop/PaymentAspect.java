package com.example.Spot.payments.infrastructure.aop;

import java.util.UUID;

import org.aspectj.lang.JoinPoint;
import org.aspectj.lang.ProceedingJoinPoint;
import org.aspectj.lang.annotation.Around;
import org.aspectj.lang.annotation.Aspect;
import org.aspectj.lang.annotation.Before;
import org.aspectj.lang.annotation.Pointcut;
import org.springframework.stereotype.Component;

import com.example.Spot.global.presentation.advice.ResourceNotFoundException;
import com.example.Spot.payments.application.service.PaymentHistoryService;
import com.example.Spot.payments.domain.entity.PaymentEntity;
import com.example.Spot.payments.domain.repository.PaymentRepository;
import com.example.Spot.payments.presentation.dto.request.PaymentRequestDto;
import com.example.Spot.payments.presentation.dto.response.PaymentResponseDto;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

@Slf4j
@Aspect
@Component
@RequiredArgsConstructor
public class PaymentAspect {

    private final PaymentRepository paymentRepository;
    private final PaymentHistoryService paymentHistoryService;

    @Pointcut("execution(* com.example.Spot.payments.application.service.PaymentService.*(..))")
    private void paymentServiceMethods() {}

    @Before("paymentServiceMethods()")
    public void logBefore(JoinPoint joinPoint) {
        String methodName = joinPoint.getSignature().getName();
        System.out.println("[Payment 로직] 메서드 실행 시작: " + methodName);
    }

    @Around("@annotation(ready)")
    public Object handleReady(ProceedingJoinPoint joinPoint, Ready ready) throws Throwable {

        PaymentRequestDto.Confirm request = (PaymentRequestDto.Confirm) joinPoint.getArgs()[2];

        validatePaymentRequest(request);
        
        var existingActivePayment = paymentRepository.findActivePaymentByOrderId(request.orderId());
        if (existingActivePayment.isPresent()) {
            log.info("[멱등성 처리] 이미 진행 중인 결제가 존재합니다. 기존 ID 반환: {}", existingActivePayment.get().getId());
            return existingActivePayment.get().getId();
        }
        
        Object result = joinPoint.proceed();
        UUID paymentId = (UUID) result;
        paymentHistoryService.recordPaymentReady(paymentId);
        return result;
    }

    @Around("@annotation(trace)")
    public Object handlePaymentBillingApproveStatus(ProceedingJoinPoint joinPoint, PaymentBillingApproveTrace trace) throws Throwable {

        UUID paymentId = (UUID) joinPoint.getArgs()[0];
        
        try {
            paymentHistoryService.recordPaymentProgress(paymentId);

            Object result = joinPoint.proceed();

            if (result instanceof PaymentResponseDto.Confirm response) {
                String paymentKey = response.paymentKey();
                paymentHistoryService.recordPaymentSuccess(paymentId, paymentKey);
            }

            return result;

        } catch (Exception e) {
            paymentHistoryService.recordFailure(paymentId);
            throw e;
        }
    }
    
    private void validatePaymentRequest(PaymentRequestDto.Confirm request) {
        
        if (request.paymentAmount() <= 0) {
            throw new IllegalArgumentException("[PaymentService] 결제 금액은 0보다 커야 합니다");
        }
    }

    @Around("@annotation(cancel)")
    public Object handleCancelStatus(ProceedingJoinPoint jointPoint, Cancel cancel) throws Throwable {

        PaymentRequestDto.Cancel request = (PaymentRequestDto.Cancel) jointPoint.getArgs()[0];

        paymentHistoryService.recordCancelProgress(request.paymentId());

        try {

            Object result = jointPoint.proceed();

            paymentHistoryService.recordCancelSuccess(request.paymentId());

            return result;

        } catch (Exception e) {
            paymentHistoryService.recordFailure(request.paymentId());
            throw e;
        }
    }

    private PaymentEntity findPayment(UUID paymentId) {
        return paymentRepository
            .findById(paymentId)
            .orElseThrow(() -> new ResourceNotFoundException("[PaymentService] 결제를 찾을 수 없습니다."));
  }
}
