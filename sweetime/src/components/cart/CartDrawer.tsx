'use client';

import Link from 'next/link';
import { AnimatePresence, motion } from 'framer-motion';
import { ShoppingBag, X } from 'lucide-react';
import { useCart } from '@/context/CartContext';
import { CartItemRow } from '@/components/cart/CartItemRow';
import { OrderSummary } from '@/components/cart/OrderSummary';
import { Button } from '@/components/ui/Button';

export function CartDrawer({ open, onClose }: { open: boolean; onClose: () => void }) {
  const { items } = useCart();

  return (
    <AnimatePresence>
      {open && (
        <>
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={onClose}
            className="fixed inset-0 z-50 bg-berry-700/40 backdrop-blur-sm"
          />
          <motion.div
            initial={{ x: '100%' }}
            animate={{ x: 0 }}
            exit={{ x: '100%' }}
            transition={{ type: 'spring', stiffness: 320, damping: 34 }}
            className="fixed inset-y-0 right-0 z-50 flex w-full max-w-md flex-col bg-cream shadow-lifted dark:bg-berry-600"
          >
            <div className="flex items-center justify-between border-b border-pink-100 px-6 py-5 dark:border-berry-300/20">
              <h2 className="font-display text-xl font-semibold text-berry-500 dark:text-cream">
                Корзина
              </h2>
              <button
                onClick={onClose}
                aria-label="Закрыть корзину"
                className="flex h-9 w-9 items-center justify-center rounded-pearl hover:bg-pink-100/70 dark:hover:bg-berry-300/10"
              >
                <X className="h-5 w-5" />
              </button>
            </div>

            {items.length === 0 ? (
              <div className="flex flex-1 flex-col items-center justify-center gap-3 px-6 text-center">
                <ShoppingBag className="h-12 w-12 text-pink-200" />
                <p className="font-body text-ink-muted">Корзина пока пуста</p>
                <Link href="/catalog" onClick={onClose}>
                  <Button size="sm">Перейти в каталог</Button>
                </Link>
              </div>
            ) : (
              <>
                <div className="flex-1 divide-y divide-pink-100/70 overflow-y-auto px-6 dark:divide-berry-300/10">
                  {items.map((item) => (
                    <CartItemRow key={item.id} item={item} compact />
                  ))}
                </div>
                <div className="space-y-4 border-t border-pink-100 px-6 py-5 dark:border-berry-300/20">
                  <OrderSummary showBonusToggle={false} />
                  <Link href="/cart" onClick={onClose}>
                    <Button fullWidth>Оформить заказ</Button>
                  </Link>
                </div>
              </>
            )}
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}
