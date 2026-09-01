package com.example.Spot.order.domain.repository;

import java.time.LocalDate;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import com.example.Spot.order.domain.entity.OrderNumberCounterEntity;

import jakarta.persistence.LockModeType;

@Repository
public interface OrderNumberCounterRepository extends JpaRepository<OrderNumberCounterEntity, LocalDate> {

    @Modifying
    @Query(value = "INSERT INTO p_order_number_counter (order_date, last_order_num) " +
            "VALUES (:orderDate, 0) " +
            "ON CONFLICT (order_date) DO NOTHING",
            nativeQuery = true)
    int ensureOrderCounterExists(@Param("orderDate") LocalDate orderDate);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT o FROM OrderNumberCounterEntity o WHERE o.orderDate = :orderDate")
    Optional<OrderNumberCounterEntity> findByOrderDateWithLock(@Param("orderDate") LocalDate orderDate);
}
