'use client';

import { useMemo, useState } from 'react';
import { motion } from 'framer-motion';
import { Check, Minus, Plus } from 'lucide-react';
import type { Product, IceLevel, Size, SugarLevel } from '@/types';
import { ICE_LEVELS, SIZES, SUGAR_LEVELS, TOPPINGS } from '@/lib/constants';
import { formatPrice, cn } from '@/lib/utils';
import { useCart } from '@/context/CartContext';
import { Button } from '@/components/ui/Button';

export function ProductCustomizer({ product }: { product: Product }) {
  const { addItem } = useCart();
  const [size, setSize] = useState<Size>(product.availableSizes[0] ?? 'M');
  const [ice, setIce] = useState<IceLevel>('Стандарт');
  const [sugar, setSugar] = useState<SugarLevel>('100%');
  const [toppingIds, setToppingIds] = useState<string[]>([]);
  const [quantity, setQuantity] = useState(1);
  const [justAdded, setJustAdded] = useState(false);

  const availableToppingOptions = TOPPINGS.filter((t) => product.availableToppings.includes(t.id));
  const sizeInfo = SIZES.find((s) => s.value === size);

  const toppingsTotal = useMemo(
    () =>
      toppingIds.reduce((sum, id) => sum + (TOPPINGS.find((t) => t.id === id)?.price ?? 0), 0),
    [toppingIds],
  );

  const unitPrice = product.price + (sizeInfo?.priceDelta ?? 0) + toppingsTotal;

  function toggleTopping(id: string) {
    setToppingIds((prev) => (prev.includes(id) ? prev.filter((t) => t !== id) : [...prev, id]));
  }

  function handleAddToCart() {
    addItem(product.id, unitPrice, { size, ice, sugar, toppingIds }, quantity);
    setJustAdded(true);
    setTimeout(() => setJustAdded(false), 1800);
  }

  return (
    <div className="space-y-6">
      {product.availableSizes.length > 0 && (
        <div>
          <h3 className="mb-2 text-sm font-semibold text-ink dark:text-cream">Размер</h3>
          <div className="flex gap-2">
            {SIZES.filter((s) => product.availableSizes.includes(s.value)).map((s) => (
              <button
                key={s.value}
                onClick={() => setSize(s.value)}
                className={cn(
                  'flex-1 rounded-2xl border-2 px-3 py-2.5 text-center transition-colors',
                  size === s.value
                    ? 'border-berry-500 bg-berry-500 text-cream'
                    : 'border-pink-100 text-ink hover:border-pink-300 dark:text-cream',
                )}
              >
                <span className="block font-semibold">{s.label}</span>
                <span className="block text-xs opacity-80">{s.volumeMl} мл</span>
              </button>
            ))}
          </div>
        </div>
      )}

      <div>
        <h3 className="mb-2 text-sm font-semibold text-ink dark:text-cream">Лёд</h3>
        <div className="flex flex-wrap gap-2">
          {ICE_LEVELS.map((level) => (
            <button
              key={level}
              onClick={() => setIce(level)}
              className={cn(
                'rounded-pearl border-2 px-3 py-1.5 text-xs font-medium transition-colors',
                ice === level
                  ? 'border-mint-500 bg-mint-200 text-mint-600'
                  : 'border-pink-100 text-ink hover:border-pink-300 dark:text-cream',
              )}
            >
              {level}
            </button>
          ))}
        </div>
      </div>

      <div>
        <h3 className="mb-2 text-sm font-semibold text-ink dark:text-cream">Сахар</h3>
        <div className="flex flex-wrap gap-2">
          {SUGAR_LEVELS.map((level) => (
            <button
              key={level}
              onClick={() => setSugar(level)}
              className={cn(
                'rounded-pearl border-2 px-3 py-1.5 text-xs font-medium transition-colors',
                sugar === level
                  ? 'border-caramel-500 bg-caramel-100 text-caramel-600'
                  : 'border-pink-100 text-ink hover:border-pink-300 dark:text-cream',
              )}
            >
              {level}
            </button>
          ))}
        </div>
      </div>

      {availableToppingOptions.length > 0 && (
        <div>
          <h3 className="mb-2 text-sm font-semibold text-ink dark:text-cream">Топпинги и добавки</h3>
          <div className="space-y-2">
            {availableToppingOptions.map((topping) => {
              const checked = toppingIds.includes(topping.id);
              return (
                <button
                  key={topping.id}
                  onClick={() => toggleTopping(topping.id)}
                  className={cn(
                    'flex w-full items-center justify-between rounded-2xl border-2 px-4 py-2.5 text-sm transition-colors',
                    checked ? 'border-pink-400 bg-pink-50' : 'border-pink-100 hover:border-pink-300',
                  )}
                >
                  <span className="flex items-center gap-2 text-ink dark:text-cream">
                    <span
                      className={cn(
                        'flex h-5 w-5 items-center justify-center rounded-full border-2',
                        checked ? 'border-pink-400 bg-pink-400 text-white' : 'border-pink-200',
                      )}
                    >
                      {checked && <Check className="h-3 w-3" />}
                    </span>
                    {topping.name}
                  </span>
                  <span className="font-mono text-ink-muted">+{formatPrice(topping.price)}</span>
                </button>
              );
            })}
          </div>
        </div>
      )}

      <div className="flex items-center gap-4 border-t border-pink-100 pt-5 dark:border-berry-300/20">
        <div className="flex items-center gap-3 rounded-pearl bg-pink-50 px-3 py-2 dark:bg-berry-600/60">
          <button
            onClick={() => setQuantity((q) => Math.max(1, q - 1))}
            className="flex h-7 w-7 items-center justify-center rounded-full bg-white text-berry-500 shadow-sm dark:bg-berry-700"
            aria-label="Уменьшить количество"
          >
            <Minus className="h-3.5 w-3.5" />
          </button>
          <span className="w-5 text-center font-semibold">{quantity}</span>
          <button
            onClick={() => setQuantity((q) => q + 1)}
            className="flex h-7 w-7 items-center justify-center rounded-full bg-white text-berry-500 shadow-sm dark:bg-berry-700"
            aria-label="Увеличить количество"
          >
            <Plus className="h-3.5 w-3.5" />
          </button>
        </div>
        <Button size="lg" fullWidth onClick={handleAddToCart}>
          {justAdded ? (
            <motion.span initial={{ scale: 0.8 }} animate={{ scale: 1 }} className="flex items-center gap-2">
              <Check className="h-5 w-5" /> Добавлено
            </motion.span>
          ) : (
            `В корзину — ${formatPrice(unitPrice * quantity)}`
          )}
        </Button>
      </div>
    </div>
  );
}
