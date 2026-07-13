'use client';

import { Bike, MapPin, Store } from 'lucide-react';
import type { Address } from '@/types';
import { Input, Textarea } from '@/components/ui/Input';
import { cn } from '@/lib/utils';

const PICKUP_POINTS = [
  { id: 'pt-1', name: 'Sweetime на Чуй', address: 'ул. Чуй 123' },
  { id: 'pt-2', name: 'Sweetime на Манаса', address: 'пр. Манаса 56' },
  { id: 'pt-3', name: 'Sweetime в ТРЦ Bishkek Park', address: 'ул. Ибраимова 115' },
];

export function DeliveryOptions({
  deliveryType,
  onDeliveryTypeChange,
  addresses,
  selectedAddressId,
  onAddressSelect,
  pickupPointId,
  onPickupPointChange,
  comment,
  onCommentChange,
}: {
  deliveryType: 'delivery' | 'pickup';
  onDeliveryTypeChange: (v: 'delivery' | 'pickup') => void;
  addresses: Address[];
  selectedAddressId: string | null;
  onAddressSelect: (id: string) => void;
  pickupPointId: string;
  onPickupPointChange: (id: string) => void;
  comment: string;
  onCommentChange: (v: string) => void;
}) {
  return (
    <div className="space-y-5">
      <div className="grid grid-cols-2 gap-3">
        <button
          onClick={() => onDeliveryTypeChange('delivery')}
          className={cn(
            'flex items-center justify-center gap-2 rounded-2xl border-2 px-4 py-3 font-medium transition-colors',
            deliveryType === 'delivery'
              ? 'border-berry-500 bg-berry-500 text-cream'
              : 'border-pink-100 text-ink hover:border-pink-300 dark:text-cream',
          )}
        >
          <Bike className="h-5 w-5" /> Доставка
        </button>
        <button
          onClick={() => onDeliveryTypeChange('pickup')}
          className={cn(
            'flex items-center justify-center gap-2 rounded-2xl border-2 px-4 py-3 font-medium transition-colors',
            deliveryType === 'pickup'
              ? 'border-berry-500 bg-berry-500 text-cream'
              : 'border-pink-100 text-ink hover:border-pink-300 dark:text-cream',
          )}
        >
          <Store className="h-5 w-5" /> Самовывоз
        </button>
      </div>

      {deliveryType === 'delivery' ? (
        <div className="space-y-2">
          {addresses.map((addr) => (
            <button
              key={addr.id}
              onClick={() => onAddressSelect(addr.id)}
              className={cn(
                'flex w-full items-start gap-3 rounded-2xl border-2 px-4 py-3 text-left transition-colors',
                selectedAddressId === addr.id
                  ? 'border-pink-400 bg-pink-50'
                  : 'border-pink-100 hover:border-pink-300',
              )}
            >
              <MapPin className="mt-0.5 h-4 w-4 shrink-0 text-berry-500" />
              <span>
                <span className="block font-semibold text-ink dark:text-cream">{addr.label}</span>
                <span className="block text-sm text-ink-muted">
                  {addr.street}
                  {addr.apartment ? `, ${addr.apartment}` : ''}, {addr.city}
                </span>
              </span>
            </button>
          ))}
          <Input placeholder="Или введите новый адрес" />
        </div>
      ) : (
        <div className="space-y-2">
          {PICKUP_POINTS.map((point) => (
            <button
              key={point.id}
              onClick={() => onPickupPointChange(point.id)}
              className={cn(
                'flex w-full items-start gap-3 rounded-2xl border-2 px-4 py-3 text-left transition-colors',
                pickupPointId === point.id
                  ? 'border-pink-400 bg-pink-50'
                  : 'border-pink-100 hover:border-pink-300',
              )}
            >
              <Store className="mt-0.5 h-4 w-4 shrink-0 text-berry-500" />
              <span>
                <span className="block font-semibold text-ink dark:text-cream">{point.name}</span>
                <span className="block text-sm text-ink-muted">{point.address}</span>
              </span>
            </button>
          ))}
        </div>
      )}

      <Textarea
        label="Комментарий к заказу"
        placeholder="Например: код домофона, не звонить в дверь…"
        rows={3}
        value={comment}
        onChange={(e) => onCommentChange(e.target.value)}
      />
    </div>
  );
}
