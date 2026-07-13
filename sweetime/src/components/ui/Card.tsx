import { cn } from '@/lib/utils';

export function Card({ className, children }: { className?: string; children: React.ReactNode }) {
  return (
    <div
      className={cn(
        'rounded-3xl border border-pink-100/70 bg-white/90 p-6 shadow-soft backdrop-blur-sm',
        'dark:bg-berry-700/40 dark:border-berry-300/20',
        className,
      )}
    >
      {children}
    </div>
  );
}
