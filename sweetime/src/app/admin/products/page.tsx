import { PRODUCTS } from '@/lib/mock-data';
import { ProductsTable } from '@/components/admin/ProductsTable';

export const metadata = { title: 'Товары — Admin' };

export default function AdminProductsPage() {
  return (
    <div>
      <h2 className="mb-6 font-display text-xl font-semibold text-berry-500 dark:text-cream">
        Товары
      </h2>
      <ProductsTable products={PRODUCTS} />
    </div>
  );
}
