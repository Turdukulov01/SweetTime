'use client';

import { useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { motion } from 'framer-motion';
import { CheckCircle2 } from 'lucide-react';
import { useCart } from '@/context/CartContext';
import { useAuth } from '@/context/AuthContext';
import { DeliveryOptions } from '@/components/checkout/DeliveryOptions';
import { PaymentForm, type PaymentMethod } from '@/components/checkout/PaymentForm';
import { OrderSummary } from '@/components/cart/OrderSummary';
import { Card } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';

export default function CheckoutPage() {
  const router = useRouter();
  const { items, clearCart } = useCart();
  const { user } = useAuth();

  const [deliveryType, setDeliveryType] = useState<'delivery' | 'pickup'>('delivery');
  const [addressId, setAddressId] = useState<string | null>(user?.addresses[0]?.id ?? null);
  const [pickupPointId, setPickupPointId] = useState('pt-1');
  const [comment, setComment] = useState('');
  const [paymentMethod, setPaymentMethod] = useState<PaymentMethod>('card');
  const [isPlacingOrder, setIsPlacingOrder] = useState(false);
  const [orderPlaced, setOrderPlaced] = useState<string | null>(null);

  async function handlePlaceOrder() {
    setIsPlacingOrder(true);
    // Replace with a real POST /api/orders call once the backend (Этап 13) is live.
    await new Promise((resolve) => setTimeout(resolve, 900));
    const orderId = `ORD-${Math.floor(10000 + Math.random() * 89999)}`;
    setOrderPlaced(orderId);
    clearCart();
    setIsPlacingOrder(false);
  }

  if (orderPlaced) {
    return (
      <div className="container-sweetime flex flex-col items-center justify-center gap-4 py-24 text-center">
        <motion.div initial={{ scale: 0.6, opacity: 0 }} animate={{ scale: 1, opacity: 1 }}>
          <CheckCircle2 className="h-20 w-20 text-mint-500" />
        </motion.div>
        <h1 className="section-heading">Заказ {orderPlaced} принят!</h1>
        <p className="max-w-md text-ink-muted">
          Мы уже начали готовить ваш напиток. Отследить статус можно в разделе «История заказов».
        </p>
        <div className="flex gap-3">
          <Link href="/profile">
            <Button>История заказов</Button>
          </Link>
          <Link href="/catalog">
            <Button variant="outline">Заказать ещё</Button>
          </Link>
        </div>
      </div>
    );
  }

  if (items.length === 0) {
    router.replace('/cart');
    return null;
  }

  return (
    <div className="container-sweetime py-10">
      <h1 className="section-heading mb-8">Оформление заказа</h1>
      <div className="grid gap-8 lg:grid-cols-[1fr_360px]">
        <div className="space-y-6">
          <Card>
            <h2 className="mb-4 font-display text-lg font-semibold text-berry-500 dark:text-cream">
              Доставка
            </h2>
            <DeliveryOptions
              deliveryType={deliveryType}
              onDeliveryTypeChange={setDeliveryType}
              addresses={user?.addresses ?? []}
              selectedAddressId={addressId}
              onAddressSelect={setAddressId}
              pickupPointId={pickupPointId}
              onPickupPointChange={setPickupPointId}
              comment={comment}
              onCommentChange={setComment}
            />
          </Card>

          <Card>
            <h2 className="mb-4 font-display text-lg font-semibold text-berry-500 dark:text-cream">
              Оплата
            </h2>
            <PaymentForm method={paymentMethod} onMethodChange={setPaymentMethod} />
          </Card>
        </div>

        <div className="space-y-4">
          <Card>
            <OrderSummary />
            <Button
              fullWidth
              size="lg"
              className="mt-5"
              isLoading={isPlacingOrder}
              onClick={handlePlaceOrder}
            >
              Подтвердить заказ
            </Button>
          </Card>
        </div>
      </div>
    </div>
  );
}
