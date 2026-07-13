import { Star } from 'lucide-react';
import type { Review } from '@/types';
import { formatDate } from '@/lib/utils';
import { Card } from '@/components/ui/Card';

export function ReviewsList({ reviews }: { reviews: Review[] }) {
  if (reviews.length === 0) {
    return (
      <p className="rounded-3xl border border-dashed border-pink-200 py-10 text-center text-ink-muted">
        Пока нет отзывов — станьте первым!
      </p>
    );
  }

  return (
    <div className="grid gap-4 sm:grid-cols-2">
      {reviews.map((review) => (
        <Card key={review.id}>
          <div className="flex items-center gap-3">
            <span
              className={`flex h-10 w-10 items-center justify-center rounded-full text-sm font-semibold text-berry-600 ${review.avatarColor}`}
            >
              {review.author.charAt(0)}
            </span>
            <div>
              <p className="font-semibold text-ink dark:text-cream">{review.author}</p>
              <p className="text-xs text-ink-muted">{formatDate(review.date)}</p>
            </div>
          </div>
          <div className="mt-3 flex gap-0.5">
            {Array.from({ length: 5 }).map((_, idx) => (
              <Star
                key={idx}
                className={`h-4 w-4 ${idx < review.rating ? 'fill-caramel-500 text-caramel-500' : 'text-pink-100'}`}
              />
            ))}
          </div>
          <p className="mt-3 text-sm leading-relaxed text-ink-muted">{review.text}</p>
        </Card>
      ))}
    </div>
  );
}
