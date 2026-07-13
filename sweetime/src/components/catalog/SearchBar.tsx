'use client';

import { Search } from 'lucide-react';

export function SearchBar({
  value,
  onChange,
}: {
  value: string;
  onChange: (value: string) => void;
}) {
  return (
    <div className="relative">
      <Search className="pointer-events-none absolute left-4 top-1/2 h-4 w-4 -translate-y-1/2 text-ink-muted" />
      <input
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder="Найти напиток…"
        className="w-full rounded-pearl border-2 border-pink-100 bg-white py-3 pl-11 pr-4 text-sm focus:border-pink-400 focus:outline-none dark:bg-berry-700/40 dark:text-cream"
      />
    </div>
  );
}
