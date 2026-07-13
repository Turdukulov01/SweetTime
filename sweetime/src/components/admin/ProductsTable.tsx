'use client';

import { useState } from 'react';
import Image from 'next/image';
import { Pencil, Plus, Search, Trash2 } from 'lucide-react';
import type { Product } from '@/types';
import { formatPrice, cn } from '@/lib/utils';
import { getCategoryById } from '@/lib/mock-data';
import { Button } from '@/components/ui/Button';

export function ProductsTable({ products: initial }: { products: Product[] }) {
  const [products, setProducts] = useState(initial);
  const [search, setSearch] = useState('');

  const filtered = products.filter((p) => p.name.toLowerCase().includes(search.toLowerCase()));

  function remove(id: string) {
    setProducts((prev) => prev.filter((p) => p.id !== id));
  }

  return (
    <div>
      <div className="mb-4 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div className="relative w-full sm:max-w-xs">
          <Search className="pointer-events-none absolute left-3.5 top-1/2 h-4 w-4 -translate-y-1/2 text-ink-muted" />
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Поиск по названию"
            className="w-full rounded-pearl border-2 border-pink-100 bg-white py-2 pl-10 pr-3 text-sm focus:border-pink-400 focus:outline-none dark:bg-berry-700/40 dark:text-cream"
          />
        </div>
        <Button size="sm">
          <Plus className="h-4 w-4" /> Добавить товар
        </Button>
      </div>

      <div className="overflow-x-auto rounded-3xl border border-pink-100/70 dark:border-berry-300/20">
        <table className="w-full min-w-[640px] text-left text-sm">
          <thead className="bg-pink-50 text-xs uppercase tracking-wide text-ink-muted dark:bg-berry-600/40">
            <tr>
              <th className="px-4 py-3">Товар</th>
              <th className="px-4 py-3">Категория</th>
              <th className="px-4 py-3">Цена</th>
              <th className="px-4 py-3">Рейтинг</th>
              <th className="px-4 py-3 text-right">Действия</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-pink-100/70 dark:divide-berry-300/10">
            {filtered.map((product) => (
              <tr key={product.id}>
                <td className="flex items-center gap-3 px-4 py-3">
                  <div className="relative h-10 w-10 shrink-0 overflow-hidden rounded-xl bg-pink-50">
                    <Image src={product.images[0]} alt={product.name} fill sizes="40px" className="object-cover" />
                  </div>
                  <span className="font-medium text-ink dark:text-cream">{product.name}</span>
                </td>
                <td className="px-4 py-3 text-ink-muted">
                  {getCategoryById(product.categoryId)?.name}
                </td>
                <td className="px-4 py-3 font-mono">{formatPrice(product.price)}</td>
                <td className="px-4 py-3">{product.rating} ★</td>
                <td className="px-4 py-3">
                  <div className="flex justify-end gap-2">
                    <button
                      className={cn(
                        'flex h-8 w-8 items-center justify-center rounded-lg text-berry-500 hover:bg-pink-100',
                      )}
                      aria-label="Редактировать"
                    >
                      <Pencil className="h-4 w-4" />
                    </button>
                    <button
                      onClick={() => remove(product.id)}
                      className="flex h-8 w-8 items-center justify-center rounded-lg text-red-500 hover:bg-red-50"
                      aria-label="Удалить"
                    >
                      <Trash2 className="h-4 w-4" />
                    </button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
