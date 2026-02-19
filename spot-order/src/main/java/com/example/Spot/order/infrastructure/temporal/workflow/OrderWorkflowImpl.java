package com.example.Spot.order.infrastructure.temporal.workflow;

import java.time.Duration;
import java.util.UUID;

import org.springframework.stereotype.Component;

import com.example.Spot.order.domain.enums.CancelledBy;
import com.example.Spot.order.domain.enums.OrderStatus;
import com.example.Spot.order.infrastructure.temporal.activity.OrderActivity;
import com.example.Spot.order.infrastructure.temporal.config.OrderConstants;
import com.example.Spot.order.infrastructure.temporal.dto.OrderStatusUpdate;
import com.example.Spot.order.presentation.dto.request.OrderCreateRequestDto;
import com.example.Spot.order.presentation.dto.response.OrderContextDto;

import io.temporal.activity.ActivityOptions;
import io.temporal.common.RetryOptions;
import io.temporal.spring.boot.WorkflowImpl;
import io.temporal.workflow.ChildWorkflowOptions;
import io.temporal.workflow.ChildWorkflowStub;
import io.temporal.workflow.Workflow;

@Component
@WorkflowImpl(taskQueues = OrderConstants.ORDER_TASK_QUEUE)
public class OrderWorkflowImpl implements OrderWorkflow {

    private OrderStatus currentStatus = OrderStatus.PAYMENT_PENDING;
    private Integer estimatedTime;
    private String reason;
    private CancelledBy actor;
    private boolean isRefundCompleted = false;

    private static final ActivityOptions ACTIVITY_OPTIONS = ActivityOptions.newBuilder()
            .setStartToCloseTimeout(Duration.ofSeconds(10))
            .setRetryOptions(RetryOptions.newBuilder().setMaximumAttempts(5).build())
            .build();

    @Override
    public void processOrder(UUID orderId, Integer userId, OrderCreateRequestDto requestDto, OrderContextDto contextDto) {
        OrderActivity activities = Workflow.newActivityStub(OrderActivity.class, ACTIVITY_OPTIONS);
        activities.createOrderInDb(orderId, userId, requestDto, contextDto);

        ChildWorkflowStub paymentStub = Workflow.newUntypedChildWorkflowStub("PaymentApproveWorkflow",
                ChildWorkflowOptions.newBuilder()
                        .setWorkflowId("payment-wf-" + orderId) // Payment 서비스가 사용할 ID와 일치시켜야 함
                        .setTaskQueue("PAYMENT_TASK_QUEUE") // PaymentConstants.PAYMENT_TASK_QUEUE 값과 일치해야 함
                        .build());
        try {
            paymentStub.execute(Void.class, orderId);
        } catch (Exception e) {
            // 결제 워크플로우 실패 시 예외가 이쪽으로 전파됩니다.
        }
        
        Workflow.await(Duration.ofMinutes(5),
                () -> currentStatus == OrderStatus.PENDING || currentStatus.isFinalStatus() || currentStatus == OrderStatus.CANCEL_PENDING);
        if (currentStatus == OrderStatus.PENDING) {
            activities.updateOrderStatusInDb(orderId, OrderStatus.PENDING, null, null, null);
        } else {
            handleCancelOrRejectIfNecessary(orderId, activities, "결제 단계 취소/타임아웃");
            return;
        }

        boolean isAccepted = Workflow.await(Duration.ofMinutes(10),
                () -> currentStatus == OrderStatus.ACCEPTED || currentStatus == OrderStatus.CANCEL_PENDING || currentStatus == OrderStatus.REJECT_PENDING || currentStatus.isFinalStatus());

        if (isAccepted && currentStatus == OrderStatus.ACCEPTED) {
            activities.updateOrderStatusInDb(orderId, OrderStatus.ACCEPTED, this.estimatedTime, null, null);
        } else {
            if (!isAccepted) {
                this.currentStatus = OrderStatus.CANCEL_PENDING;
                this.reason = "타임아웃으로 인한 자동취소";
                this.actor = CancelledBy.SYSTEM;
            }
            handleCancelOrRejectIfNecessary(orderId, activities, "점주 미수락/거절");
            return;
        }

        // 4. 조리 단계 (COOKING)
        if (waitForStatusAndUpdate(orderId, OrderStatus.COOKING, activities)) {
            return;
        }
        if (waitForStatusAndUpdate(orderId, OrderStatus.READY, activities)) {
            return;
        }
        if (waitForStatusAndUpdate(orderId, OrderStatus.COMPLETED, activities)) {
            return;
        }
    }

    private boolean handleCancelOrRejectIfNecessary(UUID orderId, OrderActivity activities, String defaultReason) {
        if (currentStatus == OrderStatus.CANCEL_PENDING || currentStatus == OrderStatus.REJECT_PENDING) {
            String finalReason = (this.reason != null) ? this.reason : defaultReason;
            CancelledBy finalActor = this.actor;
            if (currentStatus == OrderStatus.CANCEL_PENDING && finalActor == null) {
                finalActor = CancelledBy.SYSTEM;
            }

            activities.updateOrderStatusInDb(orderId, currentStatus, null, finalReason, finalActor);

            ChildWorkflowStub cancelStub = Workflow.newUntypedChildWorkflowStub("PaymentCancelWorkflow",
                    ChildWorkflowOptions.newBuilder()
                            .setWorkflowId("cancel-wf-" + orderId)
                            .setTaskQueue("PAYMENT_TASK_QUEUE") // 반드시 결제 큐 지정
                            .build());
            try {
                // 리스너가 던지는 (orderId, reason) 파라미터와 형식을 맞춥니다.
                cancelStub.execute(Void.class, orderId, finalReason);
                // Workflow.getWorkflowExecution(cancelStub); // 만약 비동기로 넘기고 싶다면 이 방식 사용
            } catch (Exception e) {
                // 이미 리스너가 해당 ID로 실행을 완료했거나 진행 중일 때 발생하는 에러는 
                // 부모-자식 관계가 맺어졌다면 무시해도 무방합니다.
            }
            
            waitForRefundAndFinalize(orderId, activities);
            return true;
        }
        return currentStatus.isFinalStatus();
    }

    private void waitForRefundAndFinalize(UUID orderId, OrderActivity activities) {
        boolean isSuccess = Workflow.await(Duration.ofMinutes(30), () -> isRefundCompleted);
        if (isSuccess) {
            activities.finalizeOrder(orderId);
        } else {
            activities.handleRefundTimeout(orderId);
        }
    }

    private boolean waitForStatusAndUpdate(UUID orderId, OrderStatus targetStatus, OrderActivity activities) {
        Workflow.await(() -> currentStatus == targetStatus || currentStatus == OrderStatus.CANCEL_PENDING
                || currentStatus.isFinalStatus());
        if (currentStatus == targetStatus) {
            activities.updateOrderStatusInDb(orderId, targetStatus, null, null, null);
            return false;
        }
        handleCancelOrRejectIfNecessary(orderId, activities, "진행 중 취소/거절");
        return true;
    }

    @Override
    public void signalStatusChanged(OrderStatusUpdate update) {
        if (this.currentStatus.isFinalStatus()) {
            return;
        }
        if (update.getStatus() == OrderStatus.REJECT_PENDING) {
            if (this.currentStatus != OrderStatus.PENDING) {
                return;
            }
        }
        this.currentStatus = update.getStatus();
        this.estimatedTime = update.getEstimatedTime();
        this.reason = update.getReason();
        this.actor = update.getCancelledBy();
    }

    @Override
    public void signalRefundCompleted() {
        this.isRefundCompleted = true;
    }
}
