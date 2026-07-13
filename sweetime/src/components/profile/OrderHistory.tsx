import type { Order, OrderStatus } from '@/types';
import { formatDate, formatPrice, cn } from '@/lib/utils';
import { Card } from '@/components/ui/Card';

const STATUS_LABEL: Record<OrderStatus, { label: string; tone: string }> = {
  processing: { label: 'Оформлен', tone: 'bg-caramel-100 text-caramel-600' },
  preparing: { label: 'Готовится', tone: 'bg-caramel-100 text-caramel-600' },
  delivering: { label: 'В пути', tone: 'bg-mint-200 text-mint-600' },
  completed: { label: 'Выполнен', tone: 'bg-mint-200 text-mint-600' },
  cancelled: { label: 'Отменён', tone: 'bg-pink-100 text-ink-muted' },
};

export function OrderHistory({ orders }: { orders: Order[] }) {
  if (orders.length === 0) {
    return <p className="text-ink-muted">Здесь появятся ваши заказы.</p>;
  }

  return (
    <div className="space-y-4">
      {orders.map((order) => {
        const status = STATUS_LABEL[order.status];
        return (
          <Card key={order.id}>
            <div className="flex flex-wrap items-center justify-between gap-2">
              <div>
                <p className="font-mono font-semibold text-ink dark:text-cream">{order.id}</p>
                <p className="text-xs text-ink-muted">{formatDate(order.date)}</p>
              </div>
              <span className={cn('rounded-pearl px-3 py-1 text-xs font-semibold', status.tone)}>
                {status.label}
              </span>
            </div>
            <ul className="mt-3 space-y-1 text-sm text-ink-muted">
              {order.items.map((item, i) => (
                <li key={i}>
                  {item.quantity} × {item.name}{' '}
                  <span className="text-xs">({item.customization})</span>
                </li>
              ))}
            </ul>
            <div className="mt-3 flex items-center justify-between border-t border-pink-100 pt-3 dark:border-berry-300/20">
              <span className="text-sm text-ink-muted">
                {order.deliveryType === 'delivery' ? 'Доставка' : 'Самовывоз'}
                {order.bonusesEarned > 0 && ` · +${order.bonusesEarned} бонусов`}
              </span>
              <span className="font-mono font-semibold text-berry-500 dark:text-cream">
                {formatPrice(order.total)}
              </span>
            </div>
          </Card>
        );
      })}
    </div>
  );
}
