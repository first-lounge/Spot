'use client';

import React, {useEffect, useState} from 'react';
import {useRouter} from 'next/navigation';
import Link from 'next/link';
import {useAuthStore} from '@/store/authStore';
import {authApi} from '@/lib/auth';

/** 모르는 값은 "-"로. 빈 문자열도 모름으로 취급한다. */
const orDash = (value: string | number | null | undefined): string =>
  value === null || value === undefined || value === '' ? '-' : String(value);

export default function MyPage() {
  const router = useRouter();
  const { user, isAuthenticated, hasHydrated, actions } = useAuthStore();
  const [isDeleting, setIsDeleting] = useState(false);
  const [profileError, setProfileError] = useState(false);

  useEffect(() => {
    if (hasHydrated && !isAuthenticated) {
      router.push('/login');
    }
  }, [hasHydrated, isAuthenticated, router]);

  // 마이페이지에 들어올 때마다 서버에서 최신 프로필을 다시 받는다.
  // 로그인 시점에 조회가 실패해 id·username·role 만 저장됐거나, 다른 기기에서 정보를 바꾼 경우를 메운다.
  // deps 를 user 전체가 아니라 id 로 두는 이유: setUser 가 user 객체를 바꾸면 무한 재요청이 되기 때문.
  const userId = user?.id;
  useEffect(() => {
    if (!hasHydrated || userId == null) return;

    let cancelled = false;
    const refreshProfile = async () => {
      try {
        const fresh = await authApi.getMe(userId);
        if (!cancelled) {
          actions.setUser(fresh);
          setProfileError(false);
        }
      } catch (error) {
        // 실패해도 저장된 정보는 그대로 보여주되, "최신이 아닐 수 있음"을 화면에 알린다(조용히 넘기지 않음)
        console.error('프로필 조회 실패:', error);
        if (!cancelled) setProfileError(true);
      }
    };
    refreshProfile();

    return () => {
      cancelled = true;
    };
  }, [hasHydrated, userId, actions]);

  const handleLogout = async () => {
    // 서버 로그아웃(현재 no-op)을 먼저 시도하고, 결과와 무관하게 클라이언트 상태를 지운다
    await authApi.logout();
    actions.logout();
    router.push('/');
  };

  const handleDeleteAccount = async () => {
    if (!confirm('정말 탈퇴하시겠습니까?\n탈퇴 후에는 주문 내역 등 모든 정보에 접근할 수 없습니다.')) {
      return;
    }

    setIsDeleting(true);
    try {
      await authApi.deleteMe();
      actions.logout();
      alert('회원 탈퇴가 완료되었습니다.');
      router.push('/');
    } catch (error) {
      console.error('회원 탈퇴 실패:', error);
      alert('회원 탈퇴에 실패했습니다. 잠시 후 다시 시도해주세요.');
    } finally {
      setIsDeleting(false);
    }
  };

  if (!hasHydrated || !user) {
    return null;
  }

  const roleLabels: Record<string, string> = {
    CUSTOMER: '일반 회원',
    OWNER: '가게 사장',
    CHEF: '요리사',
    MANAGER: '관리자',
    MASTER: '마스터',
  };

  return (
    <div className="max-w-2xl mx-auto px-4 py-8">
      <h1 className="text-2xl font-bold text-gray-900 mb-6">마이페이지</h1>

      {profileError && (
        <div className="bg-yellow-50 text-yellow-800 text-sm p-3 rounded-lg mb-4">
          최신 회원 정보를 불러오지 못했습니다. 일부 정보가 표시되지 않을 수 있습니다.
        </div>
      )}

      {/* 프로필 카드 */}
      <div className="bg-white rounded-xl shadow-md p-6 mb-6">
        <div className="flex items-center gap-4 mb-6">
          <div className="w-16 h-16 bg-orange-100 rounded-full flex items-center justify-center">
            <span className="text-2xl">👤</span>
          </div>
          <div>
            {/* 닉네임을 모르면 아이디로 표시(아이디는 토큰으로 항상 앎) */}
            <h2 className="text-xl font-bold text-gray-900">{user.nickname || user.username}</h2>
            <p className="text-gray-500">{roleLabels[user.role]}</p>
          </div>
        </div>

        <div className="space-y-4">
          <div className="flex justify-between py-3 border-b">
            <span className="text-gray-600">아이디</span>
            <span className="text-gray-900">{user.username}</span>
          </div>
          <div className="flex justify-between py-3 border-b">
            <span className="text-gray-600">이메일</span>
            <span className="text-gray-900">{orDash(user.email)}</span>
          </div>
          <div className="flex justify-between py-3 border-b">
            <span className="text-gray-600">성별</span>
            <span className="text-gray-900">
              {/* null 이면 "여성"으로 떨어지던 삼항을 명시적으로 3갈래로 */}
              {user.male === true ? '남성' : user.male === false ? '여성' : '-'}
            </span>
          </div>
          <div className="flex justify-between py-3 border-b">
            <span className="text-gray-600">나이</span>
            <span className="text-gray-900">{user.age != null ? `${user.age}세` : '-'}</span>
          </div>
          {user.roadAddress && (
            <div className="flex justify-between py-3 border-b">
              <span className="text-gray-600">주소</span>
              <span className="text-gray-900 text-right">
                {user.roadAddress}
                {user.addressDetail && <br />}
                {user.addressDetail}
              </span>
            </div>
          )}
        </div>
      </div>

      {/* 메뉴 */}
      <div className="bg-white rounded-xl shadow-md divide-y">
        {/* CUSTOMER 전용 메뉴 */}
        {user.role === 'CUSTOMER' && (
          <>
            <Link
              href="/orders"
              className="flex items-center justify-between p-4 hover:bg-gray-50"
            >
              <div className="flex items-center gap-3">
                <span className="text-xl">📋</span>
                <span className="text-gray-900">주문 내역</span>
              </div>
              <svg className="w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
              </svg>
            </Link>

            <Link
              href="/cart"
              className="flex items-center justify-between p-4 hover:bg-gray-50"
            >
              <div className="flex items-center gap-3">
                <span className="text-xl">🛒</span>
                <span className="text-gray-900">장바구니</span>
              </div>
              <svg className="w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
              </svg>
            </Link>
          </>
        )}

        {/* OWNER 전용 메뉴 */}
        {user.role === 'OWNER' && (
          <Link
            href="/mypage/store"
            className="flex items-center justify-between p-4 hover:bg-gray-50"
          >
            <div className="flex items-center gap-3">
              <span className="text-xl">🏪</span>
              <span className="text-gray-900">내 가게 관리</span>
            </div>
            <svg className="w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
            </svg>
          </Link>
        )}

        {/* CHEF 전용 메뉴 */}
        {user.role === 'CHEF' && (
          <Link
            href="/mypage/chef"
            className="flex items-center justify-between p-4 hover:bg-gray-50"
          >
            <div className="flex items-center gap-3">
              <span className="text-xl">👨‍🍳</span>
              <span className="text-gray-900">소속 가게 등록</span>
            </div>
            <svg className="w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
            </svg>
          </Link>
        )}

        <button
          onClick={handleLogout}
          className="flex items-center justify-between p-4 hover:bg-gray-50 w-full text-left"
        >
          <div className="flex items-center gap-3">
            <span className="text-xl">🚪</span>
            <span className="text-red-500">로그아웃</span>
          </div>
        </button>
      </div>

      {/* 회원 탈퇴 */}
      <div className="mt-8 text-center">
        <button
          type="button"
          onClick={handleDeleteAccount}
          disabled={isDeleting}
          className="text-sm text-gray-400 hover:text-gray-600 disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {isDeleting ? '탈퇴 처리 중...' : '회원 탈퇴'}
        </button>
      </div>
    </div>
  );
}
