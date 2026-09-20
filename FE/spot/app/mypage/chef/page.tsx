'use client';

import React, {useEffect, useState} from 'react';
import {useRouter} from 'next/navigation';
import axios from 'axios';
import {useAuthStore} from '@/store/authStore';
import {Button} from '@/components/ui/Button';
import {Input} from '@/components/ui/Input';
import api from '@/lib/api';
import type {ApiResponse, PageResponse, Store} from '@/types';

/**
 * ⚠️ `/api/chefs/**` 엔드포인트는 백엔드에 아직 없다 (ROADMAP F2-1).
 * 백엔드가 준비되면 lib/chefs.ts 로 옮기고 이 파일의 호출부만 바꾸면 된다.
 */
const chefApi = {
  getMyStore: async (): Promise<Store | null> => {
    try {
      const response = await api.get<ApiResponse<Store>>('/api/chefs/my-store');
      return response.data.result ?? null;
    } catch (error) {
      // 소속 가게가 없으면 404 — 정상 상태
      if (axios.isAxiosError(error) && error.response?.status === 404) {
        return null;
      }
      throw error;
    }
  },
  getApprovedStores: async (): Promise<Store[]> => {
    const response = await api.get<ApiResponse<PageResponse<Store>> | PageResponse<Store>>(
      '/api/stores',
      { params: { status: 'APPROVED' } }
    );
    const data = response.data as ApiResponse<PageResponse<Store>> & PageResponse<Store>;
    return data.result?.content ?? data.content ?? [];
  },
  joinStore: async (storeId: string): Promise<void> => {
    await api.post(`/api/chefs/join-store/${storeId}`, {});
  },
  leaveStore: async (): Promise<void> => {
    await api.delete('/api/chefs/leave-store');
  },
};

export default function ChefStorePage() {
  const router = useRouter();
  const { user, hasHydrated } = useAuthStore();
  const [myStore, setMyStore] = useState<Store | null>(null);
  const [availableStores, setAvailableStores] = useState<Store[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');

  useEffect(() => {
    if (hasHydrated && user?.role !== 'CHEF') {
      router.push('/mypage');
    }
  }, [hasHydrated, user, router]);

  useEffect(() => {
    if (hasHydrated && user?.role === 'CHEF') {
      loadMyStore();
      loadAvailableStores();
    }
  }, [hasHydrated, user]);

  const loadMyStore = async () => {
    try {
      setMyStore(await chefApi.getMyStore());
    } catch (error) {
      console.error('소속 가게 로드 실패:', error);
    }
  };

  const loadAvailableStores = async () => {
    try {
      setAvailableStores(await chefApi.getApprovedStores());
    } catch (error) {
      console.error('가게 목록 로드 실패:', error);
    }
  };

  const handleJoinStore = async (storeId: string) => {
    if (!confirm('이 가게에 소속되시겠습니까?')) return;

    setIsLoading(true);
    try {
      await chefApi.joinStore(storeId);
      alert('가게에 소속되었습니다.');
      loadMyStore();
      loadAvailableStores();
    } catch (error) {
      console.error('가게 소속 실패:', error);
      alert('가게 소속에 실패했습니다.');
    } finally {
      setIsLoading(false);
    }
  };

  const handleLeaveStore = async () => {
    if (!confirm('가게에서 나가시겠습니까?')) return;

    setIsLoading(true);
    try {
      await chefApi.leaveStore();
      alert('가게에서 나갔습니다.');
      setMyStore(null);
      loadAvailableStores();
    } catch (error) {
      console.error('가게 나가기 실패:', error);
      alert('가게 나가기에 실패했습니다.');
    } finally {
      setIsLoading(false);
    }
  };

  if (!hasHydrated || !user) {
    return null;
  }

  const filteredStores = availableStores.filter((store) =>
    store.name.toLowerCase().includes(searchQuery.toLowerCase())
  );

  return (
    <div className="max-w-4xl mx-auto px-4 py-8">
      <h1 className="text-2xl font-bold text-gray-900 mb-6">소속 가게 관리</h1>

      {/* 현재 소속 가게 */}
      {myStore ? (
        <div className="bg-white rounded-xl shadow-md p-6 mb-8">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-xl font-semibold text-gray-900">현재 소속 가게</h2>
            <span className="px-3 py-1 bg-green-100 text-green-800 rounded-full text-sm font-medium">
              소속됨
            </span>
          </div>

          <div className="space-y-3">
            <h3 className="text-2xl font-bold text-gray-900">{myStore.name}</h3>
            {myStore.description && <p className="text-gray-600">{myStore.description}</p>}

            <div className="space-y-2 text-sm text-gray-600 pt-3">
              <div className="flex items-center gap-2">
                <span>📞</span>
                <span>{myStore.phoneNumber}</span>
              </div>
              <div className="flex items-center gap-2">
                <span>📍</span>
                <span>
                  {myStore.roadAddress}
                  {myStore.addressDetail && `, ${myStore.addressDetail}`}
                </span>
              </div>
            </div>

            <div className="pt-4 border-t">
              <Button
                variant="outline"
                onClick={handleLeaveStore}
                isLoading={isLoading}
                className="text-red-600 border-red-600 hover:bg-red-50"
              >
                가게 나가기
              </Button>
            </div>
          </div>
        </div>
      ) : (
        <div className="bg-white rounded-xl shadow-md p-6 mb-8">
          <div className="text-center py-8">
            <p className="text-gray-500 text-lg mb-2">아직 소속된 가게가 없습니다.</p>
            <p className="text-sm text-gray-400">
              아래에서 원하는 가게를 찾아 소속되세요.
            </p>
          </div>
        </div>
      )}

      {/* 가게 검색 및 목록 */}
      {!myStore && (
        <div className="bg-white rounded-xl shadow-md p-6">
          <h2 className="text-xl font-semibold text-gray-900 mb-4">
            가게 찾기
          </h2>

          <Input
            placeholder="가게 이름으로 검색"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="mb-4"
          />

          <div className="space-y-4">
            {filteredStores.length === 0 ? (
              <div className="text-center py-8">
                <p className="text-gray-500">검색 결과가 없습니다.</p>
              </div>
            ) : (
              filteredStores.map((store) => (
                <div
                  key={store.id}
                  className="border border-gray-200 rounded-lg p-4 hover:border-orange-500 transition-colors"
                >
                  <div className="flex items-start justify-between">
                    <div className="flex-1">
                      <h3 className="text-lg font-semibold text-gray-900">
                        {store.name}
                      </h3>
                      {store.description && (
                        <p className="text-gray-600 text-sm mt-1">
                          {store.description}
                        </p>
                      )}
                      <div className="space-y-1 text-sm text-gray-600 mt-3">
                        <div className="flex items-center gap-2">
                          <span>📞</span>
                          <span>{store.phoneNumber}</span>
                        </div>
                        <div className="flex items-center gap-2">
                          <span>📍</span>
                          <span>
                            {store.roadAddress}
                            {store.addressDetail && `, ${store.addressDetail}`}
                          </span>
                        </div>
                      </div>
                    </div>
                    <Button
                      size="sm"
                      onClick={() => handleJoinStore(store.id)}
                      isLoading={isLoading}
                    >
                      소속하기
                    </Button>
                  </div>
                </div>
              ))
            )}
          </div>
        </div>
      )}
    </div>
  );
}
