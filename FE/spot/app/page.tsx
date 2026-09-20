'use client';

import React, {useEffect, useState} from 'react';
import Link from 'next/link';
import {storeApi} from '@/lib/stores';
import type {Category, Store} from '@/types';

export default function HomePage() {
  const [stores, setStores] = useState<Store[]>([]);
  const [categories, setCategories] = useState<Category[]>([]);
  const [selectedCategory, setSelectedCategory] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  // 카테고리는 마운트 시 1회만
  useEffect(() => {
    const loadCategories = async () => {
      try {
        setCategories((await storeApi.getCategories()) || []);
      } catch (error) {
        console.error('Failed to load categories:', error);
      }
    };
    loadCategories();
  }, []);

  // 가게 목록은 선택된 카테고리가 바뀔 때마다 (마운트 시에는 selectedCategory=null 이라 전체 조회)
  // 이전에는 마운트 시 두 effect 가 동시에 가게 목록을 두 번 요청했다
  useEffect(() => {
    let cancelled = false;

    const loadStores = async () => {
      setIsLoading(true);
      try {
        const data = selectedCategory
          ? await storeApi.getStoresByCategory(selectedCategory)
          : await storeApi.getStores();
        if (!cancelled) setStores(data.content || []);
      } catch (error) {
        console.error('Failed to load stores:', error);
      } finally {
        if (!cancelled) setIsLoading(false);
      }
    };
    loadStores();

    // 카테고리를 빠르게 바꿨을 때 늦게 도착한 이전 응답이 화면을 덮어쓰지 않도록
    return () => {
      cancelled = true;
    };
  }, [selectedCategory]);

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      {/* 히어로 섹션 */}
      <div className="bg-gradient-to-r from-orange-500 to-orange-600 rounded-2xl p-8 mb-8 text-white">
        <h1 className="text-3xl md:text-4xl font-bold mb-4">
          빠르고 편리한
          <br />
          음식 픽업 서비스
        </h1>
        <p className="text-orange-100 mb-6">
          원하는 음식을 미리 주문하고, 대기 없이 바로 픽업하세요!
        </p>
        <div className="flex flex-wrap gap-3">
          <span className="bg-white/20 px-4 py-2 rounded-full text-sm">빠른 픽업</span>
          <span className="bg-white/20 px-4 py-2 rounded-full text-sm">간편 결제</span>
          <span className="bg-white/20 px-4 py-2 rounded-full text-sm">다양한 메뉴</span>
        </div>
      </div>

      {/* 카테고리 */}
      <div className="mb-8">
        <h2 className="text-xl font-bold text-gray-900 mb-4">카테고리</h2>
        <div className="flex flex-wrap gap-2">
          <button
            onClick={() => setSelectedCategory(null)}
            className={`px-4 py-2 rounded-full text-sm font-medium transition-colors ${
              selectedCategory === null
                ? 'bg-orange-500 text-white'
                : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
            }`}
          >
            전체
          </button>
          {categories.map((category) => (
            <button
              key={category.id}
              onClick={() => setSelectedCategory(category.name)}
              className={`px-4 py-2 rounded-full text-sm font-medium transition-colors ${
                selectedCategory === category.name
                  ? 'bg-orange-500 text-white'
                  : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
              }`}
            >
              {category.name}
            </button>
          ))}
        </div>
      </div>

      {/* 가게 목록 */}
      <div>
        <h2 className="text-xl font-bold text-gray-900 mb-4">
          {selectedCategory ? `${selectedCategory} 맛집` : '전체 가게'}
        </h2>

        {isLoading ? (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
            {[...Array(6)].map((_, i) => (
              <div key={i} className="bg-gray-100 rounded-xl h-64 animate-pulse" />
            ))}
          </div>
        ) : stores.length === 0 ? (
          <div className="text-center py-12">
            <p className="text-gray-500">등록된 가게가 없습니다.</p>
          </div>
        ) : (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
            {stores.map((store) => (
              <Link
                key={store.id}
                href={`/stores/${store.id}`}
                className="bg-white rounded-xl shadow-md overflow-hidden hover:shadow-lg transition-shadow"
              >
                {/* 가게 이미지 플레이스홀더 */}
                <div className="bg-gradient-to-br from-orange-100 to-orange-200 h-40 flex items-center justify-center">
                  <span className="text-4xl">🏪</span>
                </div>

                <div className="p-4">
                  <h3 className="font-bold text-lg text-gray-900 mb-1">{store.name}</h3>
                  <p className="text-sm text-gray-500 mb-2">
                    {store.roadAddress} {store.addressDetail}
                  </p>
                  <div className="flex items-center justify-between text-sm">
                    {/* 목록 응답(StoreListResponse)에는 영업시간이 없고 카테고리별 조회에만 있다 */}
                    {store.openTime && store.closeTime ? (
                      <span className="text-gray-600">
                        {store.openTime} - {store.closeTime}
                      </span>
                    ) : (
                      <span className="text-gray-400">
                        {store.categoryNames?.join(' · ') || ''}
                      </span>
                    )}
                    {store.phoneNumber && (
                      <span className="text-gray-400">{store.phoneNumber}</span>
                    )}
                  </div>
                </div>
              </Link>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
