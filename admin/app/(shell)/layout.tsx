"use client";

// Shell авторизованной части: sidebar по ролям + topbar с компанией и выходом.
// Брендинг (акцент --accent, имя приложения) читается из company-store,
// поэтому изменения на странице «Настройки» применяются к админке мгновенно.

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useEffect, type CSSProperties, type ReactNode } from "react";
import {
  ClipboardList,
  CupSoda,
  LayoutDashboard,
  LogOut,
  MapPin,
  Settings,
  Store,
  Users
} from "lucide-react";
import { ThemeToggle } from "@/components/theme-toggle";
import { useApiStatus } from "@/lib/api";
import { CompanyStoreProvider, useCompanyStore } from "@/lib/company-store";
import { ROLE_LABELS } from "@/lib/labels";
import { OrdersProvider } from "@/lib/orders-store";
import { logout, useSession } from "@/lib/session";
import type { AdminUser, Role } from "@/lib/types";
import { cn, hexToRgbTriplet } from "@/lib/utils";

const NAV_ITEMS: Array<{
  href: string;
  label: string;
  icon: typeof LayoutDashboard;
  roles: Role[];
}> = [
  {
    href: "/",
    label: "Дашборд",
    icon: LayoutDashboard,
    roles: ["owner", "manager"]
  },
  {
    href: "/orders",
    label: "Заказы",
    icon: ClipboardList,
    roles: ["owner", "manager", "barista"]
  },
  { href: "/menu", label: "Меню", icon: CupSoda, roles: ["owner", "manager"] },
  {
    href: "/branches",
    label: "Филиалы",
    icon: MapPin,
    roles: ["owner", "manager"]
  },
  { href: "/staff", label: "Сотрудники", icon: Users, roles: ["owner"] },
  { href: "/settings", label: "Настройки", icon: Settings, roles: ["owner"] }
];

function ShellFrame({
  user,
  children
}: {
  user: AdminUser;
  children: ReactNode;
}) {
  const router = useRouter();
  const pathname = usePathname();
  const { company } = useCompanyStore();
  const apiStatus = useApiStatus();

  const navItems = NAV_ITEMS.filter((item) => item.roles.includes(user.role));

  function handleLogout() {
    logout();
    router.replace("/login");
  }

  return (
    <div
      style={
        { "--accent": hexToRgbTriplet(company.accentColor) } as CSSProperties
      }
      className="flex min-h-screen"
    >
      {/* Sidebar */}
      <aside className="flex w-56 shrink-0 flex-col border-r border-coffee-900/10 bg-white/70 px-3 py-5 dark:bg-white/5">
        <div className="mb-6 flex items-center gap-2.5 px-2">
          <span className="flex h-9 w-9 items-center justify-center rounded-xl bg-accent text-white">
            <Store className="h-5 w-5" />
          </span>
          <div className="min-w-0">
            <p className="truncate text-sm font-semibold text-coffee-900">
              {company.appName}
            </p>
            <p className="text-xs text-coffee-500">Админ-панель</p>
          </div>
        </div>

        <nav className="flex flex-1 flex-col gap-1">
          {navItems.map((item) => {
            const active =
              item.href === "/"
                ? pathname === "/"
                : pathname.startsWith(item.href);
            const Icon = item.icon;
            return (
              <Link
                key={item.href}
                href={item.href}
                className={cn(
                  "focus-ring flex h-11 items-center gap-3 rounded-xl px-3 text-sm font-medium transition",
                  active
                    ? "bg-accent/10 text-accent"
                    : "text-coffee-700 hover:bg-coffee-900/5"
                )}
              >
                <Icon className="h-[18px] w-[18px]" />
                {item.label}
              </Link>
            );
          })}
        </nav>

        <p className="px-2 pt-4 text-[11px] leading-snug text-coffee-500/70">
          SweetTime Platform · демо-режим
        </p>
      </aside>

      {/* Контент */}
      <div className="flex min-w-0 flex-1 flex-col">
        <header className="flex h-16 items-center justify-between gap-4 border-b border-coffee-900/10 bg-white/70 px-6 dark:bg-white/5">
          <div className="flex items-center gap-3">
            <span
              className="h-2.5 w-2.5 rounded-full bg-accent"
              aria-hidden="true"
            />
            <span className="text-sm font-semibold text-coffee-900">
              {company.name}
            </span>
            <span
              title={
                apiStatus === "live"
                  ? "Данные из API (NEXT_PUBLIC_API_URL)"
                  : "Мок-данные: API не задан или недоступен"
              }
              className="flex items-center gap-1.5 rounded-full border border-coffee-900/10 px-2.5 py-0.5 text-[11px] font-semibold text-coffee-500"
            >
              <span
                className={cn(
                  "h-2 w-2 rounded-full",
                  apiStatus === "live"
                    ? "bg-emerald-500"
                    : "bg-coffee-500/40 dark:bg-white/30"
                )}
                aria-hidden="true"
              />
              API
            </span>
          </div>

          <div className="flex items-center gap-4">
            <ThemeToggle />
            <div className="text-right">
              <p className="text-sm font-medium text-coffee-900">
                {user.email}
              </p>
              <p className="text-xs text-coffee-500">
                {ROLE_LABELS[user.role]}
              </p>
            </div>
            <button
              type="button"
              onClick={handleLogout}
              className="focus-ring flex h-9 items-center gap-2 rounded-full border border-coffee-900/15 px-4 text-sm font-medium text-coffee-700 transition hover:border-accent hover:text-accent"
            >
              <LogOut className="h-4 w-4" />
              Выйти
            </button>
          </div>
        </header>

        <main className="flex-1 px-6 py-6">{children}</main>
      </div>
    </div>
  );
}

export default function ShellLayout({ children }: { children: ReactNode }) {
  const router = useRouter();
  const { status, user, company } = useSession();

  // Guard: неавторизованных — на страницу входа
  useEffect(() => {
    if (status === "unauthenticated") router.replace("/login");
  }, [status, router]);

  if (status !== "authenticated" || !user || !company) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <p className="text-sm text-coffee-500">Загрузка…</p>
      </div>
    );
  }

  return (
    <CompanyStoreProvider key={company.id} companyId={company.id}>
      <OrdersProvider key={company.id} companyId={company.id}>
        <ShellFrame user={user}>{children}</ShellFrame>
      </OrdersProvider>
    </CompanyStoreProvider>
  );
}
