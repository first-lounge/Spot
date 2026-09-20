package com.example.Spot.user.application.service;

import java.util.List;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.Spot.user.domain.entity.UserEntity;
import com.example.Spot.user.domain.repository.UserRepository;
import com.example.Spot.user.presentation.dto.request.UserUpdateRequestDTO;
import com.example.Spot.user.presentation.dto.response.UserResponseDTO;

import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class UserService {

    private final UserRepository userRepository;

    @Transactional(readOnly = true)
    public UserResponseDTO getUserById(Integer userid) {
        UserEntity user = userRepository.findById(userid)
                .orElseThrow(() -> new IllegalArgumentException("사용자를 찾을 수 없습니다."));
        return toResponse(user);
    }

    @Transactional
    public UserResponseDTO updateUserById(Integer userid, UserUpdateRequestDTO req) {
        UserEntity user = userRepository.findByIdWithLock(userid)
                .orElseThrow(() -> new IllegalArgumentException("사용자를 찾을 수 없습니다."));

        if (req.nickname() != null) {
            user.setNickname(req.nickname());
        }
        if (req.email() != null) {
            user.setEmail(req.email());
        }
        if (req.roadAddress() != null || req.addressDetail() != null) {
            user.setAddress(
                    req.roadAddress() != null ? req.roadAddress() : user.getRoadAddress(),
                    req.addressDetail() != null ? req.addressDetail() : user.getAddressDetail()
            );
        }

        return toResponse(user);
    }

    @Transactional
    public void deleteUserById(Integer loginUserId) {
        UserEntity user = userRepository.findByIdWithLock(loginUserId)
                .orElseThrow(() -> new IllegalArgumentException("사용자를 찾을 수 없습니다."));

        user.softDelete(user.getId());
    }
    
    private UserResponseDTO toResponse(UserEntity user) {
        return new UserResponseDTO(
                user.getId(),
                user.getUsername(),
                user.getRole(),
                user.getNickname(),
                user.getEmail(),
                user.getRoadAddress(),
                user.getAddressDetail(),
                user.getAge(),
                user.isMale()
        );
    }
    
    @Transactional(readOnly = true)
    public List<UserResponseDTO> searchUsersByNickname(String nickname) {
        List<UserEntity> users = userRepository.findByNickname(nickname);

        if (users.isEmpty()) {
            throw new IllegalArgumentException("사용자를 찾을 수 없습니다.");
        }
            
        return users.stream()
                .map(this::toResponse)
                .collect(Collectors.toList());
    }
}
