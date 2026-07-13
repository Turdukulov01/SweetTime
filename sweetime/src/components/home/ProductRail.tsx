import Link from 'next/link';
import { ArrowRight } from 'lucide-react';
import type { Product } from '@/types';
import { ProductCard } from '@/components/catalog/ProductCard';

export function ProductRail({
  title,
  products,
  viewAllHref,
}: {
  title: string;
  products: Product[];
  viewAllHref: string;
}) {
  if (products.length === 0) return null;

  return (
    <section className="container-sweetime py-8">
      <div className="mb-6 flex items-end justify-between">
        <h2 className="section-heading">{title}</h2>
        <Link
          href={viewAllHref}
          className="flex items-center gap-1 text-sm font-semibold text-berry-500 hover:underline dark:text-cream"
        >
          Все <ArrowRight className="h-4 w-4" />
        </Link>
      </div>
      <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-4">
        {products.map((product, i) => (
          <ProductCard key={product.id} product={product} index={i} />
        ))}
      </div>
    </section>
  );
}
