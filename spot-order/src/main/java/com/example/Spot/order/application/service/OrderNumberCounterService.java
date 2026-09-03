package com.example.Spot.order.application.service;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import com.example.Spot.order.domain.entity.OrderNumberCounterEntity;
import com.example.Spot.order.domain.repository.OrderNumberCounterRepository;

import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class OrderNumberCounterService {
    private final OrderNumberCounterRepository orderNumberCounterRepository;
    private static final DateTimeFormatter ORDER_DATE_FORMAT = DateTimeFormatter.ofPattern("yyyyMMdd");

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public String issueOrderNumber() {
        LocalDate today = LocalDate.now();

        orderNumberCounterRepository.ensureOrderCounterExists(today);

        OrderNumberCounterEntity counter = orderNumberCounterRepository
                .findByOrderDateWithLock(today)
                .orElseThrow(() -> new IllegalStateException(
                        "오늘자 주문번호 카운터 행이 존재하지 않습니다. orderDate: " + today));

        counter.increaseOrderNum();
        int lastOrderNum = counter.getLastOrderNum();

        return String.format("ORDER-%s-%04d", today.format(ORDER_DATE_FORMAT), lastOrderNum);
    }
}
