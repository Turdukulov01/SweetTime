import { fetchCoupons } from '@/lib/api';
import { CouponsTable } from '@/components/admin/CouponsTable';

export const metadata = { title: 'Купоны — Admin' };

export default async function AdminCouponsPage() {
  const coupons = await fetchCoupons();
  return (
    <div>
      <h2 className="mb-6 font-display text-xl font-semibold text-berry-500 dark:text-cream">
        Купоны и промокоды
      </h2>
      <CouponsTable coupons={coupons} />
    </div>
  );
}
