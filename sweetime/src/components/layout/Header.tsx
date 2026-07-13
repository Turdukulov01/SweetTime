'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useRef, useState } from 'react';
import { motion } from 'framer-motion';
import { Menu, Search, ShoppingBag, User as UserIcon } from 'lucide-react';
import { NAV_LINKS, SITE } from '@/lib/constants';
import { useCart } from '@/context/CartContext';
import { useAuth } from '@/context/AuthContext';
import { useClickOutside } from '@/hooks/useClickOutside';
import { MobileMenu } from '@/components/layout/MobileMenu';
import { CartDrawer } from '@/components/cart/CartDrawer';

export function Header() {
  const router = useRouter();
  const { itemCount } = useCart();
  const { user } = useAuth();
  const [searchOpen, setSearchOpen] = useState(false);
  const [searchValue, setSearchValue] = useState('');
  const [mobileOpen, setMobileOpen] = useState(false);
  const [cartOpen, setCartOpen] = useState(false);
  const searchRef = useRef<HTMLFormElement>(null);

  useClickOutside(searchRef, () => setSearchOpen(false));

  function handleSearchSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (searchValue.trim()) {
      router.push(`/catalog?search=${encodeURIComponent(searchValue.trim())}`);
      setSearchOpen(false);
    }
  }

  return (
    <>
      <header className="sticky top-0 z-40 border-b border-pink-100/70 bg-cream/90 backdrop-blur-md dark:bg-berry-700/90">
        <div className="container-sweetime flex h-18 items-center justify-between gap-4 py-3">
          <Link href="/" className="flex shrink-0 items-center gap-2 group">
            <span className="relative flex h-9 w-9 items-center justify-center rounded-blob bg-pink-300 text-lg transition-transform group-hover:animate-wobble">
              🧋
            </span>
            <span className="font-display text-2xl font-semibold text-berry-500 dark:text-cream">
              {SITE.name}
            </span>
          </Link>

          <nav className="hidden items-center gap-1 lg:flex">
            {NAV_LINKS.map((link) => (
              <Link
                key={link.href}
                href={link.href}
                className="rounded-pearl px-4 py-2 font-medium text-ink transition-colors hover:bg-pink-100/70 hover:text-berry-500 dark:text-cream dark:hover:bg-berry-300/10"
              >
                {link.label}
              </Link>
            ))}
          </nav>

          <div className="flex flex-1 items-center justify-end gap-1.5 sm:gap-2">
            <form
              ref={searchRef}
              onSubmit={handleSearchSubmit}
              className="relative hidden items-center sm:flex"
            >
              <motion.div
                initial={false}
                animate={{ width: searchOpen ? 240 : 0, opacity: searchOpen ? 1 : 0 }}
                transition={{ type: 'spring', stiffness: 300, damping: 30 }}
                className="overflow-hidden"
              >
                <input
                  value={searchValue}
                  onChange={(e) => setSearchValue(e.target.value)}
                  placeholder="Найти напиток…"
                  className="w-full rounded-pearl border-2 border-pink-200 bg-white px-4 py-2 text-sm focus:border-pink-400 focus:outline-none dark:bg-berry-700/60 dark:text-cream"
                />
              </motion.div>
              <button
                type={searchOpen ? 'submit' : 'button'}
                onClick={() => !searchOpen && setSearchOpen(true)}
                aria-label="Поиск"
                className="flex h-10 w-10 shrink-0 items-center justify-center rounded-pearl text-berry-500 hover:bg-pink-100/70 dark:text-cream dark:hover:bg-berry-300/10"
              >
                <Search className="h-5 w-5" />
              </button>
            </form>

            <Link
              href="/auth/login"
              className="hidden h-10 w-10 items-center justify-center rounded-pearl text-berry-500 hover:bg-pink-100/70 sm:flex dark:text-cream dark:hover:bg-berry-300/10"
              aria-label={user ? 'Профиль' : 'Войти'}
            >
              {user ? (
                <span className="flex h-7 w-7 items-center justify-center rounded-full bg-mint-300 text-xs font-semibold text-berry-600">
                  {user.name.charAt(0)}
                </span>
              ) : (
                <UserIcon className="h-5 w-5" />
              )}
            </Link>

            <button
              onClick={() => setCartOpen(true)}
              aria-label="Корзина"
              className="relative flex h-10 w-10 items-center justify-center rounded-pearl text-berry-500 hover:bg-pink-100/70 dark:text-cream dark:hover:bg-berry-300/10"
            >
              <ShoppingBag className="h-5 w-5" />
              {itemCount > 0 && (
                <motion.span
                  key={itemCount}
                  initial={{ scale: 0.5 }}
                  animate={{ scale: 1 }}
                  className="absolute -right-0.5 -top-0.5 flex h-5 w-5 items-center justify-center rounded-full bg-berry-500 text-[11px] font-bold text-cream"
                >
                  {itemCount}
                </motion.span>
              )}
            </button>

            <button
              onClick={() => setMobileOpen(true)}
              aria-label="Меню"
              className="flex h-10 w-10 items-center justify-center rounded-pearl text-berry-500 hover:bg-pink-100/70 lg:hidden dark:text-cream dark:hover:bg-berry-300/10"
            >
              <Menu className="h-6 w-6" />
            </button>
          </div>
        </div>
      </header>

      <MobileMenu open={mobileOpen} onClose={() => setMobileOpen(false)} />
      <CartDrawer open={cartOpen} onClose={() => setCartOpen(false)} />
    </>
  );
}
