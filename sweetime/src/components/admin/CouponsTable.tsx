'use client';

import { useState } from 'react';
import { Plus } from 'lucide-react';
import type { Coupon } from '@/types';
import { formatDate, formatPrice, cn } from '@/lib/utils';
import { Button } from '@/components/ui/Button';

export function CouponsTable({ coupons: initial }: { coupons: Coupon[] }) {
  const [coupons, setCoupons] = useState(initial);

  function toggleActive(id: string) {
    setCoupons((prev) => prev.map((c) => (c.id === id ? { ...c, active: !c.active } : c)));
  }

  return (
    <div>
      <div className="mb-4 flex justify-end">
        <Button size="sm">
          <Plus className="h-4 w-4" /> Новый купон
        </Button>
      </div>
      <div className="overflow-x-auto rounded-3xl border border-pink-100/70 dark:border-berry-300/20">
        <table className="w-full min-w-[640px] text-left text-sm">
          <thead className="bg-pink-50 text-xs uppercase tracking-wide text-ink-muted dark:bg-berry-600/40">
            <tr>
              <th className="px-4 py-3">Код</th>
              <th className="px-4 py-3">Скидка</th>
              <th className="px-4 py-3">Мин. заказ</th>
              <th className="px-4 py-3">Использован</th>
              <th className="px-4 py-3">До</th>
              <th className="px-4 py-3">Статус</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-pink-100/70 dark:divide-berry-300/10">
            {coupons.map((coupon) => (
              <tr key={coupon.id}>
                <td className="px-4 py-3 font-mono font-semibold text-berry-500 dark:text-cream">
                  {coupon.code}
                </td>
                <td className="px-4 py-3">
                  {coupon.type === 'percent' ? `${coupon.value}%` : formatPrice(coupon.value)}
                </td>
                <td className="px-4 py-3 text-ink-muted">
                  {coupon.minOrder ? formatPrice(coupon.minOrder) : '—'}
                </td>
                <td className="px-4 py-3">{coupon.usageCount} раз</td>
                <td className="px-4 py-3 text-ink-muted">{formatDate(coupon.expiresAt)}</td>
                <td className="px-4 py-3">
                  <button
                    onClick={() => toggleActive(coupon.id)}
                    className={cn(
                      'rounded-pearl px-3 py-1 text-xs font-semibold',
                      coupon.active ? 'bg-mint-200 text-mint-600' : 'bg-pink-100 text-ink-muted',
                    )}
                  >
                    {coupon.active ? 'Активен' : 'Отключён'}
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
