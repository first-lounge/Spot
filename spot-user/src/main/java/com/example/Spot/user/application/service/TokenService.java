package com.example.Spot.user.application.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.Spot.auth.jwt.JWTUtil;
import com.example.Spot.user.domain.Role;
import com.example.Spot.user.domain.repository.UserRepository;

import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class TokenService {

    private final JWTUtil jwtUtil;
    private final UserRepository userRepository;

    @Value("${security.refresh-token.expire-days:30}")
    private long refreshExpireDays;

    // ************************ //
    // Access, Refresh 토큰 재발급 //
    // ************************ //
    @Transactional(readOnly = true)
    public ReissueResult reissueByRefresh(String refreshToken) {

        if (jwtUtil.isExpired(refreshToken)) {
            throw new IllegalArgumentException("Refresh token expired");
        }

        String type = jwtUtil.getTokenType(refreshToken);
        if (!"refresh".equals(type)) {
            throw new IllegalArgumentException("Not a refresh token");
        }

        Integer userId = jwtUtil.getUserId(refreshToken);

        // 권한은 DB에서 최신 role 조회
        Role role = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("User not found")).getRole();

        long accessExpMs = 1000L * 60 * 30; // 30분
        String newAccess = jwtUtil.createJwt(userId, role, accessExpMs);

        // refresh도 같이 새로 발급해 rotate처럼 운영
        long refreshExpMs = refreshExpireDays * 24L * 60L * 60L * 1000L;
        String newRefresh = jwtUtil.createRefreshToken(userId, refreshExpMs);

        return new ReissueResult(newAccess, newRefresh);
    }

    // logout: stateless (클라이언트가 토큰 삭제)
    public void logoutStateless() {
        // no-op
    }

    public record ReissueResult(String accessToken, String refreshToken) {}
}
