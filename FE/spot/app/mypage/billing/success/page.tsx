'use client';

import {Suspense, useEffect, useState} from 'react';
import {useRouter, useSearchParams} from 'next/navigation';
import axios from 'axios';
import {useAuthStore} from '@/store/authStore';
import {paymentApi} from '@/lib/payments';
import type {PaymentMethod} from '@/types';

function BillingSuccessContent() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const user = useAuthStore((state) => state.user);

  const [status, setStatus] = useState<'processing' | 'success' | 'error'>('processing');
  const [errorMessage, setErrorMessage] = useState('');

  useEffect(() => {
    const saveBillingKeyAndPay = async () => {
      try {
        // URL에서 파라미터 추출 (authKey 는 민감값 — 로그로 남기지 않는다)
        const authKey = searchParams.get('authKey');
        const customerKey = searchParams.get('customerKey');
        const orderId = searchParams.get('orderId');
        const paymentMethod = searchParams.get('paymentMethod') as PaymentMethod | null;

        if (!authKey || !customerKey) {
          throw new Error('빌링키 정보가 없습니다.');
        }

        if (!user) {
          throw new Error('사용자 정보를 불러올 수 없습니다.');
        }

        // 1. 빌링키 저장
        await paymentApi.saveBillingKey({
          userId: user.id,
          authKey,
          customerKey,
        });

        // 2. orderId가 있으면 자동으로 결제 진행
        if (orderId) {
          const paymentData = {
            title: '주문 결제',
            content: '자동결제 등록 후 결제',
            userId: user.id,
            orderId,
            paymentMethod: paymentMethod ?? 'CREDIT_CARD',
            paymentAmount: 0, // 서버에서 주문 금액 조회
          };

          await paymentApi.confirmPayment(orderId, paymentData);

          setStatus('success');

          // 3초 후 주문 내역으로 이동
          setTimeout(() => {
            router.push('/orders');
          }, 3000);
        } else {
          // orderId가 없으면 빌링키만 등록한 경우
          setStatus('success');
          setTimeout(() => {
            router.push('/mypage/billing');
          }, 3000);
        }
      } catch (error: unknown) {
        console.error('빌링키 저장 또는 결제 실패:', error);
        setStatus('error');
        const message = axios.isAxiosError(error)
          ? error.response?.data?.message || error.message
          : error instanceof Error
            ? error.message
            : undefined;
        setErrorMessage(message || '처리 중 오류가 발생했습니다.');
      }
    };

    if (user) {
      saveBillingKeyAndPay();
    }
  }, [user, searchParams, router]);

  if (status === 'processing') {
    return (
      <div className="min-h-[80vh] flex items-center justify-center px-4">
        <div className="w-full max-w-md text-center">
          <div className="mb-6 flex justify-center">
            <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-orange-500"></div>
          </div>
          <h1 className="text-2xl font-bold text-gray-900 mb-2">처리 중입니다</h1>
          <p className="text-gray-600">
            빌링키를 저장하고 결제를 진행하고 있습니다...
          </p>
        </div>
      </div>
    );
  }

  if (status === 'error') {
    return (
      <div className="min-h-[80vh] flex items-center justify-center px-4">
        <div className="w-full max-w-md text-center">
          <div className="mb-6 flex justify-center">
            <div className="rounded-full bg-red-100 p-4">
              <svg className="w-12 h-12 text-red-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </div>
          </div>
          <h1 className="text-2xl font-bold text-gray-900 mb-2">처리 실패</h1>
          <p className="text-gray-600 mb-8">{errorMessage}</p>
          <button
            onClick={() => router.push('/cart')}
            className="px-6 py-3 bg-orange-500 text-white rounded-lg hover:bg-orange-600"
          >
            장바구니로 돌아가기
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-[80vh] flex items-center justify-center px-4">
      <div className="w-full max-w-md text-center">
        <div className="mb-6 flex justify-center">
          <div className="rounded-full bg-green-100 p-4">
            <svg className="w-12 h-12 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M5 13l4 4L19 7" />
            </svg>
          </div>
        </div>
        <h1 className="text-2xl font-bold text-gray-900 mb-2">결제가 완료되었습니다!</h1>
        <p className="text-gray-600 mb-8">
          자동결제가 등록되어 다음부터는 간편하게 결제하실 수 있습니다.
        </p>
        <p className="text-sm text-gray-500">
          잠시 후 주문 내역 페이지로 이동합니다...
        </p>
      </div>
    </div>
  );
}

export default function BillingSuccessPage() {
  return (
    <Suspense
      fallback={
        <div className="min-h-[80vh] flex items-center justify-center px-4">
          <div className="w-full max-w-md text-center">
            <div className="mb-6 flex justify-center">
              <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-orange-500"></div>
            </div>
            <h1 className="text-2xl font-bold text-gray-900 mb-2">처리 중입니다</h1>
            <p className="text-gray-600">로딩 중...</p>
          </div>
        </div>
      }
    >
      <BillingSuccessContent />
    </Suspense>
  );
}
