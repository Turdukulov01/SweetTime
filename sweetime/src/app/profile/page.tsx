'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { Heart, MapPin, Settings, ShoppingBag, Sparkles } from 'lucide-react';
import { useAuth } from '@/context/AuthContext';
import { fetchOrders } from '@/lib/api';
import type { Order } from '@/types';
import { BonusBalance } from '@/components/profile/BonusBalance';
import { OrderHistory } from '@/components/profile/OrderHistory';
import { FavoriteDrinks } from '@/components/profile/FavoriteDrinks';
import { AddressBook } from '@/components/profile/AddressBook';
import { SettingsForm } from '@/components/profile/SettingsForm';
import { Button } from '@/components/ui/Button';
import { PearlLoader } from '@/components/ui/PearlLoader';
import { cn } from '@/lib/utils';

const TABS = [
  { id: 'orders', label: 'Заказы', icon: ShoppingBag },
  { id: 'favorites', label: 'Избранное', icon: Heart },
  { id: 'addresses', label: 'Адреса', icon: MapPin },
  { id: 'settings', label: 'Настройки', icon: Settings },
] as const;

type TabId = (typeof TABS)[number]['id'];

export default function ProfilePage() {
  const { user, isLoading } = useAuth();
  const [tab, setTab] = useState<TabId>('orders');
  const [orders, setOrders] = useState<Order[]>([]);

  useEffect(() => {
    if (user) fetchOrders().then(setOrders);
  }, [user]);

  if (isLoading) return <PearlLoader label="Загружаем профиль…" />;

  if (!user) {
    return (
      <div className="container-sweetime flex flex-col items-center gap-4 py-24 text-center">
        <Sparkles className="h-12 w-12 text-pink-200" />
        <h1 className="section-heading">Войдите в аккаунт</h1>
        <p className="text-ink-muted">Чтобы видеть бонусы, заказы и избранное — нужно авторизоваться.</p>
        <Link href="/auth/login">
          <Button>Войти</Button>
        </Link>
      </div>
    );
  }

  return (
    <div className="container-sweetime py-10">
      <div className="mb-8 flex items-center gap-4">
        <span className="flex h-16 w-16 items-center justify-center rounded-blob bg-mint-300 font-display text-2xl font-semibold text-berry-600">
          {user.name.charAt(0)}
        </span>
        <div>
          <h1 className="font-display text-2xl font-semibold text-berry-500 dark:text-cream">
            {user.name}
          </h1>
          <p className="text-sm text-ink-muted">{user.phone}</p>
        </div>
      </div>

      <div className="mb-8">
        <BonusBalance balance={user.bonusBalance} />
      </div>

      <div className="grid gap-8 lg:grid-cols-[220px_1fr]">
        <nav className="flex gap-2 overflow-x-auto lg:flex-col lg:overflow-visible">
          {TABS.map((t) => (
            <button
              key={t.id}
              onClick={() => setTab(t.id)}
              className={cn(
                'flex shrink-0 items-center gap-2 rounded-2xl px-4 py-2.5 text-sm font-medium transition-colors',
                tab === t.id
                  ? 'bg-berry-500 text-cream'
                  : 'text-ink hover:bg-pink-100/70 dark:text-cream',
              )}
            >
              <t.icon className="h-4 w-4" /> {t.label}
            </button>
          ))}
        </nav>

        <div>
          {tab === 'orders' && <OrderHistory orders={orders} />}
          {tab === 'favorites' && <FavoriteDrinks productIds={user.favoriteDrinkIds} />}
          {tab === 'addresses' && <AddressBook addresses={user.addresses} />}
          {tab === 'settings' && <SettingsForm user={user} />}
        </div>
      </div>
    </div>
  );
}
