'use client';

import { Megaphone, Plus } from 'lucide-react';
import { Button } from '@/components/ui/Button';
import { Card } from '@/components/ui/Card';

const MOCK_PROMOS = [
  { id: 'pr-1', title: '−15% на первый заказ', code: 'WELCOME150', active: true, ends: '31 дек 2026' },
  { id: 'pr-2', title: 'Двойные бонусы по пятницам', code: null, active: true, ends: 'Бессрочно' },
  { id: 'pr-3', title: 'Скидка на таро ко дню рождения', code: 'BIRTHDAY', active: false, ends: '—' },
];

export default function AdminPromotionsPage() {
  return (
    <div>
      <div className="mb-6 flex items-center justify-between">
        <h2 className="font-display text-xl font-semibold text-berry-500 dark:text-cream">
          Акции
        </h2>
        <Button size="sm">
          <Plus className="h-4 w-4" /> Новая акция
        </Button>
      </div>
      <div className="space-y-3">
        {MOCK_PROMOS.map((promo) => (
          <Card key={promo.id} className="flex items-center justify-between gap-4">
            <div className="flex items-center gap-3">
              <Megaphone className="h-5 w-5 shrink-0 text-pink-400" />
              <div>
                <p className="font-semibold text-ink dark:text-cream">{promo.title}</p>
                <p className="text-xs text-ink-muted">
                  {promo.code ? `Промокод: ${promo.code} · ` : ''}До {promo.ends}
                </p>
              </div>
            </div>
            <span
              className={`rounded-pearl px-3 py-1 text-xs font-semibold ${
                promo.active ? 'bg-mint-200 text-mint-600' : 'bg-pink-100 text-ink-muted'
              }`}
            >
              {promo.active ? 'Активна' : 'Неактивна'}
            </span>
          </Card>
        ))}
      </div>
    </div>
  );
}
