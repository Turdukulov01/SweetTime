import { PRODUCTS } from '@/lib/mock-data';
import { ProductRail } from '@/components/home/ProductRail';

export function NewArrivals() {
  const items = PRODUCTS.filter((p) => p.tags.includes('new')).slice(0, 4);
  return <ProductRail title="Новинки" products={items} viewAllHref="/catalog?tag=new" />;
}
