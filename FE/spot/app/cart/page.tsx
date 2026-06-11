'use client';

import React, {useState} from 'react';
import {useRouter} from 'next/navigation';
import Link from 'next/link';
import {useCartStore} from '@/store/cartStore';
import {useAuthStore} from '@/store/authStore';
import {orderApi} from '@/lib/orders';
import {paymentApi} from '@/lib/payments';
import {Button} from '@/components/ui/Button';
import type {PaymentMethod} from '@/types';
import {loadTossPayments} from '@tosspayments/payment-sdk';

export default function CartPage() {
  const router = useRouter();
  const { cart, updateQuantity, removeItem, clearCart, getTotal } = useCartStore();
  const isAuthenticated = useAuthStore((state) => state.isAuthenticated);
  const user = useAuthStore((state) => state.user);
  const hasHydrated = useAuthStore((state) => state.hasHydrated);

  const [pickupTime, setPickupTime] = useState('');
  const [needDisposables, setNeedDisposables] = useState(false);
  const [request, setRequest] = useState('');
  const [paymentMethod, setPaymentMethod] = useState<PaymentMethod>('CREDIT_CARD');
  const [isLoading, setIsLoading] = useState(false);
  const [step, setStep] = useState<'cart' | 'checkout'>('cart');

  // 장바구니 데이터 유효성 검사
  React.useEffect(() => {
    if (cart && cart.items.length > 0) {
      console.log('=== 장바구니 검증 시작 ===');
      console.log('장바구니 전체:', cart);
      console.log('아이템 개수:', cart.items.length);

      cart.items.forEach((item, index) => {
        console.log(`아이템 ${index}:`, {
          hasMenu: !!item.menu,
          menu: item.menu,
          menuId: item.menu?.id,
          quantity: item.quantity,
          selectedOptions: item.selectedOptions
        });
      });
    }
  }, [cart]);

  const handleCheckout = () => {
    // 2. 스토어가 로드되지 않았다면 아무것도 하지 않거나 로딩 처리를 합니다.
    if (!hasHydrated) return;

    if (!isAuthenticated) {
      alert('로그인이 필요합니다.');
      router.push('/login');
      return;
    }
    setStep('checkout');
  };

  if (!hasHydrated) {
    return <div className="p-8 text-center">로그인 정보를 확인 중입니다...</div>;
  }

  const handleOrder = async () => {
    console.log('[Debug] handleOrder 호출 - cart:', cart, 'user:', user);

    if (!cart) {
      alert('장바구니가 비어있습니다.');
      return;
    }

    if (!user) {
      alert('로그인 정보를 불러오는 중입니다. 잠시 후 다시 시도해주세요.');
      return;
    }

    // 픽업 시간 검증
    if (!pickupTime) {
      alert('픽업 시간을 선택해주세요.');
      return;
    }

    const pickupDateTime = new Date(pickupTime);
    if (pickupDateTime <= new Date()) {
      alert('픽업 시간은 현재 시간 이후여야 합니다.');
      return;
    }

    setIsLoading(true);

    try {
      // 0. 빌링키 존재 여부 확인
      const hasBillingKey = await paymentApi.checkBillingKeyExists();
      console.log(hasBillingKey);
      
      // 1. 주문 생성
      console.log('장바구니 원본 데이터:', cart);

      // 장바구니 데이터 검증
      const invalidItems = cart.items.filter(item => !item.menu || !item.menu.id);
      if (invalidItems.length > 0) {
        console.error('유효하지 않은 장바구니 아이템:', invalidItems);
        console.error('전체 장바구니:', cart);

        // 자동으로 장바구니 초기화
        if (window.confirm('장바구니에 잘못된 데이터가 있습니다. 장바구니를 비우고 새로 시작하시겠습니까?')) {
          clearCart();
          localStorage.removeItem('cart-storage');
          window.location.reload();
        }
        return;
      }

      console.log('장바구니 아이템들:', cart.items.map(item => ({
        menuId: item.menu.id,
        menuName: item.menu.name,
        quantity: item.quantity,
        selectedOptions: item.selectedOptions
      })));

      const orderData = {
        storeId: cart.storeId,
        orderItems: cart.items.map((item) => {
          console.log('처리 중인 아이템:', {
            menuId: item.menu?.id,
            menuIdType: typeof item.menu?.id,
            hasMenu: !!item.menu,
            menuObject: item.menu
          });

          if (!item.menu || !item.menu.id) {
            throw new Error(`유효하지 않은 메뉴 데이터: ${JSON.stringify(item)}`);
          }

          return {
            menuId: item.menu.id,
            quantity: item.quantity,
            ...(item.selectedOptions.length > 0 && {
              options: item.selectedOptions.map((opt) => ({
                menuOptionId: opt.id
                // value: opt.optionName,
              })),
            }),
          };
        }),
        pickupTime: pickupDateTime.toISOString(),
        needDisposables,
        ...(request && { request }),
      };

      console.log('주문 데이터:', JSON.stringify(orderData, null, 2));

      const order = await orderApi.createOrder(orderData);
      console.log("@@");
      // 2. 결제 진행
      if (hasBillingKey) {

        // 2-A. 빌링키가 있으면 자동 결제
        const paymentData = {
          title: `${cart.storeName} 주문`,
          content: `${cart.items.map((i) => i.menu.name).join(', ')}`,
          userId: user.id,
          orderId: order.orderId,
          paymentMethod,
          paymentAmount: getTotal(),
        };

        await paymentApi.confirmPayment(order.orderId, paymentData);

        // 장바구니 비우기
        clearCart();

        // 주문 완료 페이지로 이동
        alert('주문이 완료되었습니다!');
        router.push('/orders');
      } else {

        // 2-B. 빌링키가 없으면 토스 결제창 띄우기
        const clientKey = process.env.NEXT_PUBLIC_TOSS_CLIENT_KEY;

        if (!clientKey) {
          throw new Error('토스페이먼츠 클라이언트 키가 설정되지 않았습니다.');
        }

        const tossPayments = await loadTossPayments(clientKey);

        // 빌링키 발급 요청
        const customerKey = `customer_${user.id}_${Date.now()}`;

        console.log('=== requestBillingAuth 호출 ===');
        console.log('customerKey:', customerKey);
        console.log('customerName:', user.username);

        const response = await tossPayments.requestBillingAuth('카드', {
          customerKey: customerKey,
          customerName: user.username,
          successUrl: `${window.location.origin}/mypage/billing/success?orderId=${order.orderId}&paymentMethod=${paymentMethod}`,
          failUrl: `${window.location.origin}/payemnts/fail`,
        });

        console.log('=== requestBillingAuth 응답 ===');
        console.log(response);

        // 토스 결제창이 열리면 이 이후 코드는 실행되지 않음
        // billing success 페이지에서 빌링키 저장 후 결제 처리
      }
    } catch (error: any) {
      console.error('Order failed:', error);
      console.error('Error response:', error.response?.data);
      console.error('Error status:', error.response?.status);

      const errorMessage = error.response?.data?.message || error.message || '주문에 실패했습니다.';
      alert(`주문 실패: ${errorMessage}`);
    } finally {
      setIsLoading(false);
    }
  };

  // 최소 픽업 시간 (현재 시간 + 30분)
  const getMinPickupTime = () => {
    const now = new Date();
    now.setMinutes(now.getMinutes() + 30);
    return now.toISOString().slice(0, 16);
  };

  if (!cart || cart.items.length === 0) {
    return (
      <div className="max-w-2xl mx-auto px-4 py-16 text-center">
        <div className="text-6xl mb-4">🛒</div>
        <h1 className="text-2xl font-bold text-gray-900 mb-4">장바구니가 비어있습니다</h1>
        <p className="text-gray-500 mb-8">맛있는 음식을 담아보세요!</p>
        <Link href="/">
          <Button>가게 둘러보기</Button>
        </Link>
      </div>
    );
  }

  return (
    <div className="max-w-2xl mx-auto px-4 py-8">
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-2xl font-bold text-gray-900">
          {step === 'cart' ? '장바구니' : '주문하기'}
        </h1>
        {step === 'cart' && (
          <button
            onClick={() => {
              if (window.confirm('장바구니를 비우시겠습니까?')) {
                clearCart();
                localStorage.removeItem('cart-storage');
              }
            }}
            className="text-sm text-red-500 hover:text-red-700"
          >
            장바구니 비우기
          </button>
        )}
      </div>

      {/* 가게 정보 */}
      <div className="bg-white rounded-xl shadow-md p-4 mb-6">
        <Link href={`/stores/${cart.storeId}`} className="flex items-center gap-3">
          <span className="text-2xl">🏪</span>
          <span className="font-semibold text-gray-900">{cart.storeName}</span>
        </Link>
      </div>

      {step === 'cart' ? (
        <>
          {/* 장바구니 아이템 */}
          <div className="bg-white rounded-xl shadow-md divide-y">
            {cart.items.map((item, index) => (
              <div key={`${item.menu.id}-${index}`} className="p-4">
                <div className="flex justify-between items-start mb-2">
                  <div>
                    <h3 className="font-medium text-gray-900">{item.menu.name}</h3>
                    {item.selectedOptions.length > 0 && (
                      <p className="text-sm text-gray-500 mt-1">
                        옵션: {item.selectedOptions.map((o) => o.name).join(', ')}
                      </p>
                    )}
                  </div>
                  <button
                    onClick={() => removeItem(item.menu.id)}
                    className="text-gray-400 hover:text-red-500"
                  >
                    <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                    </svg>
                  </button>
                </div>

                <div className="flex justify-between items-center">
                  <div className="flex items-center gap-3">
                    <button
                      onClick={() => updateQuantity(item.menu.id, item.quantity - 1)}
                      className="w-8 h-8 rounded-full border border-gray-300 flex items-center justify-center hover:bg-gray-50"
                    >
                      -
                    </button>
                    <span className="font-medium">{item.quantity}</span>
                    <button
                      onClick={() => updateQuantity(item.menu.id, item.quantity + 1)}
                      className="w-8 h-8 rounded-full border border-gray-300 flex items-center justify-center hover:bg-gray-50"
                    >
                      +
                    </button>
                  </div>
                  <span className="font-semibold text-gray-900">
                    {(
                      (item.menu.price +
                        item.selectedOptions.reduce((sum, o) => sum + (o.price || 0), 0)) *
                      item.quantity
                    ).toLocaleString()}
                    원
                  </span>
                </div>
              </div>
            ))}
          </div>

          {/* 총 금액 */}
          <div className="bg-white rounded-xl shadow-md p-4 mt-6">
            <div className="flex justify-between items-center text-lg font-bold">
              <span>총 주문금액</span>
              <span className="text-orange-500">{getTotal().toLocaleString()}원</span>
            </div>
          </div>

          {/* 주문하기 버튼 */}
          <div className="mt-6">
            <Button onClick={handleCheckout} className="w-full" size="lg">
              {getTotal().toLocaleString()}원 주문하기
            </Button>
          </div>
        </>
      ) : (
        <>
          {/* 주문 정보 입력 */}
          <div className="space-y-6">
            {/* 픽업 시간 */}
            <div className="bg-white rounded-xl shadow-md p-4">
              <h3 className="font-semibold text-gray-900 mb-3">픽업 시간</h3>
              <input
                type="datetime-local"
                value={pickupTime}
                onChange={(e) => setPickupTime(e.target.value)}
                min={getMinPickupTime()}
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-orange-500"
              />
              <p className="text-sm text-gray-500 mt-2">
                * 최소 30분 후부터 픽업 가능합니다
              </p>
            </div>

            {/* 일회용품 */}
            <div className="bg-white rounded-xl shadow-md p-4">
              <label className="flex items-center gap-3 cursor-pointer">
                <input
                  type="checkbox"
                  checked={needDisposables}
                  onChange={(e) => setNeedDisposables(e.target.checked)}
                  className="w-5 h-5 text-orange-500 rounded focus:ring-orange-500"
                />
                <span className="text-gray-900">일회용품 필요 (수저, 포크 등)</span>
              </label>
            </div>

            {/* 요청사항 */}
            <div className="bg-white rounded-xl shadow-md p-4">
              <h3 className="font-semibold text-gray-900 mb-3">요청사항</h3>
              <textarea
                value={request}
                onChange={(e) => setRequest(e.target.value)}
                placeholder="요청사항을 입력해주세요 (선택)"
                maxLength={500}
                rows={3}
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-orange-500 resize-none"
              />
            </div>

            {/* 결제 수단 */}
            <div className="bg-white rounded-xl shadow-md p-4">
              <h3 className="font-semibold text-gray-900 mb-3">결제 수단</h3>
              <div className="space-y-2">
                {[
                  { value: 'CREDIT_CARD', label: '신용카드' },
                  { value: 'DEBIT_CARD', label: '체크카드' },
                  { value: 'BANK_TRANSFER', label: '계좌이체' },
                ].map((method) => (
                  <label
                    key={method.value}
                    className="flex items-center gap-3 p-3 border rounded-lg cursor-pointer hover:bg-gray-50"
                  >
                    <input
                      type="radio"
                      name="paymentMethod"
                      value={method.value}
                      checked={paymentMethod === method.value}
                      onChange={(e) => setPaymentMethod(e.target.value as PaymentMethod)}
                      className="w-5 h-5 text-orange-500 focus:ring-orange-500"
                    />
                    <span className="text-gray-900">{method.label}</span>
                  </label>
                ))}
              </div>
            </div>

            {/* 주문 요약 */}
            <div className="bg-white rounded-xl shadow-md p-4">
              <h3 className="font-semibold text-gray-900 mb-3">주문 요약</h3>
              <div className="space-y-2 text-sm">
                {cart.items.map((item, index) => (
                  <div key={`summary-${item.menu.id}-${index}`} className="flex justify-between">
                    <span className="text-gray-600">
                      {item.menu.name} x {item.quantity}
                    </span>
                    <span className="text-gray-900">
                      {(
                        (item.menu.price +
                          item.selectedOptions.reduce((sum, o) => sum + (o.price || 0), 0)) *
                        item.quantity
                      ).toLocaleString()}
                      원
                    </span>
                  </div>
                ))}
              </div>
              <div className="border-t mt-4 pt-4">
                <div className="flex justify-between text-lg font-bold">
                  <span>총 결제금액</span>
                  <span className="text-orange-500">{getTotal().toLocaleString()}원</span>
                </div>
              </div>
            </div>

            {/* 버튼 */}
            <div className="flex gap-3">
              <Button
                variant="secondary"
                onClick={() => setStep('cart')}
                className="flex-1"
                size="lg"
              >
                이전
              </Button>
              <Button
                onClick={handleOrder}
                className="flex-1"
                size="lg"
                isLoading={isLoading}
              >
                결제하기
              </Button>
            </div>
          </div>
        </>
      )}
    </div>
  );
}
