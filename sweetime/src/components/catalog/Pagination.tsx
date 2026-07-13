'use client';

import { ChevronLeft, ChevronRight } from 'lucide-react';
import { cn } from '@/lib/utils';

export function Pagination({
  page,
  totalPages,
  onChange,
}: {
  page: number;
  totalPages: number;
  onChange: (page: number) => void;
}) {
  if (totalPages <= 1) return null;

  const pages = Array.from({ length: totalPages }, (_, i) => i + 1);

  return (
    <nav className="mt-10 flex items-center justify-center gap-1.5" aria-label="Пагинация">
      <button
        onClick={() => onChange(Math.max(1, page - 1))}
        disabled={page === 1}
        aria-label="Предыдущая страница"
        className="flex h-9 w-9 items-center justify-center rounded-pearl text-berry-500 hover:bg-pink-100/70 disabled:opacity-30"
      >
        <ChevronLeft className="h-4 w-4" />
      </button>
      {pages.map((p) => (
        <button
          key={p}
          onClick={() => onChange(p)}
          className={cn(
            'flex h-9 w-9 items-center justify-center rounded-pearl text-sm font-semibold',
            p === page ? 'bg-berry-500 text-cream' : 'text-ink hover:bg-pink-100/70 dark:text-cream',
          )}
        >
          {p}
        </button>
      ))}
      <button
        onClick={() => onChange(Math.min(totalPages, page + 1))}
        disabled={page === totalPages}
        aria-label="Следующая страница"
        className="flex h-9 w-9 items-center justify-center rounded-pearl text-berry-500 hover:bg-pink-100/70 disabled:opacity-30"
      >
        <ChevronRight className="h-4 w-4" />
      </button>
    </nav>
  );
}
