'use client';

import React, {useState} from 'react';
import Link from 'next/link';
import {Button} from '@/components/ui/Button';
import {Input} from '@/components/ui/Input';
import {authApi} from '@/lib/auth';
import {useAuthStore} from '@/store/authStore';
import type {User} from '@/types';

export default function LoginPage() {
  const { setUser } = useAuthStore((state) => state.actions);
  const [formData, setFormData] = useState({
    username: '',
    password: '',
  });
  const [error, setError] = useState('');
  const [isLoading, setIsLoading] = useState(false);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, value } = e.target;
    setFormData((prev) => ({ ...prev, [name]: value }));
    setError('');
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);
    setError('');

    try {
      const loginData = await authApi.login(formData);
      const token = loginData.accessToken;
      if (!token) throw new Error('토큰을 찾을 수 없습니다.');

      const tokenInfo = authApi.parseToken(token);

      if (tokenInfo && tokenInfo.userId) {
        let userToSave: User;

        try {
          // 상세 정보 조회
          userToSave = await authApi.getMe(tokenInfo.userId);
        } catch (userError) {
          // 상세 조회가 실패해도 로그인 자체는 막지 않는다(토큰은 정상 발급됨).
          // 단 토큰으로 알 수 있는 것(id·username·role)만 저장하고 나머지는 "모름"으로 둔다.
          // 예전엔 email ''·age 0·male true 를 채워 넣어 여성 사용자도 "남성"으로 보이는 거짓 정보가 저장됐다.
          // 빠진 프로필은 마이페이지 진입 시 서버에서 다시 받아온다.
          console.error('사용자 정보 조회 실패, 토큰 정보만으로 로그인 진행:', userError);
          userToSave = {
            id: tokenInfo.userId,
            username: formData.username,
            // 토큰에 role 이 없을 일은 없지만, 만약 없으면 가장 낮은 권한으로(권한 상승 방향으로 추측하지 않음)
            role: tokenInfo.role || 'CUSTOMER',
          };
        }

        // zustand persist 가 동기적으로 localStorage 에 기록한다
        setUser(userToSave);
      }

      // 페이지 이동 (전체 새로고침으로 상태를 확실히 반영)
      window.location.replace('/');
    } catch (err) {
      const message = err instanceof Error ? err.message : '로그인 중 오류가 발생했습니다.';
      setError(message);
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-[80vh] flex items-center justify-center px-4">
      <div className="w-full max-w-md">
        <div className="bg-white rounded-2xl shadow-lg p-8">
          <div className="text-center mb-8">
            <h1 className="text-3xl font-bold text-gray-900">로그인</h1>
            <p className="mt-2 text-gray-600">HERE에 오신 것을 환영합니다</p>
          </div>

          <form onSubmit={handleSubmit} className="space-y-6">
            <Input
              label="아이디"
              name="username"
              type="text"
              placeholder="아이디를 입력하세요"
              value={formData.username}
              onChange={handleChange}
              required
            />

            <Input
              label="비밀번호"
              name="password"
              type="password"
              placeholder="비밀번호를 입력하세요"
              value={formData.password}
              onChange={handleChange}
              required
            />

            {error && (
              <div className="bg-red-50 text-red-500 text-sm p-3 rounded-lg">{error}</div>
            )}

            <Button type="submit" className="w-full" size="lg" isLoading={isLoading}>
              로그인
            </Button>
          </form>

          <div className="mt-6 text-center">
            <p className="text-gray-600">
              아직 계정이 없으신가요?{' '}
              <Link href="/join" className="text-orange-500 font-medium hover:underline">
                회원가입
              </Link>
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
