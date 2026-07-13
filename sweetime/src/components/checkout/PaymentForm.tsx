'use client';

import { Banknote, CreditCard, Smartphone } from 'lucide-react';
import { cn } from '@/lib/utils';
import { Input } from '@/components/ui/Input';

export type PaymentMethod = 'card' | 'cash' | 'wallet';

const METHODS: Array<{ value: PaymentMethod; label: string; icon: typeof CreditCard }> = [
  { value: 'card', label: 'Картой онлайн', icon: CreditCard },
  { value: 'cash', label: 'Наличными курьеру', icon: Banknote },
  { value: 'wallet', label: 'Apple Pay / Google Pay', icon: Smartphone },
];

export function PaymentForm({
  method,
  onMethodChange,
}: {
  method: PaymentMethod;
  onMethodChange: (m: PaymentMethod) => void;
}) {
  return (
    <div className="space-y-4">
      <div className="grid gap-2 sm:grid-cols-3">
        {METHODS.map((m) => (
          <button
            key={m.value}
            onClick={() => onMethodChange(m.value)}
            className={cn(
              'flex flex-col items-center gap-2 rounded-2xl border-2 px-4 py-4 text-sm font-medium transition-colors',
              method === m.value
                ? 'border-berry-500 bg-berry-500 text-cream'
                : 'border-pink-100 text-ink hover:border-pink-300 dark:text-cream',
            )}
          >
            <m.icon className="h-5 w-5" />
            {m.label}
          </button>
        ))}
      </div>

      {method === 'card' && (
        <div className="grid gap-3 sm:grid-cols-2">
          <Input label="Номер карты" placeholder="0000 0000 0000 0000" inputMode="numeric" className="sm:col-span-2" />
          <Input label="Срок действия" placeholder="ММ/ГГ" inputMode="numeric" />
          <Input label="CVC" placeholder="123" inputMode="numeric" />
        </div>
      )}
    </div>
  );
}
