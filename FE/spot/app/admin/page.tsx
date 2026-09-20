'use client';

import {useEffect, useState} from 'react';
import {useAuth} from '@/store/authStore';
import {adminOrderApi, type AdminStats, adminStatsApi, adminStoreApi, adminUserApi,} from '@/lib/admin';
import type {OrderResponse, OrderStatus, PageResponse, Store, User} from '@/types';
import Button from '@/components/ui/Button';

type TabType = 'dashboard' | 'users' | 'orders' | 'stores';

const ORDER_STATUS_LABELS: Record<OrderStatus, string> = {
  PAYMENT_PENDING: '결제 대기',
  PAYMENT_FAILED: '결제 실패',
  PENDING: '승인 대기',
  ACCEPTED: '승인됨',
  REJECT_PENDING: '거절 처리 중',
  REJECTED: '거절됨',
  COOKING: '조리 중',
  READY: '픽업 준비',
  COMPLETED: '완료',
  CANCEL_PENDING: '취소 처리 중',
  CANCELLED: '취소',
  REFUND_ERROR: '환불 확인 필요',
};

const formatDateTime = (value?: string): string => {
  if (!value) return '-';
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? value : date.toLocaleString('ko-KR');
};

export default function AdminPage() {
  const { user } = useAuth();
  const [activeTab, setActiveTab] = useState<TabType>('dashboard');
  const [isLoading, setIsLoading] = useState(false);

  // 주문 상세 모달 — 목록 응답에 orderItems 가 이미 포함돼 있어 추가 API 호출 없이 표시한다
  const [selectedOrder, setSelectedOrder] = useState<OrderResponse | null>(null);

  // 대시보드 데이터
  const [stats, setStats] = useState<AdminStats | null>(null);

  // 사용자 데이터
  const [users, setUsers] = useState<PageResponse<User> | null>(null);
  const [userPage, setUserPage] = useState(0);

  // 주문 데이터
  const [orders, setOrders] = useState<PageResponse<OrderResponse> | null>(null);
  const [orderPage, setOrderPage] = useState(0);

  // 가게 데이터
  const [stores, setStores] = useState<PageResponse<Store> | null>(null);
  const [storePage, setStorePage] = useState(0);

  // 대시보드 데이터 로드
  const loadDashboard = async () => {
    try {
      setIsLoading(true);
      const data = await adminStatsApi.getStats();
      setStats(data);
    } catch (error) {
      console.error('대시보드 로드 실패:', error);
      alert('대시보드 데이터를 불러오는데 실패했습니다.');
    } finally {
      setIsLoading(false);
    }
  };

  // 사용자 목록 로드
  const loadUsers = async (page = 0) => {
    try {
      setIsLoading(true);
      const data = await adminUserApi.getAllUsers(page, 20);
      setUsers(data);
      setUserPage(page);
    } catch (error) {
      console.error('사용자 목록 로드 실패:', error);
      alert('사용자 목록을 불러오는데 실패했습니다.');
    } finally {
      setIsLoading(false);
    }
  };

  // 주문 목록 로드
  const loadOrders = async (page = 0) => {
    try {
      setIsLoading(true);
      const data = await adminOrderApi.getAllOrders(page, 20);
      setOrders(data);
      setOrderPage(page);
    } catch (error) {
      console.error('주문 목록 로드 실패:', error);
      alert('주문 목록을 불러오는데 실패했습니다.');
    } finally {
      setIsLoading(false);
    }
  };

  // 가게 목록 로드
  const loadStores = async (page = 0) => {
    try {
      setIsLoading(true);
      const data = await adminStoreApi.getAllStores(page, 20);
      setStores(data);
      setStorePage(page);
    } catch (error) {
      console.error('가게 목록 로드 실패:', error);
      alert('가게 목록을 불러오는데 실패했습니다.');
    } finally {
      setIsLoading(false);
    }
  };

  // 탭 변경 시 데이터 로드
  useEffect(() => {
    switch (activeTab) {
      case 'dashboard':
        loadDashboard();
        break;
      case 'users':
        loadUsers();
        break;
      case 'orders':
        loadOrders();
        break;
      case 'stores':
        loadStores();
        break;
    }
  }, [activeTab]);

  // 사용자 역할 변경
  const handleUpdateUserRole = async (userId: number, newRole: string) => {
    if (!confirm('사용자의 역할을 변경하시겠습니까?')) return;

    try {
      await adminUserApi.updateUserRole(userId, newRole);
      alert('역할이 변경되었습니다.');
      loadUsers(userPage);
    } catch (error) {
      console.error('역할 변경 실패:', error);
      alert('역할 변경에 실패했습니다.');
    }
  };

  // 사용자 삭제
  const handleDeleteUser = async (userId: number) => {
    if (!confirm('정말 이 사용자를 삭제하시겠습니까?')) return;

    try {
      await adminUserApi.deleteUser(userId);
      alert('사용자가 삭제되었습니다.');
      loadUsers(userPage);
    } catch (error) {
      console.error('사용자 삭제 실패:', error);
      alert('사용자 삭제에 실패했습니다.');
    }
  };

  // 주문 상태 변경
  const handleUpdateOrderStatus = async (orderId: string, newStatus: string) => {
    if (!confirm('주문 상태를 변경하시겠습니까?')) return;

    try {
      await adminOrderApi.updateOrderStatus(orderId, newStatus);
      alert('주문 상태가 변경되었습니다.');
      loadOrders(orderPage);
    } catch (error) {
      console.error('주문 상태 변경 실패:', error);
      alert('주문 상태 변경에 실패했습니다.');
    }
  };

  // 가게 승인
  const handleApproveStore = async (storeId: string) => {
    if (!confirm('이 가게를 승인하시겠습니까?')) return;

    try {
      await adminStoreApi.approveStore(storeId);
      alert('가게가 승인되었습니다.');
      loadStores(storePage);
    } catch (error) {
      console.error('가게 승인 실패:', error);
      alert('가게 승인에 실패했습니다.');
    }
  };

  // 가게 거절
  const handleRejectStore = async (storeId: string) => {
    if (!confirm('이 가게를 거절하시겠습니까?')) return;

    try {
      await adminStoreApi.rejectStore(storeId);
      alert('가게가 거절되었습니다.');
      loadStores(storePage);
    } catch (error) {
      console.error('가게 거절 실패:', error);
      alert('가게 거절에 실패했습니다.');
    }
  };

  // 가게 삭제
  const handleDeleteStore = async (storeId: string) => {
    if (!confirm('정말 이 가게를 삭제하시겠습니까?')) return;

    try {
      await adminStoreApi.deleteStore(storeId);
      alert('가게가 삭제되었습니다.');
      loadStores(storePage);
    } catch (error) {
      console.error('가게 삭제 실패:', error);
      alert('가게 삭제에 실패했습니다.');
    }
  };

  return (
    <div>
      {/* 헤더 */}
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900">관리자 대시보드</h1>
        <p className="mt-2 text-gray-600">
          안녕하세요, {user?.nickname || user?.username}님 ({user?.role})
        </p>
      </div>

      {/* 탭 네비게이션 */}
      <div className="border-b border-gray-200 mb-6">
        <nav className="-mb-px flex space-x-8">
          <button
            onClick={() => setActiveTab('dashboard')}
            className={`py-4 px-1 border-b-2 font-medium text-sm ${
              activeTab === 'dashboard'
                ? 'border-blue-500 text-blue-600'
                : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
            }`}
          >
            대시보드
          </button>
          <button
            onClick={() => setActiveTab('users')}
            className={`py-4 px-1 border-b-2 font-medium text-sm ${
              activeTab === 'users'
                ? 'border-blue-500 text-blue-600'
                : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
            }`}
          >
            사용자 관리
          </button>
          <button
            onClick={() => setActiveTab('orders')}
            className={`py-4 px-1 border-b-2 font-medium text-sm ${
              activeTab === 'orders'
                ? 'border-blue-500 text-blue-600'
                : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
            }`}
          >
            주문 관리
          </button>
          <button
            onClick={() => setActiveTab('stores')}
            className={`py-4 px-1 border-b-2 font-medium text-sm ${
              activeTab === 'stores'
                ? 'border-blue-500 text-blue-600'
                : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
            }`}
          >
            가게 관리
          </button>
        </nav>
      </div>

      {/* 탭 콘텐츠 */}
      {isLoading ? (
        <div className="flex justify-center py-12">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
        </div>
      ) : (
        <>
          {/* 대시보드 탭 */}
          {activeTab === 'dashboard' && stats && (
            <div>
              {/* 통계 카드 */}
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
                <div className="bg-white rounded-lg shadow p-6">
                  <h3 className="text-sm font-medium text-gray-500">전체 사용자</h3>
                  <p className="mt-2 text-3xl font-bold text-gray-900">
                    {stats.totalUsers.toLocaleString()}
                  </p>
                </div>
                <div className="bg-white rounded-lg shadow p-6">
                  <h3 className="text-sm font-medium text-gray-500">전체 주문</h3>
                  <p className="mt-2 text-3xl font-bold text-gray-900">
                    {stats.totalOrders.toLocaleString()}
                  </p>
                </div>
                <div className="bg-white rounded-lg shadow p-6">
                  <h3 className="text-sm font-medium text-gray-500">전체 가게</h3>
                  <p className="mt-2 text-3xl font-bold text-gray-900">
                    {stats.totalStores.toLocaleString()}
                  </p>
                </div>
                <div className="bg-white rounded-lg shadow p-6">
                  <h3 className="text-sm font-medium text-gray-500">총 매출</h3>
                  <p className="mt-2 text-3xl font-bold text-gray-900">
                    {stats.totalRevenue.toLocaleString()}원
                  </p>
                </div>
              </div>

              {/* 최근 주문 */}
              <div className="bg-white rounded-lg shadow">
                <div className="px-6 py-4 border-b border-gray-200">
                  <h3 className="text-lg font-medium text-gray-900">최근 주문</h3>
                </div>
                <div className="overflow-x-auto">
                  <table className="min-w-full divide-y divide-gray-200">
                    <thead className="bg-gray-50">
                      <tr>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                          주문 ID
                        </th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                          가게명
                        </th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                          상태
                        </th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                          금액
                        </th>
                      </tr>
                    </thead>
                    <tbody className="bg-white divide-y divide-gray-200">
                      {stats.recentOrders.map((order) => (
                        <tr key={order.orderId}>
                          <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                            #{order.orderId}
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                            {order.storeName}
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap">
                            <span className="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-green-100 text-green-800">
                              {order.status}
                            </span>
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                            {Number(order.totalAmount ?? 0).toLocaleString()}원
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>
            </div>
          )}

          {/* 사용자 관리 탭 */}
          {activeTab === 'users' && users && (
            <div className="bg-white rounded-lg shadow">
              <div className="px-6 py-4 border-b border-gray-200">
                <h3 className="text-lg font-medium text-gray-900">
                  사용자 목록 (총 {users.totalElements}명)
                </h3>
              </div>
              <div className="overflow-x-auto">
                <table className="min-w-full divide-y divide-gray-200">
                  <thead className="bg-gray-50">
                    <tr>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                        ID
                      </th>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                        사용자명
                      </th>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                        닉네임
                      </th>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                        이메일
                      </th>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                        역할
                      </th>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                        작업
                      </th>
                    </tr>
                  </thead>
                  <tbody className="bg-white divide-y divide-gray-200">
                    {users.content.map((user) => (
                      <tr key={user.id}>
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                          {user.id}
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                          {user.username}
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                          {user.nickname || '-'}
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                          {user.email || '-'}
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap">
                          <select
                            value={user.role}
                            onChange={(e) => handleUpdateUserRole(user.id, e.target.value)}
                            className="text-sm border-gray-300 rounded-md"
                          >
                            <option value="CUSTOMER">CUSTOMER</option>
                            <option value="OWNER">OWNER</option>
                            <option value="CHEF">CHEF</option>
                            <option value="MANAGER">MANAGER</option>
                            <option value="MASTER">MASTER</option>
                          </select>
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm font-medium">
                          <Button
                            variant="danger"
                            size="sm"
                            onClick={() => handleDeleteUser(user.id)}
                          >
                            삭제
                          </Button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
              {/* 페이지네이션 */}
              <div className="px-6 py-4 border-t border-gray-200 flex justify-between items-center">
                <Button
                  variant="outline"
                  disabled={userPage === 0}
                  onClick={() => loadUsers(userPage - 1)}
                >
                  이전
                </Button>
                <span className="text-sm text-gray-700">
                  {userPage + 1} / {users.totalPages} 페이지
                </span>
                <Button
                  variant="outline"
                  disabled={userPage >= users.totalPages - 1}
                  onClick={() => loadUsers(userPage + 1)}
                >
                  다음
                </Button>
              </div>
            </div>
          )}

          {/* 주문 관리 탭 */}
          {activeTab === 'orders' && orders && (
            <div className="bg-white rounded-lg shadow">
              <div className="px-6 py-4 border-b border-gray-200">
                <h3 className="text-lg font-medium text-gray-900">
                  주문 목록 (총 {orders.totalElements}건)
                </h3>
              </div>
              <div className="overflow-x-auto">
                <table className="min-w-full divide-y divide-gray-200">
                  <thead className="bg-gray-50">
                    <tr>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                        주문 ID
                      </th>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                        가게명
                      </th>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                        금액
                      </th>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                        상태
                      </th>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                        작업
                      </th>
                    </tr>
                  </thead>
                  <tbody className="bg-white divide-y divide-gray-200">
                    {orders.content.map((order) => (
                      <tr key={order.orderId}>
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                          #{order.orderId}
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                          {order.storeName}
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                          {Number(order.totalAmount ?? 0).toLocaleString()}원
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap">
                          <select
                            value={order.status}
                            onChange={(e) =>
                              handleUpdateOrderStatus(order.orderId, e.target.value)
                            }
                            className="text-sm border-gray-300 rounded-md"
                          >
                            <option value="PAYMENT_PENDING">결제 대기</option>
                            <option value="PENDING">승인 대기</option>
                            <option value="ACCEPTED">승인됨</option>
                            <option value="REJECTED">거절됨</option>
                            <option value="COOKING">조리 중</option>
                            <option value="READY">픽업 준비</option>
                            <option value="COMPLETED">완료</option>
                            <option value="CANCELLED">취소</option>
                            <option value="PAYMENT_FAILED">결제 실패</option>
                          </select>
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm font-medium">
                          <Button
                            variant="outline"
                            size="sm"
                            onClick={() => setSelectedOrder(order)}
                          >
                            상세
                          </Button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
              {/* 페이지네이션 */}
              <div className="px-6 py-4 border-t border-gray-200 flex justify-between items-center">
                <Button
                  variant="outline"
                  disabled={orderPage === 0}
                  onClick={() => loadOrders(orderPage - 1)}
                >
                  이전
                </Button>
                <span className="text-sm text-gray-700">
                  {orderPage + 1} / {orders.totalPages} 페이지
                </span>
                <Button
                  variant="outline"
                  disabled={orderPage >= orders.totalPages - 1}
                  onClick={() => loadOrders(orderPage + 1)}
                >
                  다음
                </Button>
              </div>
            </div>
          )}

          {/* 가게 관리 탭 */}
          {activeTab === 'stores' && stores && (
            <div className="bg-white rounded-lg shadow">
              <div className="px-6 py-4 border-b border-gray-200">
                <h3 className="text-lg font-medium text-gray-900">
                  가게 목록 (총 {stores.totalElements}개)
                </h3>
              </div>
              <div className="overflow-x-auto">
                <table className="min-w-full divide-y divide-gray-200">
                  <thead className="bg-gray-50">
                    <tr>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                        ID
                      </th>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                        가게명
                      </th>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                        주소
                      </th>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                        전화번호
                      </th>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                        상태
                      </th>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                        삭제 여부
                      </th>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                        작업
                      </th>
                    </tr>
                  </thead>
                  <tbody className="bg-white divide-y divide-gray-200">
                    {stores.content.map((store) => (
                      <tr key={store.id} className={store.isDeleted ? 'bg-gray-100 opacity-60' : ''}>
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                          {store.id}
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                          {store.name}
                          {store.isDeleted && <span className="ml-2 text-red-600">(삭제됨)</span>}
                        </td>
                        <td className="px-6 py-4 text-sm text-gray-500">
                          {store.roadAddress}
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                          {store.phoneNumber}
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap">
                          <span
                            className={`px-2 inline-flex text-xs leading-5 font-semibold rounded-full ${
                              store.status === 'APPROVED'
                                ? 'bg-green-100 text-green-800'
                                : store.status === 'REJECTED'
                                ? 'bg-red-100 text-red-800'
                                : 'bg-yellow-100 text-yellow-800'
                            }`}
                          >
                            {store.status === 'APPROVED'
                              ? '승인됨'
                              : store.status === 'REJECTED'
                              ? '거부됨'
                              : '승인 대기'}
                          </span>
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap">
                          <span
                            className={`px-2 inline-flex text-xs leading-5 font-semibold rounded-full ${
                              store.isDeleted
                                ? 'bg-gray-100 text-gray-800'
                                : 'bg-blue-100 text-blue-800'
                            }`}
                          >
                            {store.isDeleted ? '삭제됨' : '활성'}
                          </span>
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm font-medium space-x-2">
                          {!store.isDeleted && (
                            <>
                              {store.status === 'PENDING' && (
                                <>
                                  <Button
                                    variant="primary"
                                    size="sm"
                                    onClick={() => handleApproveStore(store.id)}
                                  >
                                    승인
                                  </Button>
                                  <Button
                                    variant="danger"
                                    size="sm"
                                    onClick={() => handleRejectStore(store.id)}
                                  >
                                    거절
                                  </Button>
                                </>
                              )}
                              {store.status === 'APPROVED' && (
                                <Button
                                  variant="danger"
                                  size="sm"
                                  onClick={() => handleRejectStore(store.id)}
                                >
                                  승인 취소
                                </Button>
                              )}
                              {store.status === 'REJECTED' && (
                                <Button
                                  variant="primary"
                                  size="sm"
                                  onClick={() => handleApproveStore(store.id)}
                                >
                                  승인
                                </Button>
                              )}
                              <Button
                                variant="danger"
                                size="sm"
                                onClick={() => handleDeleteStore(store.id)}
                              >
                                삭제
                              </Button>
                            </>
                          )}
                          {store.isDeleted && (
                            <span className="text-sm text-gray-500">작업 불가</span>
                          )}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
              {/* 페이지네이션 */}
              <div className="px-6 py-4 border-t border-gray-200 flex justify-between items-center">
                <Button
                  variant="outline"
                  disabled={storePage === 0}
                  onClick={() => loadStores(storePage - 1)}

                >
                  이전
                </Button>
                <span className="text-sm text-gray-700">
                  {storePage + 1} / {stores.totalPages} 페이지
                </span>
                <Button
                  variant="outline"
                  disabled={storePage >= stores.totalPages - 1}
                  onClick={() => loadStores(storePage + 1)}
                >
                  다음
                </Button>
              </div>
            </div>
          )}
        </>
      )}

      {/* 주문 상세 모달 */}
      {selectedOrder && (
        <div
          className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4"
          onClick={() => setSelectedOrder(null)}
        >
          <div
            className="bg-white rounded-xl shadow-xl max-w-2xl w-full p-6 max-h-[90vh] overflow-y-auto"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-xl font-semibold">주문 상세</h2>
              <button
                type="button"
                onClick={() => setSelectedOrder(null)}
                className="text-gray-500 hover:text-gray-700"
                aria-label="닫기"
              >
                ✕
              </button>
            </div>

            <dl className="grid grid-cols-1 sm:grid-cols-2 gap-x-6 gap-y-3 text-sm mb-6">
              <div>
                <dt className="text-gray-500">주문 번호</dt>
                <dd className="text-gray-900 font-medium">{selectedOrder.orderNumber || '-'}</dd>
              </div>
              <div>
                <dt className="text-gray-500">주문 ID</dt>
                <dd className="text-gray-900 break-all">{selectedOrder.orderId}</dd>
              </div>
              <div>
                <dt className="text-gray-500">가게</dt>
                <dd className="text-gray-900">{selectedOrder.storeName}</dd>
              </div>
              <div>
                <dt className="text-gray-500">주문자 ID</dt>
                <dd className="text-gray-900">{selectedOrder.userId}</dd>
              </div>
              <div>
                <dt className="text-gray-500">상태</dt>
                <dd className="text-gray-900">
                  {ORDER_STATUS_LABELS[selectedOrder.status] ?? selectedOrder.status}
                </dd>
              </div>
              <div>
                <dt className="text-gray-500">주문 시각</dt>
                <dd className="text-gray-900">{formatDateTime(selectedOrder.createdAt)}</dd>
              </div>
              <div>
                <dt className="text-gray-500">픽업 시각</dt>
                <dd className="text-gray-900">{formatDateTime(selectedOrder.pickupTime)}</dd>
              </div>
              <div>
                <dt className="text-gray-500">일회용품</dt>
                <dd className="text-gray-900">{selectedOrder.needDisposables ? '필요' : '불필요'}</dd>
              </div>
              {selectedOrder.estimatedTime != null && (
                <div>
                  <dt className="text-gray-500">예상 조리 시간</dt>
                  <dd className="text-gray-900">{selectedOrder.estimatedTime}분</dd>
                </div>
              )}
              {selectedOrder.request && (
                <div className="sm:col-span-2">
                  <dt className="text-gray-500">요청 사항</dt>
                  <dd className="text-gray-900 whitespace-pre-wrap">{selectedOrder.request}</dd>
                </div>
              )}
              {selectedOrder.reason && (
                <div className="sm:col-span-2">
                  <dt className="text-gray-500">
                    거절/취소 사유{selectedOrder.cancelledBy ? ` (${selectedOrder.cancelledBy})` : ''}
                  </dt>
                  <dd className="text-gray-900 whitespace-pre-wrap">{selectedOrder.reason}</dd>
                </div>
              )}
            </dl>

            <h3 className="text-sm font-medium text-gray-700 mb-2">주문 항목</h3>
            <div className="border rounded-lg divide-y">
              {(selectedOrder.orderItems ?? []).length === 0 ? (
                <p className="p-4 text-sm text-gray-500">항목 정보가 없습니다.</p>
              ) : (
                selectedOrder.orderItems.map((item) => (
                  <div key={item.id ?? `${item.menuId}-${item.quantity}`} className="p-4 text-sm">
                    <div className="flex justify-between">
                      <span className="font-medium text-gray-900">
                        {item.menuName} × {item.quantity}
                      </span>
                      <span className="text-gray-900">
                        {Number(item.subtotal ?? item.menuPrice * item.quantity).toLocaleString()}원
                      </span>
                    </div>
                    {item.options && item.options.length > 0 && (
                      <ul className="mt-1 text-gray-500 space-y-0.5">
                        {item.options.map((option) => (
                          <li key={option.id ?? option.menuOptionId}>
                            + {option.optionName}
                            {option.optionDetail ? ` (${option.optionDetail})` : ''}
                            {option.optionPrice ? ` ${Number(option.optionPrice).toLocaleString()}원` : ''}
                          </li>
                        ))}
                      </ul>
                    )}
                  </div>
                ))
              )}
            </div>

            <div className="flex justify-between items-center mt-4 pt-4 border-t">
              <span className="text-sm text-gray-500">총 금액</span>
              <span className="text-lg font-bold text-gray-900">
                {Number(selectedOrder.totalAmount ?? 0).toLocaleString()}원
              </span>
            </div>

            <div className="mt-6 flex justify-end">
              <Button variant="outline" onClick={() => setSelectedOrder(null)}>
                닫기
              </Button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
