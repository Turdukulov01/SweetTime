import { CircleDollarSign, Package, ShoppingCart, Users } from 'lucide-react';
import { formatPrice } from '@/lib/utils';
import { Card } from '@/components/ui/Card';

interface Stat {
  label: string;
  value: string;
  delta: string;
  positive: boolean;
  icon: typeof CircleDollarSign;
}

export function DashboardStats({
  revenueToday,
  ordersToday,
  productsCount,
  usersCount,
}: {
  revenueToday: number;
  ordersToday: number;
  productsCount: number;
  usersCount: number;
}) {
  const stats: Stat[] = [
    {
      label: 'Выручка сегодня',
      value: formatPrice(revenueToday),
      delta: '+12.4%',
      positive: true,
      icon: CircleDollarSign,
    },
    {
      label: 'Заказы сегодня',
      value: String(ordersToday),
      delta: '+8.1%',
      positive: true,
      icon: ShoppingCart,
    },
    { label: 'Товаров в каталоге', value: String(productsCount), delta: '', positive: true, icon: Package },
    { label: 'Клиентов', value: String(usersCount), delta: '+3.2%', positive: true, icon: Users },
  ];

  return (
    <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
      {stats.map((stat) => (
        <Card key={stat.label}>
          <div className="flex items-center justify-between">
            <span className="flex h-10 w-10 items-center justify-center rounded-2xl bg-pink-100 text-berry-500">
              <stat.icon className="h-5 w-5" />
            </span>
            {stat.delta && (
              <span className="text-xs font-semibold text-mint-600">{stat.delta}</span>
            )}
          </div>
          <p className="mt-4 font-display text-2xl font-semibold text-berry-500 dark:text-cream">
            {stat.value}
          </p>
          <p className="text-sm text-ink-muted">{stat.label}</p>
        </Card>
      ))}
    </div>
  );
}
