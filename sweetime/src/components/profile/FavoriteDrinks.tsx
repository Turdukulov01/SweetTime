import { getProductById } from '@/lib/mock-data';
import { ProductCard } from '@/components/catalog/ProductCard';

export function FavoriteDrinks({ productIds }: { productIds: string[] }) {
  const products = productIds.map(getProductById).filter((p): p is NonNullable<typeof p> => Boolean(p));

  if (products.length === 0) {
    return <p className="text-ink-muted">Отмечайте любимые напитки сердечком на странице товара.</p>;
  }

  return (
    <div className="grid grid-cols-2 gap-4 sm:grid-cols-3">
      {products.map((product, i) => (
        <ProductCard key={product.id} product={product} index={i} />
      ))}
    </div>
  );
}
