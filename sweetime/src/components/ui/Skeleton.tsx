import { cn } from '@/lib/utils';

export function Skeleton({ className }: { className?: string }) {
  return (
    <div
      className={cn(
        'animate-shimmer rounded-2xl bg-[linear-gradient(110deg,#F3E4CE_8%,#FDF6ED_18%,#F3E4CE_33%)]',
        'bg-[length:200%_100%]',
        className,
      )}
    />
  );
}

export function ProductCardSkeleton() {
  return (
    <div className="rounded-3xl border border-pink-100/70 bg-white p-4">
      <Skeleton className="mb-4 aspect-square w-full" />
      <Skeleton className="mb-2 h-4 w-3/4" />
      <Skeleton className="mb-4 h-3 w-1/2" />
      <Skeleton className="h-8 w-full rounded-pearl" />
    </div>
  );
}
