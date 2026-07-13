import type { AdminOrderRow, OrderStatus } from '@/types';
import { formatDate, formatPrice, cn } from '@/lib/utils';

const STATUS_STYLE: Record<OrderStatus, string> = {
  processing: 'bg-caramel-100 text-caramel-600',
  preparing: 'bg-caramel-100 text-caramel-600',
  delivering: 'bg-mint-200 text-mint-600',
  completed: 'bg-mint-200 text-mint-600',
  cancelled: 'bg-pink-100 text-ink-muted',
};

const STATUS_LABEL: Record<OrderStatus, string> = {
  processing: 'Новый',
  preparing: 'Готовится',
  delivering: 'В пути',
  completed: 'Выполнен',
  cancelled: 'Отменён',
};

export function OrdersTable({ orders }: { orders: AdminOrderRow[] }) {
  return (
    <div className="overflow-x-auto rounded-3xl border border-pink-100/70 dark:border-berry-300/20">
      <table className="w-full min-w-[640px] text-left text-sm">
        <thead className="bg-pink-50 text-xs uppercase tracking-wide text-ink-muted dark:bg-berry-600/40">
          <tr>
            <th className="px-4 py-3">Заказ</th>
            <th className="px-4 py-3">Клиент</th>
            <th className="px-4 py-3">Товары</th>
            <th className="px-4 py-3">Сумма</th>
            <th className="px-4 py-3">Статус</th>
            <th className="px-4 py-3">Дата</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-pink-100/70 dark:divide-berry-300/10">
          {orders.map((order) => (
            <tr key={order.id}>
              <td className="px-4 py-3 font-mono font-medium">{order.id}</td>
              <td className="px-4 py-3">{order.customer}</td>
              <td className="px-4 py-3 text-ink-muted">{order.itemsCount} шт.</td>
              <td className="px-4 py-3 font-mono">{formatPrice(order.total)}</td>
              <td className="px-4 py-3">
                <span className={cn('rounded-pearl px-3 py-1 text-xs font-semibold', STATUS_STYLE[order.status])}>
                  {STATUS_LABEL[order.status]}
                </span>
              </td>
              <td className="px-4 py-3 text-ink-muted">{formatDate(order.date)}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
