import { fetchAdminOrders } from '@/lib/api';
import { OrdersTable } from '@/components/admin/OrdersTable';

export const metadata = { title: 'Заказы — Admin' };

export default async function AdminOrdersPage() {
  const orders = await fetchAdminOrders();
  return (
    <div>
      <h2 className="mb-6 font-display text-xl font-semibold text-berry-500 dark:text-cream">
        Заказы
      </h2>
      <OrdersTable orders={orders} />
    </div>
  );
}
