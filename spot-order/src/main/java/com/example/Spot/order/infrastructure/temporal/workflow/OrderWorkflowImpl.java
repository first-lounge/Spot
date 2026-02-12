package com.example.Spot.order.infrastructure.temporal.workflow;

import java.time.Duration;
import java.util.UUID;

import org.springframework.stereotype.Component;

import com.example.Spot.order.domain.enums.OrderStatus;
import com.example.Spot.order.infrastructure.temporal.activity.OrderActivity;
import com.example.Spot.order.infrastructure.temporal.config.OrderConstants;

import io.temporal.activity.ActivityOptions;
import io.temporal.common.RetryOptions;
import io.temporal.spring.boot.WorkflowImpl;
import io.temporal.workflow.Workflow;

@Component
@WorkflowImpl(taskQueues = OrderConstants.ORDER_TASK_QUEUE)
public class OrderWorkflowImpl implements OrderWorkflow {

    private static final ActivityOptions ACTIVITY_OPTIONS = ActivityOptions.newBuilder()
            .setStartToCloseTimeout(Duration.ofSeconds(10))
            .setRetryOptions(RetryOptions.newBuilder().setMaximumAttempts(5).build())
            .build();
    
    private OrderStatus currentStatus = OrderStatus.PAYMENT_PENDING;
    private boolean isRefundCompleted = false;
    
    @Override
    public void processOrder(UUID orderId) {
        OrderActivity activities = Workflow.newActivityStub(OrderActivity.class, ACTIVITY_OPTIONS);
        
        boolean paidWithinTime = Workflow.await(Duration.ofMinutes(5),
                () -> currentStatus == OrderStatus.PENDING || currentStatus.isFinalStatus());
        
        if (!paidWithinTime && currentStatus == OrderStatus.PAYMENT_PENDING) {
            activities.cancelOrder(orderId, "결제 시간 초과로 인한 자동 취소");
            if (currentStatus == OrderStatus.CANCEL_PENDING) {
                waitForRefundAndFinalize(orderId, activities);
                return;
            }
            return;
        }

        Workflow.await(Duration.ofMinutes(10), () -> currentStatus == OrderStatus.ACCEPTED || isTrulyFinalStatus(currentStatus));
        if (handleCancelIfNecessary(orderId, activities)) {
            return;
        }
        
        Workflow.await(() -> currentStatus == OrderStatus.COOKING || isTrulyFinalStatus(currentStatus));
        if (handleCancelIfNecessary(orderId, activities)) {
            return;
        }
        
        Workflow.await(() -> currentStatus == OrderStatus.READY || isTrulyFinalStatus(currentStatus));
        if (handleCancelIfNecessary(orderId, activities)) {
            return;
        }
        
        Workflow.await(() -> currentStatus == OrderStatus.COMPLETED || isTrulyFinalStatus(currentStatus));
        if (handleCancelIfNecessary(orderId, activities)) {
            return;
        }
    }
    
    private boolean handleCancelIfNecessary(UUID orderId, OrderActivity activities) {
        if (currentStatus == OrderStatus.CANCEL_PENDING) {
            waitForRefundAndFinalize(orderId, activities);
            return true;
        }
        return currentStatus.isFinalStatus();
    }

    private void waitForRefundAndFinalize(UUID orderId, OrderActivity activities) {
        Workflow.await(() -> isRefundCompleted);
        activities.finalizeOrder(orderId);
    }

    @Override
    public void signalStatusChanged(OrderStatus nextStatus) {
        this.currentStatus = nextStatus;
    }

    @Override
    public void signalRefundCompleted() {
        this.isRefundCompleted = true;
    }

    private boolean isTrulyFinalStatus(OrderStatus status) {
        return status == OrderStatus.COMPLETED || status == OrderStatus.CANCELLED || status == OrderStatus.REJECTED;
    }
}
