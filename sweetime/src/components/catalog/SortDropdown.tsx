'use client';

import type { ProductQuery } from '@/lib/api';

const OPTIONS: Array<{ value: NonNullable<ProductQuery['sort']>; label: string }> = [
  { value: 'popular', label: 'Популярные' },
  { value: 'new', label: 'Сначала новинки' },
  { value: 'rating', label: 'По рейтингу' },
  { value: 'price-asc', label: 'Сначала дешевле' },
  { value: 'price-desc', label: 'Сначала дороже' },
];

export function SortDropdown({
  value,
  onChange,
}: {
  value: NonNullable<ProductQuery['sort']>;
  onChange: (value: NonNullable<ProductQuery['sort']>) => void;
}) {
  return (
    <select
      value={value}
      onChange={(e) => onChange(e.target.value as NonNullable<ProductQuery['sort']>)}
      className="rounded-pearl border-2 border-pink-100 bg-white px-4 py-2.5 text-sm font-medium text-ink focus:border-pink-400 focus:outline-none dark:bg-berry-700/40 dark:text-cream"
    >
      {OPTIONS.map((opt) => (
        <option key={opt.value} value={opt.value}>
          {opt.label}
        </option>
      ))}
    </select>
  );
}
