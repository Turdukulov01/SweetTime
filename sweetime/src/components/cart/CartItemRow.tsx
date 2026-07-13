'use client';

import Image from 'next/image';
import { Minus, Plus, Trash2 } from 'lucide-react';
import type { CartItem } from '@/types';
import { getProductById } from '@/lib/mock-data';
import { formatPrice, cn } from '@/lib/utils';
import { useCart } from '@/context/CartContext';

export function CartItemRow({ item, compact = false }: { item: CartItem; compact?: boolean }) {
  const { updateQuantity, removeItem } = useCart();
  const product = getProductById(item.productId);
  if (!product) return null;

  const customLabel = [
    item.customization.size,
    item.customization.ice,
    `сахар ${item.customization.sugar}`,
    item.customization.toppingIds.length > 0 ? `+${item.customization.toppingIds.length} топпинга` : null,
  ]
    .filter(Boolean)
    .join(' · ');

  return (
    <div className={cn('flex gap-3', compact ? 'py-3' : 'py-4')}>
      <div className={cn('relative shrink-0 overflow-hidden rounded-2xl bg-pink-50', compact ? 'h-16 w-16' : 'h-20 w-20')}>
        <Image src={product.images[0]} alt={product.name} fill sizes="80px" className="object-cover" />
      </div>
      <div className="flex flex-1 flex-col justify-between gap-1">
        <div className="flex items-start justify-between gap-2">
          <div>
            <p className="font-body font-semibold leading-tight text-ink dark:text-cream">{product.name}</p>
            <p className="mt-0.5 text-xs text-ink-muted">{customLabel}</p>
          </div>
          <button
            onClick={() => removeItem(item.id)}
            aria-label="Удалить из корзины"
            className="shrink-0 text-ink-muted hover:text-red-500"
          >
            <Trash2 className="h-4 w-4" />
          </button>
        </div>
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2 rounded-pearl bg-pink-50 px-1.5 py-1 dark:bg-berry-600/60">
            <button
              onClick={() => updateQuantity(item.id, item.quantity - 1)}
              className="flex h-6 w-6 items-center justify-center rounded-full bg-white text-berry-500 shadow-sm dark:bg-berry-700"
              aria-label="Уменьшить количество"
            >
              <Minus className="h-3 w-3" />
            </button>
            <span className="w-4 text-center text-sm font-semibold">{item.quantity}</span>
            <button
              onClick={() => updateQuantity(item.id, item.quantity + 1)}
              className="flex h-6 w-6 items-center justify-center rounded-full bg-white text-berry-500 shadow-sm dark:bg-berry-700"
              aria-label="Увеличить количество"
            >
              <Plus className="h-3 w-3" />
            </button>
          </div>
          <span className="font-mono text-sm font-semibold text-berry-500 dark:text-cream">
            {formatPrice(item.unitPrice * item.quantity)}
          </span>
        </div>
      </div>
    </div>
  );
}
