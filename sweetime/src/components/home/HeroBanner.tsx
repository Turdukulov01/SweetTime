'use client';

import Link from 'next/link';
import Image from 'next/image';
import { motion } from 'framer-motion';
import { Button } from '@/components/ui/Button';

const FLOATING_PEARLS = [
  { size: 18, left: '8%', delay: 0 },
  { size: 12, left: '22%', delay: 0.6 },
  { size: 22, left: '78%', delay: 0.3 },
  { size: 14, left: '90%', delay: 1.1 },
  { size: 16, left: '55%', delay: 0.9 },
];

export function HeroBanner() {
  return (
    <section className="relative overflow-hidden bg-gradient-to-b from-pink-100 via-cream to-cream">
      {FLOATING_PEARLS.map((pearl, i) => (
        <motion.span
          key={i}
          className="pointer-events-none absolute top-0 rounded-full bg-berry-500/70"
          style={{ width: pearl.size, height: pearl.size, left: pearl.left }}
          animate={{ y: ['0%', '520%'], opacity: [0, 0.7, 0] }}
          transition={{ duration: 6, delay: pearl.delay, repeat: Infinity, ease: 'easeIn' }}
        />
      ))}

      <div className="container-sweetime relative grid gap-10 py-16 lg:grid-cols-2 lg:items-center lg:py-24">
        <motion.div
          initial={{ opacity: 0, y: 24 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6 }}
        >
          <span className="inline-flex items-center gap-2 rounded-pearl bg-white/70 px-4 py-1.5 text-sm font-medium text-berry-500 shadow-soft">
            🧋 Свежая заварка каждый час
          </span>
          <h1 className="mt-5 font-display text-4xl font-semibold leading-[1.1] text-berry-500 sm:text-5xl lg:text-6xl">
            Пузырьки радости
            <br />
            в каждом глотке
          </h1>
          <p className="mt-5 max-w-md font-body text-lg text-ink-muted">
            Sweetime — авторский бабл-ти и кофе на пастельном пироге радости.
            Собери свой напиток: размер, лёд, сахар и топпинги — как захочешь.
          </p>
          <div className="mt-8 flex flex-wrap gap-3">
            <Link href="/catalog">
              <Button size="lg">Смотреть меню</Button>
            </Link>
            <Link href="/catalog?tag=new">
              <Button size="lg" variant="outline">
                Новинки сезона
              </Button>
            </Link>
          </div>
        </motion.div>

        <motion.div
          initial={{ opacity: 0, scale: 0.92 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ duration: 0.7, delay: 0.15 }}
          className="relative mx-auto aspect-square w-full max-w-md"
        >
          <div className="absolute inset-6 rounded-blob bg-pink-300/50 blur-2xl" />
          <div className="relative h-full w-full overflow-hidden rounded-blob border-4 border-white shadow-lifted">
            <Image
              src="https://images.unsplash.com/photo-1558857563-b371033873b8?q=80&w=1200&auto=format&fit=crop"
              alt="Sweetime bubble tea"
              fill
              priority
              sizes="(min-width: 1024px) 480px, 90vw"
              className="object-cover"
            />
          </div>
        </motion.div>
      </div>
    </section>
  );
}
