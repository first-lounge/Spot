'use client';

import React, {useEffect, useState} from 'react';
import {useParams, useRouter} from 'next/navigation';
import {useAuthStore} from '@/store/authStore';
import {Button} from '@/components/ui/Button';
import {Input} from '@/components/ui/Input';
import {storeApi} from '@/lib/stores';
import {CreateMenuOptionRequest, CreateMenuRequest, menuApi} from '@/lib/menus';
import {SalesDashboard} from '@/components/sales/SalesDashboard';
import {OrderManagement} from '@/components/order/OrderManagement';
import type {Menu, Store} from '@/types';

export default function StoreManagementPage() {
  const params = useParams();
  const router = useRouter();
  const storeId = params.storeId as string;
  const { user, hasHydrated } = useAuthStore();

  const [store, setStore] = useState<Store | null>(null);
  const [menus, setMenus] = useState<Menu[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [activeTab, setActiveTab] = useState<'info' | 'menus' | 'sales' | 'orders'>('menus');

  // 메뉴 추가 모달
  const [showMenuForm, setShowMenuForm] = useState(false);
  const [editingMenu, setEditingMenu] = useState<Menu | null>(null);
  const [menuFormData, setMenuFormData] = useState<CreateMenuRequest>({
    name: '',
    category: '',
    price: 0,
    description: '',
    imageUrl: 'https://via.placeholder.com/300x200?text=Menu+Image', // 기본값 설정
    isAvailable: true,
    isHidden: false,
  });

  // 메뉴 옵션 모달
  const [showOptionForm, setShowOptionForm] = useState(false);
  const [selectedMenuForOption, setSelectedMenuForOption] = useState<Menu | null>(null);
  const [optionFormData, setOptionFormData] = useState<CreateMenuOptionRequest>({
    name: '',
    detail: '',
    price: 0,
  });

  // 가게 정보 수정
  const [isEditingStore, setIsEditingStore] = useState(false);
  const [storeFormData, setStoreFormData] = useState({
    name: '',
    phoneNumber: '',
    roadAddress: '',
    addressDetail: '',
    openTime: '',
    closeTime: '',
  });

  useEffect(() => {
    if (hasHydrated && user?.role !== 'OWNER') {
      router.push('/mypage');
    }
  }, [hasHydrated, user, router]);

  useEffect(() => {
    if (hasHydrated && storeId) {
      loadStoreData();
    }
  }, [hasHydrated, storeId]);

  const loadStoreData = async () => {
    try {
      setIsLoading(true);
      const [storeData, menusData] = await Promise.all([
        storeApi.getStore(storeId),
        menuApi.getMenus(storeId),
      ]);

      console.log('가게 데이터:', storeData);
      console.log('메뉴 데이터:', menusData);

      setStore(storeData);
      setMenus(menusData);

      // 가게 정보 폼 데이터 초기화
      setStoreFormData({
        name: storeData.name || '',
        phoneNumber: storeData.phoneNumber || '',
        roadAddress: storeData.roadAddress || '',
        addressDetail: storeData.addressDetail || '',
        openTime: storeData.openTime || '',
        closeTime: storeData.closeTime || '',
      });
    } catch (error) {
      console.error('가게 데이터 로드 실패:', error);
      alert('가게 정보를 불러오는데 실패했습니다.');
    } finally {
      setIsLoading(false);
    }
  };

  // 메뉴 관리 함수들
  const handleMenuFormChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
    const { name, value, type } = e.target;
    let processedValue: string | number = type === 'number' ? Number(value) : value;

    // imageUrl이 빈 문자열이면 기본값 유지
    if (name === 'imageUrl' && !value.trim()) {
      processedValue = 'https://via.placeholder.com/300x200?text=Menu+Image';
    }

    setMenuFormData((prev) => ({
      ...prev,
      [name]: processedValue,
    }));
  };

  const handleCreateMenu = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      if (editingMenu) {
        await menuApi.updateMenu(storeId, editingMenu.id, menuFormData);
        alert('메뉴가 수정되었습니다.');
      } else {
        await menuApi.createMenu(storeId, menuFormData);
        alert('메뉴가 추가되었습니다.');
      }
      setShowMenuForm(false);
      setEditingMenu(null);
      setMenuFormData({
        name: '',
        category: '',
        price: 0,
        description: '',
        imageUrl: 'https://via.placeholder.com/300x200?text=Menu+Image', // 기본값으로 리셋
        isAvailable: true,
        isHidden: false,
      });
      loadStoreData();
    } catch (error) {
      console.error('메뉴 저장 실패:', error);
      alert('메뉴 저장에 실패했습니다.');
    }
  };

  const handleEditMenu = (menu: Menu) => {
    setEditingMenu(menu);
    setMenuFormData({
      name: menu.name,
      category: menu.category,
      price: menu.price,
      description: menu.description,
      imageUrl: menu.imageUrl || '',
      isAvailable: menu.isAvailable ?? true,
      isHidden: menu.isHidden ?? false,
    });
    setShowMenuForm(true);
  };

  const handleDeleteMenu = async (menuId: string) => {
    if (!confirm('정말 이 메뉴를 삭제하시겠습니까?')) return;

    try {
      await menuApi.deleteMenu(storeId, menuId);
      alert('메뉴가 삭제되었습니다.');
      loadStoreData();
    } catch (error) {
      console.error('메뉴 삭제 실패:', error);
      alert('메뉴 삭제에 실패했습니다.');
    }
  };

  // 옵션 관리 함수들
  const handleOptionFormChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, value, type } = e.target;
    setOptionFormData((prev) => ({
      ...prev,
      [name]: type === 'number' ? Number(value) : value,
    }));
  };

  const handleAddOption = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedMenuForOption) return;

    console.log('옵션 추가 - 선택된 메뉴:', selectedMenuForOption);
    console.log('옵션 추가 - menuId:', selectedMenuForOption.id);
    console.log('옵션 추가 - storeId:', storeId);
    console.log('옵션 데이터:', optionFormData);

    try {
      await menuApi.addMenuOption(storeId, selectedMenuForOption.id, optionFormData);
      alert('옵션이 추가되었습니다.');
      setShowOptionForm(false);
      setSelectedMenuForOption(null);
      setOptionFormData({ name: '', detail: '', price: 0 });
      loadStoreData();
    } catch (error) {
      console.error('옵션 추가 실패:', error);
      alert('옵션 추가에 실패했습니다.');
    }
  };

  const handleDeleteOption = async (menuId: string, optionId: string) => {
    if (!confirm('정말 이 옵션을 삭제하시겠습니까?')) return;

    try {
      await menuApi.deleteMenuOption(storeId, menuId, optionId);
      alert('옵션이 삭제되었습니다.');
      loadStoreData();
    } catch (error) {
      console.error('옵션 삭제 실패:', error);
      alert('옵션 삭제에 실패했습니다.');
    }
  };

  // 가게 정보 수정
  const handleStoreFormChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, value } = e.target;
    setStoreFormData((prev) => ({ ...prev, [name]: value }));
  };

  const handleUpdateStore = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      // TODO: 가게 정보 수정 API 호출
      // await storeApi.updateStore(storeId, storeFormData);
      alert('가게 정보가 수정되었습니다.');
      setIsEditingStore(false);
      loadStoreData();
    } catch (error) {
      console.error('가게 정보 수정 실패:', error);
      alert('가게 정보 수정에 실패했습니다.');
    }
  };

  if (!hasHydrated || isLoading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="text-gray-500">로딩 중...</div>
      </div>
    );
  }

  if (!store) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="text-gray-500">가게를 찾을 수 없습니다.</div>
      </div>
    );
  }

  return (
    <div className="max-w-6xl mx-auto px-4 py-8">
      {/* 헤더 */}
      <div className="mb-6">
        <button
          onClick={() => router.back()}
          className="text-gray-600 hover:text-gray-900 mb-4"
        >
          ← 뒤로 가기
        </button>
        <h1 className="text-2xl font-bold text-gray-900">{store.name} 관리</h1>
      </div>

      {/* 탭 */}
      <div className="border-b border-gray-200 mb-6">
        <div className="flex gap-4">
          <button
            onClick={() => setActiveTab('menus')}
            className={`pb-3 px-2 font-medium ${
              activeTab === 'menus'
                ? 'text-orange-500 border-b-2 border-orange-500'
                : 'text-gray-500 hover:text-gray-700'
            }`}
          >
            메뉴 관리
          </button>
          <button
            onClick={() => setActiveTab('orders')}
            className={`pb-3 px-2 font-medium ${
              activeTab === 'orders'
                ? 'text-orange-500 border-b-2 border-orange-500'
                : 'text-gray-500 hover:text-gray-700'
            }`}
          >
            주문 관리
          </button>
          <button
            onClick={() => setActiveTab('sales')}
            className={`pb-3 px-2 font-medium ${
              activeTab === 'sales'
                ? 'text-orange-500 border-b-2 border-orange-500'
                : 'text-gray-500 hover:text-gray-700'
            }`}
          >
            매출 현황
          </button>
          <button
            onClick={() => setActiveTab('info')}
            className={`pb-3 px-2 font-medium ${
              activeTab === 'info'
                ? 'text-orange-500 border-b-2 border-orange-500'
                : 'text-gray-500 hover:text-gray-700'
            }`}
          >
            가게 정보
          </button>
        </div>
      </div>

      {/* 메뉴 관리 탭 */}
      {activeTab === 'menus' && (
        <div>
          <div className="flex items-center justify-between mb-6">
            <h2 className="text-xl font-semibold">메뉴 목록 ({menus.length}개)</h2>
            <Button onClick={() => setShowMenuForm(true)}>메뉴 추가</Button>
          </div>

          {menus.length === 0 ? (
            <div className="bg-white rounded-xl shadow-md p-8 text-center">
              <p className="text-gray-500">등록된 메뉴가 없습니다.</p>
              <p className="text-sm text-gray-400 mt-2">메뉴를 추가해보세요.</p>
            </div>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {menus.map((menu) => (
                <div key={menu.id} className="bg-white rounded-xl shadow-md p-6">
                  <div className="flex items-start justify-between mb-4">
                    <div className="flex-1">
                      <h3 className="text-lg font-semibold text-gray-900">{menu.name}</h3>
                      <p className="text-sm text-gray-500">{menu.category}</p>
                      <p className="text-lg font-bold text-orange-500 mt-2">
                        {menu.price.toLocaleString()}원
                      </p>
                    </div>
                    <div className="flex gap-2">
                      <button
                        onClick={() => handleEditMenu(menu)}
                        className="text-sm text-blue-500 hover:text-blue-700"
                      >
                        수정
                      </button>
                      <button
                        onClick={() => handleDeleteMenu(menu.id)}
                        className="text-sm text-red-500 hover:text-red-700"
                      >
                        삭제
                      </button>
                    </div>
                  </div>

                  {menu.description && (
                    <p className="text-sm text-gray-600 mb-4">{menu.description}</p>
                  )}

                  {/* 옵션 */}
                  <div className="border-t pt-4">
                    <div className="flex items-center justify-between mb-2">
                      <h4 className="text-sm font-medium text-gray-700">옵션</h4>
                      <button
                        onClick={() => {
                          setSelectedMenuForOption(menu);
                          setShowOptionForm(true);
                        }}
                        className="text-xs text-orange-500 hover:text-orange-700"
                      >
                        + 옵션 추가
                      </button>
                    </div>

                    {menu.options && menu.options.length > 0 ? (
                      <div className="space-y-1">
                        {menu.options.map((option) => (
                          <div
                            key={option.id}
                            className="flex items-center justify-between text-sm"
                          >
                            <span className="text-gray-600">
                              {option.name} (+{option.price.toLocaleString()}원)
                            </span>
                            <button
                              onClick={() => handleDeleteOption(menu.id, option.id)}
                              className="text-xs text-red-500 hover:text-red-700"
                            >
                              삭제
                            </button>
                          </div>
                        ))}
                      </div>
                    ) : (
                      <p className="text-xs text-gray-400">옵션 없음</p>
                    )}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* 가게 정보 탭 */}
      {activeTab === 'info' && (
        <div className="bg-white rounded-xl shadow-md p-6">
          {!isEditingStore ? (
            <div>
              <div className="flex items-center justify-between mb-6">
                <h2 className="text-xl font-semibold">가게 정보</h2>
                <Button onClick={() => setIsEditingStore(true)}>수정하기</Button>
              </div>

              <div className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">가게 이름</label>
                  <p className="text-gray-900">{store.name}</p>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">전화번호</label>
                  <p className="text-gray-900">{store.phoneNumber}</p>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">주소</label>
                  <p className="text-gray-900">
                    {store.roadAddress} {store.addressDetail}
                  </p>
                </div>
                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      오픈 시간
                    </label>
                    <p className="text-gray-900">{store.openTime}</p>
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      마감 시간
                    </label>
                    <p className="text-gray-900">{store.closeTime}</p>
                  </div>
                </div>
              </div>
            </div>
          ) : (
            <form onSubmit={handleUpdateStore}>
              <h2 className="text-xl font-semibold mb-6">가게 정보 수정</h2>

              <div className="space-y-4">
                <Input
                  label="가게 이름"
                  name="name"
                  value={storeFormData.name}
                  onChange={handleStoreFormChange}
                  required
                />
                <Input
                  label="전화번호"
                  name="phoneNumber"
                  value={storeFormData.phoneNumber}
                  onChange={handleStoreFormChange}
                  required
                />
                <Input
                  label="도로명 주소"
                  name="roadAddress"
                  value={storeFormData.roadAddress}
                  onChange={handleStoreFormChange}
                  required
                />
                <Input
                  label="상세 주소"
                  name="addressDetail"
                  value={storeFormData.addressDetail}
                  onChange={handleStoreFormChange}
                />
                <div className="grid grid-cols-2 gap-4">
                  <Input
                    label="오픈 시간"
                    name="openTime"
                    type="time"
                    value={storeFormData.openTime}
                    onChange={handleStoreFormChange}
                    required
                  />
                  <Input
                    label="마감 시간"
                    name="closeTime"
                    type="time"
                    value={storeFormData.closeTime}
                    onChange={handleStoreFormChange}
                    required
                  />
                </div>
              </div>

              <div className="flex gap-2 mt-6">
                <Button type="submit" className="flex-1">
                  저장하기
                </Button>
                <Button
                  type="button"
                  variant="outline"
                  onClick={() => setIsEditingStore(false)}
                >
                  취소
                </Button>
              </div>
            </form>
          )}
        </div>
      )}

      {/* 메뉴 추가/수정 모달 */}
      {showMenuForm && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-xl shadow-xl max-w-lg w-full p-6 max-h-[90vh] overflow-y-auto">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-xl font-semibold">
                {editingMenu ? '메뉴 수정' : '메뉴 추가'}
              </h2>
              <button
                onClick={() => {
                  setShowMenuForm(false);
                  setEditingMenu(null);
                }}
                className="text-gray-500 hover:text-gray-700"
              >
                ✕
              </button>
            </div>

            <form onSubmit={handleCreateMenu} className="space-y-4">
              <Input
                label="메뉴 이름"
                name="name"
                value={menuFormData.name}
                onChange={handleMenuFormChange}
                required
              />
              <Input
                label="카테고리"
                name="category"
                value={menuFormData.category}
                onChange={handleMenuFormChange}
                placeholder="예: 메인, 사이드, 음료"
                required
              />
              <Input
                label="가격"
                name="price"
                type="number"
                value={menuFormData.price}
                onChange={handleMenuFormChange}
                required
              />
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">설명</label>
                <textarea
                  name="description"
                  value={menuFormData.description}
                  onChange={handleMenuFormChange}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-orange-500"
                  rows={3}
                />
              </div>
              <div>
                <Input
                  label="이미지 URL (선택)"
                  name="imageUrl"
                  value={menuFormData.imageUrl}
                  onChange={handleMenuFormChange}
                  placeholder="https://example.com/image.jpg"
                />
                <p className="mt-1 text-xs text-gray-500">
                  입력하지 않으면 기본 이미지가 사용됩니다.
                </p>
              </div>

              <div className="flex gap-2">
                <Button type="submit" className="flex-1">
                  {editingMenu ? '수정하기' : '추가하기'}
                </Button>
                <Button
                  type="button"
                  variant="outline"
                  onClick={() => {
                    setShowMenuForm(false);
                    setEditingMenu(null);
                  }}
                >
                  취소
                </Button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* 옵션 추가 모달 */}
      {showOptionForm && selectedMenuForOption && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-xl shadow-xl max-w-lg w-full p-6">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-xl font-semibold">
                옵션 추가 - {selectedMenuForOption.name}
              </h2>
              <button
                onClick={() => {
                  setShowOptionForm(false);
                  setSelectedMenuForOption(null);
                }}
                className="text-gray-500 hover:text-gray-700"
              >
                ✕
              </button>
            </div>

            <form onSubmit={handleAddOption} className="space-y-4">
              <Input
                label="옵션 이름"
                name="name"
                value={optionFormData.name}
                onChange={handleOptionFormChange}
                placeholder="예: 곱빼기, 치즈 추가"
                required
              />
              <Input
                label="옵션 설명"
                name="detail"
                type="text"
                value={optionFormData.detail}
                onChange={handleOptionFormChange}
                required
              />
              <Input
                label="추가 가격"
                name="price"
                type="number"
                value={optionFormData.price}
                onChange={handleOptionFormChange}
                required
              />

              <div className="flex gap-2">
                <Button type="submit" className="flex-1">
                  추가하기
                </Button>
                <Button
                  type="button"
                  variant="outline"
                  onClick={() => {
                    setShowOptionForm(false);
                    setSelectedMenuForOption(null);
                  }}
                >
                  취소
                </Button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* 주문 관리 탭 */}
      {activeTab === 'orders' && (
        <OrderManagement storeId={storeId} />
      )}

      {/* 매출 현황 탭 */}
      {activeTab === 'sales' && (
        <SalesDashboard storeId={storeId} />
      )}
    </div>
  );
}
