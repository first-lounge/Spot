package com.example.Spot.payments.application.service;

import java.util.UUID;

import org.springframework.stereotype.Service;

import com.example.Spot.payments.application.service.command.BillingAuthService;
import com.example.Spot.payments.application.service.command.PaymentApprovalService;
import com.example.Spot.payments.application.service.command.PaymentCancellationService;
import com.example.Spot.payments.application.service.query.PaymentQueryService;
import com.example.Spot.payments.domain.repository.PaymentRepository;
import com.example.Spot.payments.presentation.dto.request.PaymentRequestDto;
import com.example.Spot.payments.presentation.dto.response.PaymentResponseDto;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

@Slf4j
@Service
@RequiredArgsConstructor
public class PaymentService {

    private final PaymentApprovalService paymentApprovalService;
    private final PaymentCancellationService paymentCancellationService;
    private final BillingAuthService billingAuthService;
    private final PaymentRepository paymentRepository;
    private final PaymentQueryService paymentQueryService;

    // ******* //
    // 결제 승인 //
    // ******* //
    public UUID ready(Integer userId, UUID orderId, PaymentRequestDto.Confirm request) {
        return paymentApprovalService.ready(userId, orderId, request);
    }

    public PaymentResponseDto.Confirm createPaymentBillingApprove(UUID paymentId) {
        return paymentApprovalService.createPaymentBillingApprove(paymentId);
    }

    public PaymentResponseDto.SavedPaymentHistory savePaymentHistory(PaymentRequestDto.SavePaymentHistory request) {
        return paymentApprovalService.savePaymentHistory(request);
    }

    // ******* //
    // 결제 취소 //
    // ******* //
    public boolean refundByOrderId(UUID orderId, String reason) {
        return paymentCancellationService.refundByOrderId(orderId, reason);
    }

    public PaymentResponseDto.Cancel executeCancel(PaymentRequestDto.Cancel request) {
        return paymentCancellationService.executeCancel(request);
    }

    public PaymentResponseDto.PartialCancel executePartialCancel(PaymentRequestDto.PartialCancel request) {
        return paymentCancellationService.executePartialCancel(request);
    }

    // ******* //
    // 빌링 인증 //
    // ******* //
    public PaymentResponseDto.SavedBillingKey saveBillingKey(PaymentRequestDto.SaveBillingKey request) {
        return billingAuthService.saveBillingKey(request);
    }

    public boolean hasBillingAuth(Integer userId) {
        return billingAuthService.hasBillingAuth(userId);
    }

    // ******* //
    // 결제 조회 //
    // ******* //
    public PaymentResponseDto.PaymentList getAllPayment() {
        return paymentQueryService.getAllPayments();
    }

    public PaymentResponseDto.PaymentDetail getDetailPayment(UUID paymentId) {
        return paymentQueryService.getPaymentDetail(paymentId);
    }

    public PaymentResponseDto.CancelList getAllPaymentCancel() {
        return paymentQueryService.getAllCancellations();
    }

    public PaymentResponseDto.CancelList getDetailPaymentCancel(UUID paymentId) {
        return paymentQueryService.getCancellationsByPaymentId(paymentId);
    }

    // ******** //
    // 소유권 검증 //
    // ******** //
    public void validateOrderStoreOwnership(UUID orderId, Integer userId) {
        paymentQueryService.validateOrderStoreOwnership(orderId, userId);
    }

    public void validatePaymentStoreOwnership(UUID paymentId, Integer userId) {
        paymentQueryService.validatePaymentStoreOwnership(paymentId, userId);
    }
    
    public boolean isAlreadyProcessed(UUID orderId) {
        return paymentRepository.findActivePaymentByOrderId(orderId).isPresent();
    }
}
