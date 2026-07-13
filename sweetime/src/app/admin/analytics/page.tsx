import { fetchAnalytics } from '@/lib/api';
import { AnalyticsCharts } from '@/components/admin/AnalyticsCharts';

export const metadata = { title: 'Аналитика — Admin' };

export default async function AdminAnalyticsPage() {
  const data = await fetchAnalytics();

  const totalRevenue = data.reduce((s, d) => s + d.revenue, 0);
  const totalOrders = data.reduce((s, d) => s + d.orders, 0);
  const avgOrder = Math.round(totalRevenue / totalOrders);

  return (
    <div className="space-y-8">
      <h2 className="font-display text-xl font-semibold text-berry-500 dark:text-cream">
        Аналитика — последние 7 дней
      </h2>

      <div className="grid gap-4 sm:grid-cols-3">
        {[
          { label: 'Выручка за период', value: `${(totalRevenue / 1000).toFixed(0)} тыс. ₽` },
          { label: 'Всего заказов', value: String(totalOrders) },
          { label: 'Средний чек', value: `${avgOrder} ₽` },
        ].map((item) => (
          <div
            key={item.label}
            className="rounded-3xl border border-pink-100/70 bg-white p-5 shadow-soft dark:border-berry-300/20 dark:bg-berry-700/40"
          >
            <p className="text-sm text-ink-muted">{item.label}</p>
            <p className="mt-1 font-display text-3xl font-semibold text-berry-500 dark:text-cream">
              {item.value}
            </p>
          </div>
        ))}
      </div>

      <AnalyticsCharts data={data} />
    </div>
  );
}
