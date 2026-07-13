'use client';

import Link from 'next/link';
import { motion } from 'framer-motion';
import { CATEGORIES } from '@/lib/mock-data';

const TONE_BG: Record<string, string> = {
  pink: 'bg-pink-200',
  mint: 'bg-mint-200',
  caramel: 'bg-caramel-100',
};

export function Categories() {
  return (
    <section className="container-sweetime py-8">
      <h2 className="section-heading mb-6">Категории</h2>
      <div className="flex gap-4 overflow-x-auto pb-2 sm:grid sm:grid-cols-3 sm:overflow-visible lg:grid-cols-6">
        {CATEGORIES.map((cat, i) => (
          <motion.div
            key={cat.id}
            initial={{ opacity: 0, y: 12 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ delay: i * 0.05 }}
          >
            <Link
              href={`/catalog?category=${cat.slug}`}
              className="flex w-24 shrink-0 flex-col items-center gap-2 sm:w-auto"
            >
              <span
                className={`flex h-16 w-16 items-center justify-center rounded-blob text-2xl transition-transform hover:scale-105 ${TONE_BG[cat.color]}`}
              >
                {cat.emoji}
              </span>
              <span className="text-center text-sm font-medium text-ink dark:text-cream">
                {cat.name}
              </span>
            </Link>
          </motion.div>
        ))}
      </div>
    </section>
  );
}
