'use client';

import { useState } from 'react';
import Image from 'next/image';
import { motion } from 'framer-motion';
import { cn } from '@/lib/utils';

export function Gallery({ images, name }: { images: string[]; name: string }) {
  const [active, setActive] = useState(0);

  return (
    <div>
      <div className="relative aspect-square overflow-hidden rounded-3xl bg-pink-50 shadow-soft">
        <motion.div
          key={active}
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ duration: 0.3 }}
          className="absolute inset-0"
        >
          <Image
            src={images[active] ?? images[0]}
            alt={name}
            fill
            priority
            sizes="(min-width: 1024px) 480px, 90vw"
            className="object-cover"
          />
        </motion.div>
      </div>
      {images.length > 1 && (
        <div className="mt-4 flex gap-3">
          {images.map((src, i) => (
            <button
              key={src}
              onClick={() => setActive(i)}
              className={cn(
                'relative h-16 w-16 shrink-0 overflow-hidden rounded-2xl border-2 transition-colors',
                active === i ? 'border-pink-400' : 'border-transparent',
              )}
            >
              <Image src={src} alt={`${name} ${i + 1}`} fill sizes="64px" className="object-cover" />
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
