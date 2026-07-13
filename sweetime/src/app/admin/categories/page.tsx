'use client';

import { Plus } from 'lucide-react';
import { CATEGORIES } from '@/lib/mock-data';
import { Button } from '@/components/ui/Button';
import { Card } from '@/components/ui/Card';

export default function AdminCategoriesPage() {
  return (
    <div>
      <div className="mb-6 flex items-center justify-between">
        <h2 className="font-display text-xl font-semibold text-berry-500 dark:text-cream">
          Категории
        </h2>
        <Button size="sm">
          <Plus className="h-4 w-4" /> Добавить
        </Button>
      </div>
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
        {CATEGORIES.map((cat) => (
          <Card key={cat.id} className="flex items-center gap-3">
            <span className="flex h-10 w-10 items-center justify-center rounded-blob bg-pink-100 text-xl">
              {cat.emoji}
            </span>
            <div>
              <p className="font-semibold text-ink dark:text-cream">{cat.name}</p>
              <p className="text-xs text-ink-muted">/{cat.slug}</p>
            </div>
          </Card>
        ))}
      </div>
    </div>
  );
}
