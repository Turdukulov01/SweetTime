'use client';

import Link from 'next/link';
import { ShoppingBag } from 'lucide-react';
import { useCart } from '@/context/CartContext';
import { CartItemRow } from '@/components/cart/CartItemRow';
import { PromoCodeInput } from '@/components/cart/PromoCodeInput';
import { OrderSummary } from '@/components/cart/OrderSummary';
import { Card } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';

export default function CartPage() {
  const { items } = useCart();

  if (items.length === 0) {
    return (
      <div className="container-sweetime flex flex-col items-center justify-center gap-4 py-24 text-center">
        <ShoppingBag className="h-16 w-16 text-pink-200" />
        <h1 className="section-heading">Корзина пуста</h1>
        <p className="text-ink-muted">Загляните в каталог — там точно найдётся что-то вкусное.</p>
        <Link href="/catalog">
          <Button>Перейти в каталог</Button>
        </Link>
      </div>
    );
  }

  return (
    <div className="container-sweetime py-10">
      <h1 className="section-heading mb-8">Корзина</h1>
      <div className="grid gap-8 lg:grid-cols-[1fr_360px]">
        <Card className="divide-y divide-pink-100/70 dark:divide-berry-300/10">
          {items.map((item) => (
            <CartItemRow key={item.id} item={item} />
          ))}
        </Card>

        <div className="space-y-4">
          <Card>
            <PromoCodeInput />
          </Card>
          <Card>
            <OrderSummary />
            <Link href="/checkout" className="mt-5 block">
              <Button fullWidth size="lg">
                Оформить заказ
              </Button>
            </Link>
          </Card>
        </div>
      </div>
    </div>
  );
}
