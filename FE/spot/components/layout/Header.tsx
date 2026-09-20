'use client';

import React from 'react';
import Link from 'next/link';
import {useRouter} from 'next/navigation';
import {useAuthStore} from '@/store/authStore';
import {useCartStore} from '@/store/cartStore';

export function Header() {
  const router = useRouter();
  const { user, isAuthenticated, hasHydrated: authHydrated, actions } = useAuthStore();
  const { getItemCount, hasHydrated: cartHydrated } = useCartStore();
  const itemCount = getItemCount();
  const hasHydrated = authHydrated && cartHydrated;

  const handleLogout = () => {
    actions.logout();
    router.push('/');
  };

  return (
    <header className="sticky top-0 z-50 bg-white border-b border-gray-200">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-16">
          {/* 로고 */}
          <Link href="/" className="flex items-center">
            <span className="text-2xl font-bold text-orange-500">SPOT</span>
            <span className="ml-2 text-sm text-gray-500">픽업 주문</span>
          </Link>

          {/* 검색바 */}
          <div className="hidden md:flex flex-1 max-w-lg mx-8">
            <div className="relative w-full">
              <input
                type="text"
                placeholder="가게 또는 메뉴 검색"
                className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-full focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent"
                onKeyDown={(e) => {
                  if (e.key === 'Enter') {
                    const target = e.target as HTMLInputElement;
                    router.push(`/search?q=${encodeURIComponent(target.value)}`);
                  }
                }}
              />
              <svg
                className="absolute left-3 top-1/2 transform -translate-y-1/2 h-5 w-5 text-gray-400"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
                />
              </svg>
            </div>
          </div>

          {/* 우측 메뉴 */}
          <div className="flex items-center space-x-4">
            {/* 장바구니 - CUSTOMER 역할만 표시 */}
            {hasHydrated && isAuthenticated && user?.role === 'CUSTOMER' && (
              <Link href="/cart" className="relative p-2 text-gray-600 hover:text-orange-500">
                <svg className="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M3 3h2l.4 2M7 13h10l4-8H5.4M7 13L5.4 5M7 13l-2.293 2.293c-.63.63-.184 1.707.707 1.707H17m0 0a2 2 0 100 4 2 2 0 000-4zm-8 2a2 2 0 11-4 0 2 2 0 014 0z"
                  />
                </svg>
                {itemCount > 0 && (
                  <span className="absolute -top-1 -right-1 bg-orange-500 text-white text-xs font-bold rounded-full h-5 w-5 flex items-center justify-center">
                    {itemCount}
                  </span>
                )}
              </Link>
            )}

            {!hasHydrated ? (
              <div className="w-24 h-8" />
            ) : isAuthenticated && user ? (
              <div className="flex items-center space-x-4">
                {/* 관리자 페이지 링크 - MASTER, MANAGER만 표시 */}
                {(user.role === 'MASTER' || user.role === 'MANAGER') && (
                  <Link
                    href="/admin"
                    className="text-gray-600 hover:text-orange-500 text-sm font-medium"
                  >
                    관리자
                  </Link>
                )}

                {/* CUSTOMER 메뉴 */}
                {user.role === 'CUSTOMER' && (
                  <Link
                    href="/orders"
                    className="text-gray-600 hover:text-orange-500 text-sm font-medium"
                  >
                    주문내역
                  </Link>
                )}

                {/* OWNER 메뉴 */}
                {user.role === 'OWNER' && (
                  <Link
                    href="/mypage/store"
                    className="text-gray-600 hover:text-orange-500 text-sm font-medium"
                  >
                    내 가게
                  </Link>
                )}

                {/* CHEF 메뉴 */}
                {user.role === 'CHEF' && (
                  <Link
                    href="/mypage/chef"
                    className="text-gray-600 hover:text-orange-500 text-sm font-medium"
                  >
                    소속 가게
                  </Link>
                )}

                <Link
                  href="/mypage"
                  className="text-gray-600 hover:text-orange-500 text-sm font-medium"
                >
                  {user.nickname || user.username}님
                </Link>
                <button
                  onClick={handleLogout}
                  className="text-gray-600 hover:text-orange-500 text-sm font-medium"
                >
                  로그아웃
                </button>
              </div>
            ) : (
              <div className="flex items-center space-x-2">
                <Link
                  href="/login"
                  className="px-4 py-2 text-sm font-medium text-gray-600 hover:text-orange-500"
                >
                  로그인
                </Link>
                <Link
                  href="/join"
                  className="px-4 py-2 text-sm font-medium text-white bg-orange-500 rounded-lg hover:bg-orange-600"
                >
                  회원가입
                </Link>
              </div>
            )}
          </div>
        </div>
      </div>
    </header>
  );
}

export default Header;
