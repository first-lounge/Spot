package com.example.Spot.user.domain.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.example.Spot.user.domain.entity.UserEntity;

import jakarta.persistence.LockModeType;

public interface UserRepository extends JpaRepository<UserEntity, Integer> {

    boolean existsByUsername(String username);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT u FROM UserEntity u WHERE u.username = :username")
    Optional<UserEntity> findByUsernameWithLock(@Param("username") String username);

    Optional<UserEntity> findByUsername(String username);
    Optional<UserEntity> findRoleById(Integer id);
    
    Optional<UserEntity> findById(Integer id);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT u FROM UserEntity u WHERE u.id = :id")
    Optional<UserEntity> findByIdWithLock(@Param("id") Integer id);
    
    @Query("SELECT u FROM UserEntity u WHERE u.nickname = :nickname")    
    List<UserEntity> findByNickname(@Param("nickname") String nickname);
}

