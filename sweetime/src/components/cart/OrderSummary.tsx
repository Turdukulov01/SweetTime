'use client';

import { useAuth } from '@/context/AuthContext';
import { useCart } from '@/context/CartContext';
import { formatPrice } from '@/lib/utils';
import { FREE_DELIVERY_THRESHOLD } from '@/lib/constants';

export function OrderSummary({ showBonusToggle = true }: { showBonusToggle?: boolean }) {
  const { subtotal, discount, deliveryFee, total, redeemedBonuses, setRedeemedBonuses } = useCart();
  const { user } = useAuth();

  const maxRedeemable = user ? Math.min(user.bonusBalance, Math.floor(subtotal * 0.3)) : 0;

  return (
    <div className="space-y-3">
      <div className="flex justify-between text-sm text-ink-muted">
        <span>Сумма</span>
        <span className="font-mono text-ink">{formatPrice(subtotal)}</span>
      </div>
      {discount > 0 && (
        <div className="flex justify-between text-sm text-mint-600">
          <span>Скидка</span>
          <span className="font-mono">−{formatPrice(discount)}</span>
        </div>
      )}
      <div className="flex justify-between text-sm text-ink-muted">
        <span>Доставка</span>
        <span className="font-mono text-ink">
          {deliveryFee === 0 ? 'Бесплатно' : formatPrice(deliveryFee)}
        </span>
      </div>
      {deliveryFee > 0 && (
        <p className="text-xs text-ink-muted">
          Бесплатная доставка от {formatPrice(FREE_DELIVERY_THRESHOLD)}
        </p>
      )}

      {showBonusToggle && user && maxRedeemable > 0 && (
        <label className="flex items-center justify-between rounded-2xl bg-caramel-100/60 px-4 py-3 text-sm">
          <span>
            Списать бонусы (доступно {user.bonusBalance})
          </span>
          <input
            type="checkbox"
            checked={redeemedBonuses > 0}
            onChange={(e) => setRedeemedBonuses(e.target.checked ? maxRedeemable : 0)}
            className="h-5 w-5 accent-berry-500"
          />
        </label>
      )}

      <div className="flex justify-between border-t border-pink-100 pt-3 font-display text-lg font-semibold text-berry-500 dark:border-berry-300/20 dark:text-cream">
        <span>Итого</span>
        <span className="font-mono">{formatPrice(total)}</span>
      </div>
    </div>
  );
}
