'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import {
  BarChart3,
  LayoutDashboard,
  ListTree,
  Megaphone,
  Package,
  ShoppingCart,
  Tag,
  Users,
} from 'lucide-react';
import { cn } from '@/lib/utils';

const LINKS = [
  { href: '/admin', label: 'Dashboard', icon: LayoutDashboard, exact: true },
  { href: '/admin/products', label: 'Товары', icon: Package },
  { href: '/admin/categories', label: 'Категории', icon: ListTree },
  { href: '/admin/orders', label: 'Заказы', icon: ShoppingCart },
  { href: '/admin/users', label: 'Пользователи', icon: Users },
  { href: '/admin/coupons', label: 'Купоны', icon: Tag },
  { href: '/admin/promotions', label: 'Акции', icon: Megaphone },
  { href: '/admin/analytics', label: 'Аналитика', icon: BarChart3 },
];

export function AdminSidebar() {
  const pathname = usePathname();

  return (
    <nav className="flex gap-1 overflow-x-auto pb-4 lg:w-56 lg:shrink-0 lg:flex-col lg:overflow-visible lg:pb-0">
      {LINKS.map((link) => {
        const active = link.exact ? pathname === link.href : pathname.startsWith(link.href);
        return (
          <Link
            key={link.href}
            href={link.href}
            className={cn(
              'flex shrink-0 items-center gap-2.5 rounded-2xl px-4 py-2.5 text-sm font-medium transition-colors',
              active ? 'bg-berry-500 text-cream' : 'text-ink hover:bg-pink-100/70 dark:text-cream',
            )}
          >
            <link.icon className="h-4 w-4" /> {link.label}
          </Link>
        );
      })}
    </nav>
  );
}
