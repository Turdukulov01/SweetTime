import { ProductCardSkeleton } from '@/components/ui/Skeleton';

export default function CatalogLoading() {
  return (
    <div className="container-sweetime py-10">
      <div className="mb-8 h-9 w-48 animate-shimmer rounded-2xl bg-cream-deep" />
      <div className="grid gap-4 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4">
        {Array.from({ length: 8 }).map((_, i) => (
          <ProductCardSkeleton key={i} />
        ))}
      </div>
    </div>
  );
}
