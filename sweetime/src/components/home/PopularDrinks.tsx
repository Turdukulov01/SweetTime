import { PRODUCTS } from '@/lib/mock-data';
import { ProductRail } from '@/components/home/ProductRail';

export function PopularDrinks() {
  const popular = [...PRODUCTS].sort((a, b) => b.reviewsCount - a.reviewsCount).slice(0, 4);
  return <ProductRail title="Популярные напитки" products={popular} viewAllHref="/catalog?sort=popular" />;
}
