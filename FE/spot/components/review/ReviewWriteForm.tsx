'use client';

import {useState} from 'react';
import {reviewApi} from '@/lib/review';
import {getApiErrorMessage} from '@/lib/api';
import {useAuth} from '@/store/authStore';
import Button from '@/components/ui/Button';

interface ReviewWriteFormProps {
  storeId: string;
  onSuccess?: () => void;
}

export function ReviewWriteForm({ storeId, onSuccess }: ReviewWriteFormProps) {
  const { user } = useAuth();
  const [rating, setRating] = useState(0);
  const [content, setContent] = useState('');
  const [hoveredRating, setHoveredRating] = useState(0);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!user) {
      alert('로그인이 필요합니다.');
      return;
    }

    if (rating === 0) {
      alert('별점을 선택해주세요.');
      return;
    }

    try {
      setIsSubmitting(true);
      await reviewApi.createReview({
        storeId,
        rating,
        content: content.trim() || undefined,
      });
      alert('리뷰가 작성되었습니다.');
      setRating(0);
      setContent('');
      onSuccess?.();
    } catch (error) {
      console.error('리뷰 작성 실패:', error);
      alert(getApiErrorMessage(error, '리뷰 작성에 실패했습니다.'));
    } finally {
      setIsSubmitting(false);
    }
  };

  const renderStars = () => {
    return (
      <div className="flex gap-1">
        {[1, 2, 3, 4, 5].map((star) => (
          <button
            key={star}
            type="button"
            onClick={() => setRating(star)}
            onMouseEnter={() => setHoveredRating(star)}
            onMouseLeave={() => setHoveredRating(0)}
            className={`text-4xl transition-all ${
              star <= (hoveredRating || rating)
                ? 'text-yellow-400 scale-110'
                : 'text-gray-300'
            } hover:scale-125`}
          >
            ★
          </button>
        ))}
      </div>
    );
  };

  if (!user) {
    return (
      <div className="bg-gray-50 p-6 rounded-lg text-center">
        <p className="text-gray-600">로그인 후 리뷰를 작성할 수 있습니다.</p>
      </div>
    );
  }

  return (
    <div className="bg-white border border-gray-200 rounded-lg p-6">
      <h3 className="text-lg font-semibold text-gray-900 mb-4">리뷰 작성</h3>
      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">
            별점 <span className="text-red-500">*</span>
          </label>
          {renderStars()}
          {rating > 0 && (
            <p className="text-sm text-gray-600 mt-2">
              {rating}점을 선택하셨습니다.
            </p>
          )}
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">
            리뷰 내용 (선택)
          </label>
          <textarea
            value={content}
            onChange={(e) => setContent(e.target.value)}
            placeholder="이 가게에 대한 솔직한 리뷰를 남겨주세요."
            className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            rows={4}
            maxLength={500}
          />
          <p className="text-sm text-gray-500 mt-1 text-right">
            {content.length} / 500
          </p>
        </div>

        <div className="flex justify-end gap-2">
          <Button
            type="button"
            variant="outline"
            onClick={() => {
              setRating(0);
              setContent('');
            }}
            disabled={isSubmitting}
          >
            초기화
          </Button>
          <Button type="submit" disabled={isSubmitting || rating === 0}>
            {isSubmitting ? '작성 중...' : '리뷰 작성'}
          </Button>
        </div>
      </form>
    </div>
  );
}
