'use client';

import Image from 'next/image';
import Link from 'next/link';
import { motion } from 'framer-motion';
import { Star } from 'lucide-react';
import type { Product } from '@/types';
import { Badge, TAG_LABELS } from '@/components/ui/Badge';
import { formatPrice } from '@/lib/utils';

export function ProductCard({ product, index = 0 }: { product: Product; index?: number }) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 16 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, margin: '-40px' }}
      transition={{ duration: 0.4, delay: Math.min(index, 6) * 0.05 }}
    >
      <Link
        href={`/product/${product.slug}`}
        className="group flex h-full flex-col overflow-hidden rounded-3xl border border-pink-100/70 bg-white shadow-soft transition-shadow hover:shadow-lifted dark:border-berry-300/20 dark:bg-berry-700/40"
      >
        <div className="relative aspect-square overflow-hidden bg-pink-50">
          <Image
            src={product.images[0]}
            alt={product.name}
            fill
            sizes="(min-width: 1024px) 25vw, (min-width: 640px) 33vw, 50vw"
            className="object-cover transition-transform duration-500 group-hover:scale-105"
          />
          {product.tags.length > 0 && (
            <div className="absolute left-3 top-3 flex flex-col gap-1.5">
              {product.tags.slice(0, 2).map((tag) => (
                <Badge key={tag} tone={TAG_LABELS[tag].tone}>
                  {TAG_LABELS[tag].label}
                </Badge>
              ))}
            </div>
          )}
        </div>
        <div className="flex flex-1 flex-col gap-2 p-4">
          <h3 className="font-body font-semibold leading-snug text-ink dark:text-cream">
            {product.name}
          </h3>
          <div className="flex items-center gap-1 text-xs text-ink-muted">
            <Star className="h-3.5 w-3.5 fill-caramel-500 text-caramel-500" />
            <span className="font-medium text-ink">{product.rating}</span>
            <span>({product.reviewsCount})</span>
          </div>
          <div className="mt-auto flex items-center gap-2 pt-2">
            <span className="font-mono text-lg font-semibold text-berry-500 dark:text-cream">
              {formatPrice(product.price)}
            </span>
            {product.oldPrice && (
              <span className="font-mono text-sm text-ink-muted line-through">
                {formatPrice(product.oldPrice)}
              </span>
            )}
          </div>
        </div>
      </Link>
    </motion.div>
  );
}
