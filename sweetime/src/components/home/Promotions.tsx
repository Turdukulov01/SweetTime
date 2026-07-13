'use client';

import { motion } from 'framer-motion';
import { Gift, Percent, Truck } from 'lucide-react';

const PROMOS = [
  {
    icon: Percent,
    title: '−15% на первый заказ',
    text: 'Промокод WELCOME150 на приложение первого заказа от 600 ₽',
    tone: 'bg-pink-200 text-berry-600',
  },
  {
    icon: Truck,
    title: 'Бесплатная доставка',
    text: 'При заказе от 1500 ₽ привезём совершенно бесплатно',
    tone: 'bg-mint-200 text-mint-600',
  },
  {
    icon: Gift,
    title: 'Бонусы за каждый заказ',
    text: 'Копите 5% от суммы заказа и оплачивайте ими до 30% следующего',
    tone: 'bg-caramel-100 text-caramel-600',
  },
];

export function Promotions() {
  return (
    <section className="container-sweetime py-14">
      <div className="grid gap-4 sm:grid-cols-3">
        {PROMOS.map((promo, i) => (
          <motion.div
            key={promo.title}
            initial={{ opacity: 0, y: 16 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ delay: i * 0.08 }}
            className="flex items-start gap-4 rounded-3xl border border-pink-100/70 bg-white p-5 shadow-soft dark:border-berry-300/20 dark:bg-berry-700/40"
          >
            <span className={`flex h-11 w-11 shrink-0 items-center justify-center rounded-blob ${promo.tone}`}>
              <promo.icon className="h-5 w-5" />
            </span>
            <div>
              <h3 className="font-body font-semibold text-ink dark:text-cream">{promo.title}</h3>
              <p className="mt-1 text-sm text-ink-muted">{promo.text}</p>
            </div>
          </motion.div>
        ))}
      </div>
    </section>
  );
}
