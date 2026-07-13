'use client';

import { useState } from 'react';
import { Tag, X } from 'lucide-react';
import { useCart } from '@/context/CartContext';
import { Button } from '@/components/ui/Button';

export function PromoCodeInput() {
  const { coupon, couponError, applyCoupon, removeCoupon } = useCart();
  const [code, setCode] = useState('');
  const [isChecking, setIsChecking] = useState(false);

  async function handleApply() {
    if (!code.trim()) return;
    setIsChecking(true);
    await applyCoupon(code);
    setIsChecking(false);
  }

  if (coupon) {
    return (
      <div className="flex items-center justify-between rounded-2xl bg-mint-100 px-4 py-3 text-sm">
        <span className="flex items-center gap-2 font-semibold text-mint-600">
          <Tag className="h-4 w-4" /> Промокод {coupon.code} применён
        </span>
        <button onClick={removeCoupon} aria-label="Убрать промокод" className="text-mint-600 hover:text-berry-500">
          <X className="h-4 w-4" />
        </button>
      </div>
    );
  }

  return (
    <div>
      <div className="flex gap-2">
        <input
          value={code}
          onChange={(e) => setCode(e.target.value.toUpperCase())}
          placeholder="Промокод"
          className="w-full rounded-pearl border-2 border-pink-100 bg-white px-4 py-2.5 text-sm uppercase tracking-wide focus:border-pink-400 focus:outline-none dark:bg-berry-700/40 dark:text-cream"
        />
        <Button size="sm" variant="secondary" isLoading={isChecking} onClick={handleApply}>
          Применить
        </Button>
      </div>
      {couponError && <p className="mt-1.5 text-xs text-red-500">{couponError}</p>}
    </div>
  );
}
