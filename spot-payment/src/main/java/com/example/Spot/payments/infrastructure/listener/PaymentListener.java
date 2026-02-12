package com.example.Spot.payments.infrastructure.listener;

import java.util.UUID;

import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.support.Acknowledgment;
import org.springframework.stereotype.Component;

import com.example.Spot.payments.application.service.PaymentService;
import com.example.Spot.payments.domain.entity.PaymentEntity;
import com.example.Spot.payments.infrastructure.event.subscribe.OrderCancelledEvent;
import com.example.Spot.payments.infrastructure.event.subscribe.OrderCreatedEvent;
import com.example.Spot.payments.infrastructure.temporal.config.PaymentConstants;
import com.example.Spot.payments.infrastructure.temporal.workflow.PaymentApproveWorkflow;
import com.example.Spot.payments.infrastructure.temporal.workflow.PaymentCancelWorkflow;
import com.example.Spot.payments.presentation.dto.request.PaymentRequestDto;
import com.fasterxml.jackson.databind.ObjectMapper;

import io.temporal.api.enums.v1.WorkflowIdReusePolicy;
import io.temporal.client.WorkflowClient;
import io.temporal.client.WorkflowExecutionAlreadyStarted;
import io.temporal.client.WorkflowOptions;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

@Slf4j
@Component
@RequiredArgsConstructor
public class PaymentListener {

    private final PaymentService paymentService;
    private final ObjectMapper objectMapper;
    private final WorkflowClient workflowClient;

    @KafkaListener(topics = "${spring.kafka.topic.order.created}", groupId = "${spring.kafka.consumer.group.payment}")
    public void handleOrderCreated(String message, Acknowledgment ack) {
        try {
            OrderCreatedEvent event = objectMapper.readValue(message, OrderCreatedEvent.class);
            log.info("[결제]주문 생성 이벤트 수신: orderId={}", event.getOrderId());

            // 1. 부족한 정보를 채워 DTO를 조립합니다.
            PaymentRequestDto.Confirm confirmRequest = PaymentRequestDto.Confirm.builder()
                    .title("Spot 주문 결제")
                    .content("자동 결제 시스템 처리")
                    .userId(event.getUserId())
                    .orderId(event.getOrderId())
                    .paymentMethod(PaymentEntity.PaymentMethod.CREDIT_CARD)
                    .paymentAmount(event.getAmount())
                    .build();

            // 2. 가공된 DTO를 서비스에 넘기기
            UUID paymentId = paymentService.ready(event.getUserId(), event.getOrderId(), confirmRequest);
            
            // 3. 결제 시도 및 결과에 따른 분기 처리
            WorkflowOptions options = WorkflowOptions.newBuilder()
                    .setWorkflowId("payment-wf-" + event.getOrderId())
                    .setTaskQueue(PaymentConstants.PAYMENT_TASK_QUEUE)
                    .setWorkflowIdReusePolicy(WorkflowIdReusePolicy.WORKFLOW_ID_REUSE_POLICY_REJECT_DUPLICATE)
                    .build();

            try {
                PaymentApproveWorkflow workflow = workflowClient.newWorkflowStub(PaymentApproveWorkflow.class, options);
                WorkflowClient.start(workflow::processApprove, paymentId);
                log.info("[결제] 새 워크플로우 시작: orderId={}, paymentId={}", event.getOrderId(), paymentId);
            } catch (WorkflowExecutionAlreadyStarted e) {
                log.info("[결제] 이미 진행 중인 워크플로우입니다. 스킵: orderId={}", event.getOrderId());
            }
            
            ack.acknowledge();
            log.info("[결제] 오프셋 커밋: paymentId={}", paymentId);
            
        } catch (Exception e) {
            log.error("[결제] 주문 이벤트 처리 및 워크플로우 시작 실패", e);
        }
    }
    
    // 고객취소, 가게취소, 주문거절 이벤트 수신 시 환불 처리
    @KafkaListener(topics = "${spring.kafka.topic.order.cancelled}", groupId = "${spring.kafka.consumer.group.payment}")
    public void handleOrderCancelled(String message, Acknowledgment ack) {
        try {
            OrderCancelledEvent event = objectMapper.readValue(message, OrderCancelledEvent.class);
            log.info("[결제] 주문 취소/거절 이벤트 수신: orderId={}, reason={}", event.getOrderId(), event.getReason());
            
            WorkflowOptions options = WorkflowOptions.newBuilder()
                    .setWorkflowId("cancel-wf-" + event.getOrderId())
                    .setTaskQueue(PaymentConstants.PAYMENT_TASK_QUEUE)
                    .setWorkflowIdReusePolicy(WorkflowIdReusePolicy.WORKFLOW_ID_REUSE_POLICY_REJECT_DUPLICATE)
                    .build();
            
            try {
                PaymentCancelWorkflow workflow = workflowClient.newWorkflowStub(PaymentCancelWorkflow.class, options);
                WorkflowClient.start(workflow::processCancel, event.getOrderId(), event.getReason());
                log.info("[결제] 취소 워크플로우 시작: orderId={}", event.getOrderId());
            } catch (WorkflowExecutionAlreadyStarted e) {
                log.info("[결제] 이미 진행 중인 취소 워크플로우입니다: orderId={}", event.getOrderId());
            }
            
            ack.acknowledge();

        } catch (Exception e) {
            log.error("[결제] 취소 이벤트 처리 실패: {}", e.getMessage());
        }
    }
}
