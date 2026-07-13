'use client';

import { cn } from '@/lib/utils';
import { CATEGORIES } from '@/lib/mock-data';

const TAGS: Array<{ value: string; label: string }> = [
  { value: 'new', label: 'Новинки' },
  { value: 'bestseller', label: 'Хиты' },
  { value: 'sale', label: 'Акции' },
  { value: 'signature', label: 'Авторские' },
];

export function Filters({
  categorySlug,
  onCategoryChange,
  tag,
  onTagChange,
}: {
  categorySlug: string | null;
  onCategoryChange: (slug: string | null) => void;
  tag: string | null;
  onTagChange: (tag: string | null) => void;
}) {
  return (
    <div className="space-y-6">
      <div>
        <h3 className="mb-3 font-display text-sm font-semibold uppercase tracking-wide text-berry-500 dark:text-cream">
          Категории
        </h3>
        <div className="flex flex-col gap-1">
          <button
            onClick={() => onCategoryChange(null)}
            className={cn(
              'rounded-2xl px-3 py-2 text-left text-sm font-medium transition-colors',
              !categorySlug
                ? 'bg-pink-200 text-berry-600'
                : 'text-ink hover:bg-pink-100/70 dark:text-cream',
            )}
          >
            Все напитки
          </button>
          {CATEGORIES.map((cat) => (
            <button
              key={cat.id}
              onClick={() => onCategoryChange(cat.slug)}
              className={cn(
                'flex items-center gap-2 rounded-2xl px-3 py-2 text-left text-sm font-medium transition-colors',
                categorySlug === cat.slug
                  ? 'bg-pink-200 text-berry-600'
                  : 'text-ink hover:bg-pink-100/70 dark:text-cream',
              )}
            >
              <span>{cat.emoji}</span> {cat.name}
            </button>
          ))}
        </div>
      </div>

      <div>
        <h3 className="mb-3 font-display text-sm font-semibold uppercase tracking-wide text-berry-500 dark:text-cream">
          Метки
        </h3>
        <div className="flex flex-wrap gap-2">
          {TAGS.map((t) => (
            <button
              key={t.value}
              onClick={() => onTagChange(tag === t.value ? null : t.value)}
              className={cn(
                'rounded-pearl border-2 px-3 py-1.5 text-xs font-semibold transition-colors',
                tag === t.value
                  ? 'border-berry-500 bg-berry-500 text-cream'
                  : 'border-pink-200 text-ink hover:border-pink-400 dark:text-cream',
              )}
            >
              {t.label}
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}
