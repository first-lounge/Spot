package com.example.Spot.order.application.service;

import java.math.BigDecimal;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.Spot.global.feign.dto.MenuOptionResponse;
import com.example.Spot.global.feign.dto.MenuResponse;
import com.example.Spot.order.domain.entity.OrderEntity;
import com.example.Spot.order.domain.entity.OrderItemEntity;
import com.example.Spot.order.domain.entity.OrderItemOptionEntity;
import com.example.Spot.order.domain.enums.CancelledBy;
import com.example.Spot.order.domain.enums.OrderStatus;
import com.example.Spot.order.domain.repository.OrderRepository;
import com.example.Spot.order.infrastructure.producer.OrderEventProducer;
import com.example.Spot.order.presentation.dto.request.OrderCreateRequestDto;
import com.example.Spot.order.presentation.dto.request.OrderItemOptionRequestDto;
import com.example.Spot.order.presentation.dto.request.OrderItemRequestDto;
import com.example.Spot.order.presentation.dto.response.OrderContextDto;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

@Slf4j
@Service
@RequiredArgsConstructor
public class OrderCreationService {

    private static final String CREATION_FAILED_REASON = "시스템 오류로 주문이 접수되지 않았습니다.";

    private final OrderRepository orderRepository;
    private final OrderEventProducer orderEventProducer;

    // 잠금 → 존재 확인 → 저장 → outbox 예약을 한 트랜잭션으로 묶음
    // 주문번호 발급(REQUIRES_NEW)은 이 트랜잭션 밖에서 끝낸 뒤 값만 받음(커넥션을 동시에 2개 잡지 않기 위해)
    @Transactional(timeout = 3)
    public void saveOrder(UUID orderId, Integer userId, String orderNumber, OrderCreateRequestDto requestDto, OrderContextDto contextDto) {
        lockOrder(orderId);

        if (orderRepository.existsById(orderId)) {
            log.info("해당 주문은 이미 처리되었습니다. orderId={}", orderId);
            return;
        }

        BuiltOrder built = buildOrder(orderId, userId, orderNumber, requestDto, contextDto);

        orderRepository.save(built.order());

        orderEventProducer.reserveOrderCreated(
                orderId,
                userId,
                built.totalAmount().longValue()
        );

        log.info("주문 생성이 완료되었습니다. OrderID: {}, OrderNumber: {}", orderId, orderNumber);
    }

    // 주문 저장이 재시도를 다 쓰고 실패했을 때 호출
    @Transactional(timeout = 3)
    public void saveFailedOrder(UUID orderId, Integer userId, String orderNumber, OrderCreateRequestDto requestDto, OrderContextDto contextDto) {
        lockOrder(orderId);

        if (orderRepository.existsById(orderId)) {
            log.warn("주문 생성 실패 기록을 남기려 했지만 주문이 이미 존재합니다. orderId={}", orderId);
            return;
        }

        OrderEntity order = buildOrder(orderId, userId, orderNumber, requestDto, contextDto).order();
        order.cancelOrder(CREATION_FAILED_REASON, CancelledBy.SYSTEM);

        orderRepository.save(order);

        log.warn("주문 생성 실패 기록을 남겼습니다. OrderID: {}, OrderNumber: {}", orderId, orderNumber);
    }

    // 같은 주문 ID로 동시에 들어온 시도 중 하나만 통과시킴
    private void lockOrder(UUID orderId) {
        // UUID → long
        long key = orderId.getMostSignificantBits() ^ orderId.getLeastSignificantBits();

        // lock 시도
        if (!orderRepository.lockByKey(key)) {
            log.info("해당 주문 ID는 처리 중 입니다. orderId={}", orderId);
            throw new IllegalStateException("주문을 처리 중입니다. orderId=" + orderId);
        }
    }

    private BuiltOrder buildOrder(UUID orderId, Integer userId, String orderNumber, OrderCreateRequestDto requestDto, OrderContextDto contextDto) {
        BigDecimal totalAmount = BigDecimal.ZERO;

        OrderEntity order = OrderEntity.builder()
                .id(orderId)
                .storeId(contextDto.getStore().getId())
                .userId(userId)
                .orderNumber(orderNumber)
                .pickupTime(requestDto.getPickupTime())
                .needDisposables(requestDto.getNeedDisposables())
                .request(requestDto.getRequest())
                .orderStatus(OrderStatus.PAYMENT_PENDING)
                .build();

        for (OrderItemRequestDto itemDto : requestDto.getOrderItems()) {
            MenuResponse menu = contextDto.getMenuMap().get(itemDto.getMenuId());
            BigDecimal itemPrice = BigDecimal.valueOf(menu.getPrice());

            // 총액 합산 로직
            totalAmount = totalAmount.add(itemPrice.multiply(BigDecimal.valueOf(itemDto.getQuantity())));

            OrderItemEntity orderItem = OrderItemEntity.builder()
                    .menuId(menu.getId())
                    .menuName(menu.getName())
                    .menuPrice(itemPrice)
                    .quantity(itemDto.getQuantity())
                    .build();

            for (OrderItemOptionRequestDto optionDto : itemDto.getOptions()) {
                MenuOptionResponse menuOption = contextDto.getOptionMap().get(optionDto.getMenuOptionId());
                BigDecimal optionPrice = BigDecimal.valueOf(menuOption.getPrice());

                // 옵션 총액 합산
                totalAmount = totalAmount.add(optionPrice);

                OrderItemOptionEntity orderItemOption = OrderItemOptionEntity.builder()
                        .menuOptionId(menuOption.getId())
                        .optionName(menuOption.getName())
                        .optionDetail(menuOption.getDetail())
                        .optionPrice(optionPrice)
                        .build();

                orderItem.addOrderItemOption(orderItemOption);
            }
            order.addOrderItem(orderItem);
        }

        return new BuiltOrder(order, totalAmount);
    }

    private record BuiltOrder(OrderEntity order, BigDecimal totalAmount) {
    }
}
