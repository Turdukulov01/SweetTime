'use client';

import { Suspense, useEffect, useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { SlidersHorizontal, X } from 'lucide-react';
import { fetchProducts, type ProductQuery } from '@/lib/api';
import type { Product } from '@/types';
import { useDebounce } from '@/hooks/useDebounce';
import { SearchBar } from '@/components/catalog/SearchBar';
import { Filters } from '@/components/catalog/Filters';
import { SortDropdown } from '@/components/catalog/SortDropdown';
import { Pagination } from '@/components/catalog/Pagination';
import { ProductCard } from '@/components/catalog/ProductCard';
import { ProductCardSkeleton } from '@/components/ui/Skeleton';

const PER_PAGE = 8;

function CatalogContent() {
  const router = useRouter();
  const searchParams = useSearchParams();

  const [search, setSearch] = useState(searchParams.get('search') ?? '');
  const [category, setCategory] = useState<string | null>(searchParams.get('category'));
  const [tag, setTag] = useState<string | null>(searchParams.get('tag'));
  const [sort, setSort] = useState<NonNullable<ProductQuery['sort']>>(
    (searchParams.get('sort') as ProductQuery['sort']) ?? 'popular',
  );
  const [page, setPage] = useState(1);
  const [mobileFiltersOpen, setMobileFiltersOpen] = useState(false);

  const [items, setItems] = useState<Product[]>([]);
  const [total, setTotal] = useState(0);
  const [isLoading, setIsLoading] = useState(true);

  const debouncedSearch = useDebounce(search, 350);

  useEffect(() => setPage(1), [debouncedSearch, category, tag, sort]);

  useEffect(() => {
    setIsLoading(true);
    fetchProducts({
      search: debouncedSearch,
      categorySlug: category ?? undefined,
      tag: (tag as Product['tags'][number]) ?? undefined,
      sort,
      page,
      perPage: PER_PAGE,
    }).then((result) => {
      setItems(result.items);
      setTotal(result.total);
      setIsLoading(false);
    });
  }, [debouncedSearch, category, tag, sort, page]);

  useEffect(() => {
    const params = new URLSearchParams();
    if (debouncedSearch) params.set('search', debouncedSearch);
    if (category) params.set('category', category);
    if (tag) params.set('tag', tag);
    if (sort !== 'popular') params.set('sort', sort);
    router.replace(`/catalog${params.toString() ? `?${params}` : ''}`, { scroll: false });
  }, [debouncedSearch, category, tag, sort, router]);

  const totalPages = Math.max(1, Math.ceil(total / PER_PAGE));

  return (
    <div className="container-sweetime py-10">
      <h1 className="section-heading mb-2">Каталог</h1>
      <p className="mb-8 text-ink-muted">Найдено {total} напитков</p>

      <div className="grid gap-8 lg:grid-cols-[240px_1fr]">
        <aside className="hidden lg:block">
          <Filters
            categorySlug={category}
            onCategoryChange={setCategory}
            tag={tag}
            onTagChange={setTag}
          />
        </aside>

        <div>
          <div className="mb-6 flex flex-col gap-3 sm:flex-row sm:items-center">
            <div className="flex-1">
              <SearchBar value={search} onChange={setSearch} />
            </div>
            <div className="flex gap-2">
              <button
                onClick={() => setMobileFiltersOpen(true)}
                className="flex items-center gap-2 rounded-pearl border-2 border-pink-100 bg-white px-4 py-2.5 text-sm font-medium lg:hidden dark:bg-berry-700/40 dark:text-cream"
              >
                <SlidersHorizontal className="h-4 w-4" /> Фильтры
              </button>
              <SortDropdown value={sort} onChange={setSort} />
            </div>
          </div>

          {isLoading ? (
            <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 xl:grid-cols-4">
              {Array.from({ length: PER_PAGE }).map((_, i) => (
                <ProductCardSkeleton key={i} />
              ))}
            </div>
          ) : items.length === 0 ? (
            <div className="rounded-3xl border border-dashed border-pink-200 py-20 text-center text-ink-muted">
              Ничего не нашлось. Попробуйте изменить фильтры или запрос.
            </div>
          ) : (
            <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 xl:grid-cols-4">
              {items.map((product, i) => (
                <ProductCard key={product.id} product={product} index={i} />
              ))}
            </div>
          )}

          <Pagination page={page} totalPages={totalPages} onChange={setPage} />
        </div>
      </div>

      {mobileFiltersOpen && (
        <div className="fixed inset-0 z-50 flex lg:hidden">
          <div className="flex-1 bg-berry-700/40" onClick={() => setMobileFiltersOpen(false)} />
          <div className="w-[85%] max-w-xs overflow-y-auto bg-cream p-6 dark:bg-berry-600">
            <div className="mb-4 flex items-center justify-between">
              <h2 className="font-display text-lg font-semibold text-berry-500 dark:text-cream">
                Фильтры
              </h2>
              <button onClick={() => setMobileFiltersOpen(false)} aria-label="Закрыть фильтры">
                <X className="h-5 w-5" />
              </button>
            </div>
            <Filters
              categorySlug={category}
              onCategoryChange={(c) => {
                setCategory(c);
                setMobileFiltersOpen(false);
              }}
              tag={tag}
              onTagChange={(t) => {
                setTag(t);
                setMobileFiltersOpen(false);
              }}
            />
          </div>
        </div>
      )}
    </div>
  );
}

export default function CatalogPage() {
  return (
    <Suspense fallback={null}>
      <CatalogContent />
    </Suspense>
  );
}
