import { fetchAdminOrders, fetchAnalytics } from '@/lib/api';
import { PRODUCTS } from '@/lib/mock-data';
import { DashboardStats } from '@/components/admin/DashboardStats';
import { OrdersTable } from '@/components/admin/OrdersTable';
import { AnalyticsCharts } from '@/components/admin/AnalyticsCharts';

export default async function AdminDashboardPage() {
  const [orders, analytics] = await Promise.all([fetchAdminOrders(), fetchAnalytics()]);

  const todayRevenue = analytics.at(-1)?.revenue ?? 0;
  const todayOrders = analytics.at(-1)?.orders ?? 0;

  return (
    <div className="space-y-8">
      <DashboardStats
        revenueToday={todayRevenue}
        ordersToday={todayOrders}
        productsCount={PRODUCTS.length}
        usersCount={5}
      />

      <section>
        <h2 className="mb-4 font-display text-lg font-semibold text-berry-500 dark:text-cream">
          Аналитика за 7 дней
        </h2>
        <AnalyticsCharts data={analytics} />
      </section>

      <section>
        <h2 className="mb-4 font-display text-lg font-semibold text-berry-500 dark:text-cream">
          Последние заказы
        </h2>
        <OrdersTable orders={orders.slice(0, 5)} />
      </section>
    </div>
  );
}
