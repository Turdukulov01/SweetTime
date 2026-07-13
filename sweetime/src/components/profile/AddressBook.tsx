'use client';

import { useState } from 'react';
import { MapPin, Plus, Star, Trash2 } from 'lucide-react';
import type { Address } from '@/types';
import { Card } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { Input } from '@/components/ui/Input';

export function AddressBook({ addresses: initial }: { addresses: Address[] }) {
  const [addresses, setAddresses] = useState(initial);
  const [isAdding, setIsAdding] = useState(false);
  const [draft, setDraft] = useState({ label: '', street: '', city: 'Бишкек' });

  function handleAdd(e: React.FormEvent) {
    e.preventDefault();
    if (!draft.label || !draft.street) return;
    setAddresses((prev) => [...prev, { id: `a-${Date.now()}`, ...draft }]);
    setDraft({ label: '', street: '', city: 'Бишкек' });
    setIsAdding(false);
  }

  function handleRemove(id: string) {
    setAddresses((prev) => prev.filter((a) => a.id !== id));
  }

  return (
    <div className="space-y-4">
      {addresses.map((addr) => (
        <Card key={addr.id} className="flex items-start justify-between gap-3">
          <div className="flex items-start gap-3">
            <MapPin className="mt-0.5 h-4 w-4 shrink-0 text-berry-500" />
            <div>
              <p className="flex items-center gap-1.5 font-semibold text-ink dark:text-cream">
                {addr.label}
                {addr.isDefault && <Star className="h-3.5 w-3.5 fill-caramel-500 text-caramel-500" />}
              </p>
              <p className="text-sm text-ink-muted">
                {addr.street}
                {addr.apartment ? `, ${addr.apartment}` : ''}, {addr.city}
              </p>
            </div>
          </div>
          <button
            onClick={() => handleRemove(addr.id)}
            aria-label="Удалить адрес"
            className="text-ink-muted hover:text-red-500"
          >
            <Trash2 className="h-4 w-4" />
          </button>
        </Card>
      ))}

      {isAdding ? (
        <Card>
          <form onSubmit={handleAdd} className="space-y-3">
            <Input
              label="Название"
              placeholder="Дом, работа…"
              value={draft.label}
              onChange={(e) => setDraft((d) => ({ ...d, label: e.target.value }))}
              required
            />
            <Input
              label="Улица и дом"
              value={draft.street}
              onChange={(e) => setDraft((d) => ({ ...d, street: e.target.value }))}
              required
            />
            <div className="flex gap-2">
              <Button type="submit" size="sm">
                Сохранить
              </Button>
              <Button type="button" size="sm" variant="ghost" onClick={() => setIsAdding(false)}>
                Отмена
              </Button>
            </div>
          </form>
        </Card>
      ) : (
        <Button variant="outline" onClick={() => setIsAdding(true)}>
          <Plus className="h-4 w-4" /> Добавить адрес
        </Button>
      )}
    </div>
  );
}
