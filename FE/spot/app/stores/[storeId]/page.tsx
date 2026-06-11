'use client';

import React, {useEffect, useState} from 'react';
import {useParams, useRouter} from 'next/navigation';
import {storeApi} from '@/lib/stores';
import {useCartStore} from '@/store/cartStore';
import {Button} from '@/components/ui/Button';
import {ReviewList} from '@/components/review/ReviewList';
import {ReviewWriteForm} from '@/components/review/ReviewWriteForm';
import type {Menu, MenuOption, Store} from '@/types';

export default function StoreDetailPage() {
  const params = useParams();
  const router = useRouter();
  const storeId = params.storeId as string;

  const [store, setStore] = useState<Store | null>(null);
  const [menus, setMenus] = useState<Menu[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [selectedMenu, setSelectedMenu] = useState<Menu | null>(null);
  const [quantity, setQuantity] = useState(1);
  const [selectedOptions, setSelectedOptions] = useState<MenuOption[]>([]);
  const [activeTab, setActiveTab] = useState<'menu' | 'review'>('menu');
  const [reviewKey, setReviewKey] = useState(0);

  const { addItem, cart, getTotal, getItemCount } = useCartStore();

  useEffect(() => {
    loadStoreData();
  }, [storeId]);

  const loadStoreData = async () => {
    try {
      const storeData = await storeApi.getStore(storeId);
      console.log('[StoreDetail] 매장 데이터 로드 완료:', storeData);
      console.log('[StoreDetail] 포함된 메뉴 개수:', storeData.menus?.length || 0);

      if (storeData.menus && storeData.menus.length > 0) {
        console.log('[StoreDetail] 첫 번째 메뉴 샘플:', {
          id: storeData.menus[0].id,
          name: storeData.menus[0].name,
          price: storeData.menus[0].price,
          options: storeData.menus[0].options
        });
      }

      setStore(storeData);
      // 매장 상세 조회 시 메뉴가 포함되어 있음
      setMenus(storeData.menus || []);
    } catch (error) {
      console.error('Failed to load store:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const handleMenuClick = (menu: Menu) => {
    setSelectedMenu(menu);
    setQuantity(1);
    setSelectedOptions([]);
  };

  const handleOptionToggle = (option: MenuOption) => {
    console.log('[StoreDetail] 옵션 토글:', option);
    setSelectedOptions((prev) => {
      const exists = prev.find((o) => o.id === option.id);
      if (exists) {
        const filtered = prev.filter((o) => o.id !== option.id);
        console.log('[StoreDetail] 옵션 제거됨, 현재 선택된 옵션:', filtered);
        return filtered;
      }
      const updated = [...prev, option];
      console.log('[StoreDetail] 옵션 추가됨, 현재 선택된 옵션:', updated);
      return updated;
    });
  };

  const handleAddToCart = () => {
    if (!selectedMenu || !store) return;

    console.log('[StoreDetail] 장바구니 담기:', {
      menu: selectedMenu,
      quantity,
      selectedOptions
    });

    addItem(storeId, store.name, selectedMenu, quantity, selectedOptions);
    setSelectedMenu(null);
    setQuantity(1);
    setSelectedOptions([]);
  };

  const calculateItemTotal = () => {
    if (!selectedMenu) return 0;
    const optionsTotal = selectedOptions.reduce((sum, opt) => sum + (opt.price || 0), 0);
    return (selectedMenu.price + optionsTotal) * quantity;
  };

  // 메뉴 카테고리별 그룹화
  const menusByCategory = menus.reduce(
    (acc, menu) => {
      const category = menu.category || '기타';
      if (!acc[category]) {
        acc[category] = [];
      }
      acc[category].push(menu);
      return acc;
    },
    {} as Record<string, Menu[]>
  );

  if (isLoading) {
    return (
      <div className="max-w-4xl mx-auto px-4 py-8">
        <div className="animate-pulse">
          <div className="bg-gray-200 h-48 rounded-xl mb-6" />
          <div className="bg-gray-200 h-8 w-1/3 rounded mb-4" />
          <div className="bg-gray-200 h-4 w-2/3 rounded" />
        </div>
      </div>
    );
  }

  if (!store) {
    return (
      <div className="max-w-4xl mx-auto px-4 py-8 text-center">
        <p className="text-gray-500">가게를 찾을 수 없습니다.</p>
      </div>
    );
  }

  return (
    <div className="max-w-4xl mx-auto px-4 py-8">
      {/* 가게 정보 */}
      <div className="bg-white rounded-xl shadow-md overflow-hidden mb-8">
        <div className="bg-gradient-to-br from-orange-100 to-orange-200 h-48 flex items-center justify-center">
          <span className="text-6xl">🏪</span>
        </div>
        <div className="p-6">
          <h1 className="text-2xl font-bold text-gray-900 mb-2">{store.name}</h1>
          <p className="text-gray-600 mb-4">
            {store.roadAddress} {store.addressDetail}
          </p>
          <div className="flex flex-wrap gap-4 text-sm text-gray-500">
            <span>영업시간: {store.openTime} - {store.closeTime}</span>
            {store.phoneNumber && <span>전화: {store.phoneNumber}</span>}
          </div>
        </div>
      </div>

      {/* 탭 네비게이션 */}
      <div className="mb-6 border-b border-gray-200">
        <nav className="-mb-px flex gap-8">
          <button
            onClick={() => setActiveTab('menu')}
            className={`py-4 px-1 border-b-2 font-medium text-sm transition-colors ${
              activeTab === 'menu'
                ? 'border-orange-500 text-orange-600'
                : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
            }`}
          >
            메뉴
          </button>
          <button
            onClick={() => setActiveTab('review')}
            className={`py-4 px-1 border-b-2 font-medium text-sm transition-colors ${
              activeTab === 'review'
                ? 'border-orange-500 text-orange-600'
                : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
            }`}
          >
            리뷰
          </button>
        </nav>
      </div>

      {/* 메뉴 탭 */}
      {activeTab === 'menu' && (
        <div className="bg-white rounded-xl shadow-md p-6">
          <h2 className="text-xl font-bold text-gray-900 mb-6">메뉴</h2>

        {Object.entries(menusByCategory).map(([category, categoryMenus]) => (
          <div key={category} className="mb-8 last:mb-0">
            <h3 className="text-lg font-semibold text-gray-800 mb-4 pb-2 border-b">
              {category}
            </h3>
            <div className="space-y-4">
              {categoryMenus.map((menu, index) => (
                <div
                  key={`${category}-${menu.id}-${index}`}
                  onClick={() => handleMenuClick(menu)}
                  className="flex items-center gap-4 p-4 rounded-lg hover:bg-gray-50 cursor-pointer transition-colors"
                >
                  {menu.imageUrl ? (
                    <img
                      src={menu.imageUrl}
                      alt={menu.name}
                      className="w-20 h-20 rounded-lg object-cover"
                    />
                  ) : (
                    <div className="w-20 h-20 bg-gray-100 rounded-lg flex items-center justify-center">
                      <span className="text-2xl">🍽️</span>
                    </div>
                  )}
                  <div className="flex-1">
                    <h4 className="font-medium text-gray-900">{menu.name}</h4>
                    {menu.description && (
                      <p className="text-sm text-gray-500 mt-1 line-clamp-2">
                        {menu.description}
                      </p>
                    )}
                    <p className="text-orange-500 font-semibold mt-2">
                      {menu.price.toLocaleString()}원
                    </p>
                  </div>
                </div>
              ))}
            </div>
          </div>
        ))}
        </div>
      )}

      {/* 리뷰 탭 */}
      {activeTab === 'review' && (
        <div className="space-y-6">
          <ReviewWriteForm
            storeId={storeId}
            onSuccess={() => setReviewKey((prev) => prev + 1)}
          />
          <ReviewList key={reviewKey} storeId={storeId} />
        </div>
      )}

      {/* 장바구니 플로팅 버튼 */}
      {cart && cart.storeId === storeId && getItemCount() > 0 && (
        <div className="fixed bottom-6 left-1/2 transform -translate-x-1/2 w-full max-w-md px-4">
          <Button
            onClick={() => router.push('/cart')}
            className="w-full shadow-lg"
            size="lg"
          >
            장바구니 보기 · {getItemCount()}개 · {getTotal().toLocaleString()}원
          </Button>
        </div>
      )}

      {/* 메뉴 선택 모달 */}
      {selectedMenu && (
        <div className="fixed inset-0 bg-black/50 flex items-end justify-center z-50">
          <div className="bg-white w-full max-w-lg rounded-t-2xl max-h-[80vh] overflow-y-auto">
            <div className="p-6">
              <div className="flex justify-between items-start mb-4">
                <h3 className="text-xl font-bold text-gray-900">{selectedMenu.name}</h3>
                <button
                  onClick={() => setSelectedMenu(null)}
                  className="text-gray-400 hover:text-gray-600"
                >
                  <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </button>
              </div>

              {selectedMenu.description && (
                <p className="text-gray-600 mb-4">{selectedMenu.description}</p>
              )}

              <p className="text-lg font-semibold text-orange-500 mb-6">
                {selectedMenu.price.toLocaleString()}원
              </p>

              {/* 옵션 선택 */}
              {selectedMenu.options && selectedMenu.options.length > 0 && (
                <div className="mb-6">
                  <h4 className="font-medium text-gray-900 mb-3">추가 옵션</h4>
                  <div className="space-y-2">
                    {selectedMenu.options.map((option) => (
                      <label
                        key={option.id}
                        className="flex items-center justify-between p-3 border rounded-lg cursor-pointer hover:bg-gray-50"
                      >
                        <div className="flex items-center">
                          <input
                            type="checkbox"
                            checked={selectedOptions.some((o) => o.id === option.id)}
                            onChange={() => handleOptionToggle(option)}
                            className="w-5 h-5 text-orange-500 rounded focus:ring-orange-500"
                          />
                          <span className="ml-3 text-gray-700">{option.name}</span>
                        </div>
                        <span className="text-gray-500">
                          +{(option.price || 0).toLocaleString()}원
                        </span>
                      </label>
                    ))}
                  </div>
                </div>
              )}

              {/* 수량 선택 */}
              <div className="flex items-center justify-between mb-6">
                <span className="font-medium text-gray-900">수량</span>
                <div className="flex items-center gap-4">
                  <button
                    onClick={() => setQuantity(Math.max(1, quantity - 1))}
                    className="w-10 h-10 rounded-full border border-gray-300 flex items-center justify-center hover:bg-gray-50"
                  >
                    -
                  </button>
                  <span className="text-lg font-medium w-8 text-center">{quantity}</span>
                  <button
                    onClick={() => setQuantity(quantity + 1)}
                    className="w-10 h-10 rounded-full border border-gray-300 flex items-center justify-center hover:bg-gray-50"
                  >
                    +
                  </button>
                </div>
              </div>

              {/* 담기 버튼 */}
              <Button onClick={handleAddToCart} className="w-full" size="lg">
                {calculateItemTotal().toLocaleString()}원 담기
              </Button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
