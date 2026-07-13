'use client';

import { motion } from 'framer-motion';
import { Star } from 'lucide-react';
import { REVIEWS } from '@/lib/mock-data';
import { formatDate } from '@/lib/utils';
import { Card } from '@/components/ui/Card';

export function Reviews() {
  return (
    <section className="container-sweetime py-14">
      <h2 className="section-heading mb-6">Отзывы гостей</h2>
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {REVIEWS.slice(0, 6).map((review, i) => (
          <motion.div
            key={review.id}
            initial={{ opacity: 0, y: 16 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ delay: (i % 3) * 0.08 }}
          >
            <Card className="h-full">
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
          </motion.div>
        ))}
      </div>
    </section>
  );
}
