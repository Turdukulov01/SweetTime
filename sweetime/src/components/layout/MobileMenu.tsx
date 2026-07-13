'use client';

import Link from 'next/link';
import { AnimatePresence, motion } from 'framer-motion';
import { LogIn, Search, X } from 'lucide-react';
import { NAV_LINKS, SITE } from '@/lib/constants';
import { useAuth } from '@/context/AuthContext';

export function MobileMenu({ open, onClose }: { open: boolean; onClose: () => void }) {
  const { user } = useAuth();

  return (
    <AnimatePresence>
      {open && (
        <>
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={onClose}
            className="fixed inset-0 z-50 bg-berry-700/40 backdrop-blur-sm lg:hidden"
          />
          <motion.div
            initial={{ x: '100%' }}
            animate={{ x: 0 }}
            exit={{ x: '100%' }}
            transition={{ type: 'spring', stiffness: 320, damping: 34 }}
            className="fixed inset-y-0 right-0 z-50 flex w-[85%] max-w-sm flex-col bg-cream p-6 shadow-lifted lg:hidden dark:bg-berry-600"
          >
            <div className="mb-6 flex items-center justify-between">
              <span className="font-display text-xl font-semibold text-berry-500 dark:text-cream">
                {SITE.name}
              </span>
              <button
                onClick={onClose}
                aria-label="Закрыть меню"
                className="flex h-9 w-9 items-center justify-center rounded-pearl hover:bg-pink-100/70 dark:hover:bg-berry-300/10"
              >
                <X className="h-5 w-5" />
              </button>
            </div>

            <form
              action="/catalog"
              className="mb-6 flex items-center gap-2 rounded-pearl border-2 border-pink-200 bg-white px-4 py-2.5 dark:bg-berry-700/60"
            >
              <Search className="h-4 w-4 text-ink-muted" />
              <input
                name="search"
                placeholder="Найти напиток…"
                className="w-full bg-transparent text-sm focus:outline-none dark:text-cream"
              />
            </form>

            <nav className="flex flex-col gap-1">
              {NAV_LINKS.map((link) => (
                <Link
                  key={link.href}
                  href={link.href}
                  onClick={onClose}
                  className="rounded-2xl px-4 py-3 text-lg font-medium text-ink hover:bg-pink-100/70 dark:text-cream dark:hover:bg-berry-300/10"
                >
                  {link.label}
                </Link>
              ))}
            </nav>

            <div className="mt-auto border-t border-pink-100 pt-4 dark:border-berry-300/20">
              <Link
                href={user ? '/profile' : '/auth/login'}
                onClick={onClose}
                className="flex items-center gap-2 rounded-2xl px-4 py-3 font-medium text-berry-500 hover:bg-pink-100/70 dark:text-cream dark:hover:bg-berry-300/10"
              >
                <LogIn className="h-5 w-5" />
                {user ? user.name : 'Войти в аккаунт'}
              </Link>
            </div>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}
