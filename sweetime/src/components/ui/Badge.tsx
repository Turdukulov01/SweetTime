import { cn } from '@/lib/utils';

type BadgeTone = 'pink' | 'mint' | 'caramel' | 'berry' | 'neutral';

const toneClasses: Record<BadgeTone, string> = {
  pink: 'bg-pink-200 text-berry-600',
  mint: 'bg-mint-200 text-mint-600',
  caramel: 'bg-caramel-100 text-caramel-600',
  berry: 'bg-berry-500 text-cream',
  neutral: 'bg-cream-deep text-ink',
};

export function Badge({
  tone = 'pink',
  className,
  children,
}: {
  tone?: BadgeTone;
  className?: string;
  children: React.ReactNode;
}) {
  return (
    <span
      className={cn(
        'inline-flex items-center gap-1 rounded-pearl px-3 py-1 text-xs font-semibold tracking-wide',
        toneClasses[tone],
        className,
      )}
    >
      {children}
    </span>
  );
}

export const TAG_LABELS: Record<string, { label: string; tone: BadgeTone }> = {
  new: { label: 'Новинка', tone: 'mint' },
  bestseller: { label: 'Хит', tone: 'berry' },
  sale: { label: 'Акция', tone: 'caramel' },
  signature: { label: 'Авторский', tone: 'pink' },
};
