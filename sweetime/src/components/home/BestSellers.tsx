import { PRODUCTS } from '@/lib/mock-data';
import { ProductRail } from '@/components/home/ProductRail';

export function BestSellers() {
  const items = PRODUCTS.filter((p) => p.tags.includes('bestseller')).slice(0, 4);
  return <ProductRail title="Хиты продаж" products={items} viewAllHref="/catalog?tag=bestseller" />;
}
