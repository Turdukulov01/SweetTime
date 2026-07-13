import type { Product } from '@/types';
import { ProductCard } from '@/components/catalog/ProductCard';

export function Recommendations({ products }: { products: Product[] }) {
  if (products.length === 0) return null;
  return (
    <section>
      <h2 className="section-heading mb-6">Вам может понравиться</h2>
      <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-4">
        {products.map((product, i) => (
          <ProductCard key={product.id} product={product} index={i} />
        ))}
      </div>
    </section>
  );
}
