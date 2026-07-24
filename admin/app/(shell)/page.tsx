"use client";

// Дашборд владельца/менеджера: оперативные показатели и demo-аналитика.
// Клиенты в demo-контракте идентифицируются по customerName; для production
// потребуется стабильный customerId, paymentStatus и paidAt.

import { useEffect, useRef, useState, type ReactNode } from "react";
import {
  CircleDollarSign,
  CreditCard,
  ReceiptText,
  ShoppingBag,
  Sparkles,
  UserPlus,
  UserRoundX,
  Users,
  X,
  type LucideIcon
} from "lucide-react";
import { RoleGate } from "@/components/role-gate";
import { StatusBadge } from "@/components/status-badge";
import { useCompanyStore } from "@/lib/company-store";
import { ORDER_TYPE_LABELS } from "@/lib/labels";
import { useOrders } from "@/lib/orders-store";
import type { Order, PaymentMethod } from "@/lib/types";
import { formatCurrency, formatDateTime, isToday } from "@/lib/utils";

const DAY_MS = 24 * 60 * 60 * 1000;

type DetailKey =
  | "orders"
  | "revenue"
  | "average"
  | "payments"
  | "popular"
  | "newCustomers"
  | "dormant"
  | "buyers";

type PaymentBucket = PaymentMethod | "unknown";

interface PeriodDefinition {
  key: "day" | "week" | "month";
  label: string;
  cutoff: number;
}

interface ProductCount {
  name: string;
  count: number;
}

interface CustomerHistory {
  name: string;
  firstAt: number;
  lastAt: number;
  orderCount: number;
}

const PAYMENT_LABELS: Record<PaymentBucket, string> = {
  mock: "Демо-оплата",
  cash: "Наличные",
  qr: "QR",
  unknown: "Не указано"
};

function startOfToday(now: number): number {
  const date = new Date(now);
  date.setHours(0, 0, 0, 0);
  return date.getTime();
}

function normalizeProductName(name: string): string {
  return name.replace(/\s*\([^)]*\)/g, "").trim();
}

function countProducts(orders: Order[]): ProductCount[] {
  const counts = new Map<string, number>();
  orders.forEach((order) => {
    order.items.forEach((item) => {
      const name = normalizeProductName(item.name);
      counts.set(name, (counts.get(name) ?? 0) + item.quantity);
    });
  });
  return [...counts.entries()]
    .map(([name, count]) => ({ name, count }))
    .sort((a, b) => b.count - a.count || a.name.localeCompare(b.name, "ru"));
}

function buildCustomerHistory(orders: Order[]): CustomerHistory[] {
  const history = new Map<string, CustomerHistory>();
  orders.forEach((order) => {
    const key = order.customerName.trim().toLocaleLowerCase("ru");
    if (!key) return;
    const timestamp = new Date(order.createdAt).getTime();
    const current = history.get(key);
    if (!current) {
      history.set(key, {
        name: order.customerName.trim(),
        firstAt: timestamp,
        lastAt: timestamp,
        orderCount: 1
      });
      return;
    }
    current.firstAt = Math.min(current.firstAt, timestamp);
    current.lastAt = Math.max(current.lastAt, timestamp);
    current.orderCount += 1;
  });
  return [...history.values()];
}

function AnalyticsCard({
  label,
  value,
  hint,
  icon: Icon,
  onClick
}: {
  label: string;
  value: string;
  hint: string;
  icon: LucideIcon;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="surface focus-ring group min-h-32 px-5 py-4 text-left transition hover:-translate-y-0.5 hover:border-accent/40 hover:shadow-lg"
    >
      <span className="flex items-center justify-between gap-3">
        <span className="text-sm text-coffee-500">{label}</span>
        <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-accent/10 text-accent transition group-hover:bg-accent group-hover:text-white">
          <Icon className="h-4 w-4" />
        </span>
      </span>
      <span className="mt-2 block text-xl font-semibold text-coffee-900">
        {value}
      </span>
      <span className="mt-2 block text-xs text-coffee-500">{hint}</span>
    </button>
  );
}

function DetailSection({ title, children }: { title: string; children: ReactNode }) {
  return (
    <section>
      <h3 className="text-sm font-semibold text-coffee-900">{title}</h3>
      <div className="mt-2">{children}</div>
    </section>
  );
}

function EmptyDetail({ children }: { children: ReactNode }) {
  return (
    <p className="rounded-xl bg-cream-100 px-4 py-3 text-sm text-coffee-500 dark:bg-white/5">
      {children}
    </p>
  );
}

function AnalyticsDrawer({
  title,
  onClose,
  children
}: {
  title: string;
  onClose: () => void;
  children: ReactNode;
}) {
  const panelRef = useRef<HTMLElement>(null);
  const closeButtonRef = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    const previousFocus = document.activeElement as HTMLElement | null;
    closeButtonRef.current?.focus();

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        onClose();
        return;
      }
      if (event.key !== "Tab") return;

      const focusable = panelRef.current?.querySelectorAll<HTMLElement>(
        'button:not([disabled]), [href], input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])'
      );
      if (!focusable?.length) return;
      const first = focusable[0];
      const last = focusable[focusable.length - 1];
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      }
    };
    window.addEventListener("keydown", handleKeyDown);
    return () => {
      window.removeEventListener("keydown", handleKeyDown);
      previousFocus?.focus();
    };
  }, [onClose]);

  return (
    <div className="fixed inset-0 z-50 flex justify-end" role="presentation">
      <button
        type="button"
        aria-label="Закрыть детали аналитики"
        onClick={onClose}
        className="absolute inset-0 bg-coffee-900/35 backdrop-blur-sm"
      />
      <aside
        ref={panelRef}
        role="dialog"
        aria-modal="true"
        aria-labelledby="analytics-title"
        className="relative flex h-full w-full max-w-xl flex-col bg-cream-50 shadow-2xl dark:bg-[#171315]"
      >
        <header className="flex items-center justify-between border-b border-coffee-900/10 px-6 py-5">
          <div>
            <p className="text-xs font-semibold uppercase tracking-wider text-accent">
              Demo-аналитика
            </p>
            <h2 id="analytics-title" className="mt-1 text-xl">
              {title}
            </h2>
          </div>
          <button
            ref={closeButtonRef}
            type="button"
            onClick={onClose}
            aria-label="Закрыть"
            className="focus-ring flex h-10 w-10 items-center justify-center rounded-full text-coffee-500 transition hover:bg-coffee-900/5 hover:text-coffee-900"
          >
            <X className="h-5 w-5" />
          </button>
        </header>
        <div className="flex-1 space-y-6 overflow-y-auto px-6 py-5">{children}</div>
        <footer className="border-t border-coffee-900/10 px-6 py-4 text-xs text-coffee-500">
          Клиенты считаются по имени. Для точной production-аналитики нужен customerId.
        </footer>
      </aside>
    </div>
  );
}

function DashboardContent() {
  const { company, branches } = useCompanyStore();
  const { orders } = useOrders();
  const [selectedDetail, setSelectedDetail] = useState<DetailKey | null>(null);

  const now = Date.now();
  const periods: PeriodDefinition[] = [
    { key: "day", label: "Сегодня", cutoff: startOfToday(now) },
    { key: "week", label: "7 дней", cutoff: now - 7 * DAY_MS },
    { key: "month", label: "30 дней", cutoff: now - 30 * DAY_MS }
  ];
  // "scheduled" — план постоянных заказов, ещё не работа и не выручка:
  // в счётчики и аналитику не входит (как и отменённые).
  const validOrders = orders.filter(
    (order) => order.status !== "cancelled" && order.status !== "scheduled"
  );
  const ordersFor = (period: PeriodDefinition) =>
    validOrders.filter(
      (order) => new Date(order.createdAt).getTime() >= period.cutoff
    );
  const ordersByPeriod = periods.map((period) => ({
    ...period,
    orders: ordersFor(period)
  }));

  const todayOrders = validOrders.filter((order) => isToday(order.createdAt));
  const revenue = todayOrders.reduce((sum, order) => sum + order.total, 0);
  const averageCheck =
    todayOrders.length > 0 ? Math.round(revenue / todayOrders.length) : 0;
  const paymentByPeriod = ordersByPeriod.map((period) => {
    const methods = Object.fromEntries(
      (["mock", "cash", "qr", "unknown"] as PaymentBucket[]).map((method) => [
        method,
        { count: 0, total: 0 }
      ])
    ) as Record<PaymentBucket, { count: number; total: number }>;
    period.orders.forEach((order) => {
      const method = order.paymentMethod ?? "unknown";
      methods[method].count += 1;
      methods[method].total += order.total;
    });
    return { ...period, methods };
  });
  const prepaidToday =
    paymentByPeriod[0].methods.mock.count + paymentByPeriod[0].methods.qr.count;

  const popularByPeriod = ordersByPeriod.map((period) => ({
    ...period,
    products: countProducts(period.orders)
  }));
  const popularToday = popularByPeriod[0].products[0];

  const customerHistory = buildCustomerHistory(validOrders);
  const customerByPeriod = periods.map((period) => ({
    ...period,
    buyers: customerHistory.filter((customer) => customer.lastAt >= period.cutoff),
    newCustomers: customerHistory.filter(
      (customer) => customer.firstAt >= period.cutoff
    )
  }));
  const dormantCustomers = customerHistory
    .filter((customer) => customer.lastAt < now - 14 * DAY_MS)
    .sort((a, b) => a.lastAt - b.lastAt);

  const stats: Array<{
    key: DetailKey;
    label: string;
    value: string;
    hint: string;
    icon: LucideIcon;
  }> = [
    {
      key: "orders",
      label: "Заказы сегодня",
      value: String(todayOrders.length),
      hint: "Нажмите для состава и типов",
      icon: ShoppingBag
    },
    {
      key: "revenue",
      label: "Выручка сегодня",
      value: formatCurrency(revenue, company.currency),
      hint: "Сравнение за день, 7 и 30 дней",
      icon: CircleDollarSign
    },
    {
      key: "average",
      label: "Средний чек",
      value: formatCurrency(averageCheck, company.currency),
      hint: "Среднее по трём периодам",
      icon: ReceiptText
    },
    {
      key: "payments",
      label: "Оплачено сразу сегодня",
      value: `${prepaidToday} заказов`,
      hint: "QR, demo и наличные отдельно",
      icon: CreditCard
    },
    {
      key: "popular",
      label: "Популярный сегодня",
      value: popularToday?.name ?? "Нет данных",
      hint: popularToday ? `${popularToday.count} шт. · другие периоды внутри` : "Откройте детали",
      icon: Sparkles
    },
    {
      key: "newCustomers",
      label: "Новые клиенты · 30 дней",
      value: String(customerByPeriod[2].newCustomers.length),
      hint: "Первый заказ в выбранном периоде",
      icon: UserPlus
    },
    {
      key: "dormant",
      label: "Не заказывали 14+ дней",
      value: String(dormantCustomers.length),
      hint: "Клиенты для возвратной коммуникации",
      icon: UserRoundX
    },
    {
      key: "buyers",
      label: "Покупатели · 30 дней",
      value: String(customerByPeriod[2].buyers.length),
      hint: "Уникальные имена за день, 7 и 30 дней",
      icon: Users
    }
  ];

  const selectedTitle = stats.find((stat) => stat.key === selectedDetail)?.label;

  function renderDetail(): ReactNode {
    switch (selectedDetail) {
      case "orders":
        return (
          <>
            <DetailSection title="Типы заказов сегодня">
              <div className="grid grid-cols-3 gap-2">
                {(["pickup", "scheduled", "qr"] as const).map((type) => (
                  <div key={type} className="rounded-xl bg-cream-100 px-3 py-3 text-center dark:bg-white/5">
                    <p className="text-xl font-semibold text-coffee-900">
                      {todayOrders.filter((order) => order.type === type).length}
                    </p>
                    <p className="mt-1 text-xs text-coffee-500">{ORDER_TYPE_LABELS[type]}</p>
                  </div>
                ))}
              </div>
            </DetailSection>
            <DetailSection title="Заказы">
              {todayOrders.length === 0 ? (
                <EmptyDetail>Сегодня заказов ещё нет.</EmptyDetail>
              ) : (
                <div className="space-y-2">
                  {todayOrders.map((order) => (
                    <div key={order.id} className="flex items-center justify-between gap-3 rounded-xl border border-coffee-900/10 px-4 py-3 text-sm">
                      <div>
                        <p className="font-semibold text-coffee-900">{order.number} · {order.customerName}</p>
                        <p className="mt-1 text-xs text-coffee-500">{formatDateTime(order.createdAt)} · {ORDER_TYPE_LABELS[order.type]}</p>
                      </div>
                      <span className="font-semibold text-coffee-900">{formatCurrency(order.total, company.currency)}</span>
                    </div>
                  ))}
                </div>
              )}
            </DetailSection>
          </>
        );
      case "revenue":
      case "average":
        return (
          <DetailSection title={selectedDetail === "revenue" ? "Выручка по периодам" : "Средний чек по периодам"}>
            <div className="space-y-2">
              {ordersByPeriod.map((period) => {
                const total = period.orders.reduce((sum, order) => sum + order.total, 0);
                const value = selectedDetail === "revenue"
                  ? total
                  : period.orders.length > 0
                    ? Math.round(total / period.orders.length)
                    : 0;
                return (
                  <div key={period.key} className="flex items-center justify-between rounded-xl bg-cream-100 px-4 py-3 dark:bg-white/5">
                    <span className="text-sm text-coffee-700">{period.label} · {period.orders.length} заказов</span>
                    <span className="font-semibold text-coffee-900">{formatCurrency(value, company.currency)}</span>
                  </div>
                );
              })}
            </div>
          </DetailSection>
        );
      case "payments":
        return (
          <>
            {paymentByPeriod.map((period) => (
              <DetailSection key={period.key} title={period.label}>
                <div className="grid grid-cols-1 gap-2 sm:grid-cols-2">
                  {(["qr", "mock", "cash", "unknown"] as PaymentBucket[]).map((method) => (
                    <div key={method} className="rounded-xl bg-cream-100 px-4 py-3 dark:bg-white/5">
                      <p className="text-xs text-coffee-500">{PAYMENT_LABELS[method]}</p>
                      <p className="mt-1 font-semibold text-coffee-900">
                        {period.methods[method].count} · {formatCurrency(period.methods[method].total, company.currency)}
                      </p>
                    </div>
                  ))}
                </div>
              </DetailSection>
            ))}
            <EmptyDetail>
              В demo «оплачено сразу» = QR + mock. Наличные показаны отдельно; production потребует paymentStatus и paidAt.
            </EmptyDetail>
          </>
        );
      case "popular":
        return (
          <>
            {popularByPeriod.map((period) => (
              <DetailSection key={period.key} title={period.label}>
                {period.products.length === 0 ? (
                  <EmptyDetail>Нет продаж за период.</EmptyDetail>
                ) : (
                  <div className="space-y-2">
                    {period.products.slice(0, 5).map((product, index) => (
                      <div key={product.name} className="flex items-center gap-3 rounded-xl bg-cream-100 px-4 py-3 dark:bg-white/5">
                        <span className="flex h-7 w-7 items-center justify-center rounded-full bg-accent/10 text-xs font-bold text-accent">{index + 1}</span>
                        <span className="flex-1 text-sm text-coffee-700">{product.name}</span>
                        <span className="font-semibold text-coffee-900">{product.count} шт.</span>
                      </div>
                    ))}
                  </div>
                )}
              </DetailSection>
            ))}
          </>
        );
      case "newCustomers":
      case "buyers": {
        const field = selectedDetail === "newCustomers" ? "newCustomers" : "buyers";
        return (
          <>
            {customerByPeriod.map((period) => (
              <DetailSection key={period.key} title={`${period.label} · ${period[field].length}`}>
                {period[field].length === 0 ? (
                  <EmptyDetail>Нет клиентов за период.</EmptyDetail>
                ) : (
                  <div className="flex flex-wrap gap-2">
                    {period[field].map((customer) => (
                      <span key={`${period.key}-${customer.name}`} className="rounded-full bg-accent/10 px-3 py-1.5 text-sm font-medium text-accent">
                        {customer.name}
                      </span>
                    ))}
                  </div>
                )}
              </DetailSection>
            ))}
          </>
        );
      }
      case "dormant":
        return (
          <DetailSection title="Последний заказ более 14 дней назад">
            {dormantCustomers.length === 0 ? (
              <EmptyDetail>Таких клиентов в доступной истории нет.</EmptyDetail>
            ) : (
              <div className="space-y-2">
                {dormantCustomers.map((customer) => (
                  <div key={customer.name} className="flex items-center justify-between rounded-xl border border-coffee-900/10 px-4 py-3 text-sm">
                    <div>
                      <p className="font-semibold text-coffee-900">{customer.name}</p>
                      <p className="mt-1 text-xs text-coffee-500">Всего заказов: {customer.orderCount}</p>
                    </div>
                    <span className="text-xs text-coffee-500">{new Date(customer.lastAt).toLocaleDateString("ru-RU")}</span>
                  </div>
                ))}
              </div>
            )}
          </DetailSection>
        );
      default:
        return null;
    }
  }

  const branchName = (branchId: string) =>
    branches.find((branch) => branch.id === branchId)?.name ?? branchId;
  // Планы "scheduled" не показываем: сгенерированные утром постоянные заказы
  // вытеснили бы реальные из пяти последних строк.
  const recentOrders = orders
    .filter((order) => order.status !== "scheduled")
    .sort(
      (a, b) =>
        new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
    )
    .slice(0, 5);

  return (
    <div>
      <h1 className="text-2xl">Дашборд</h1>
      <p className="mt-1 text-sm text-coffee-500">
        Сводка по {company.name}. Нажмите на карточку, чтобы увидеть детали.
      </p>

      <div className="mt-6 grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-3">
        {stats.map((stat) => (
          <AnalyticsCard
            key={stat.key}
            label={stat.label}
            value={stat.value}
            hint={stat.hint}
            icon={stat.icon}
            onClick={() => setSelectedDetail(stat.key)}
          />
        ))}
      </div>

      <div className="surface mt-6 overflow-hidden">
        <div className="border-b border-coffee-900/10 px-5 py-4">
          <h2 className="text-base">Последние заказы</h2>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-coffee-900/10 text-left text-xs uppercase tracking-wide text-coffee-500">
                <th className="px-5 py-3 font-semibold">Номер</th>
                <th className="px-5 py-3 font-semibold">Время</th>
                <th className="px-5 py-3 font-semibold">Клиент</th>
                <th className="px-5 py-3 font-semibold">Филиал</th>
                <th className="px-5 py-3 font-semibold">Тип</th>
                <th className="px-5 py-3 font-semibold">Статус</th>
                <th className="px-5 py-3 text-right font-semibold">Сумма</th>
              </tr>
            </thead>
            <tbody>
              {recentOrders.map((order) => (
                <tr key={order.id} className="border-b border-coffee-900/5 last:border-0">
                  <td className="px-5 py-3 font-semibold text-coffee-900">{order.number}</td>
                  <td className="px-5 py-3 text-coffee-700">{formatDateTime(order.createdAt)}</td>
                  <td className="px-5 py-3 text-coffee-700">{order.customerName}</td>
                  <td className="px-5 py-3 text-coffee-700">{branchName(order.branchId)}</td>
                  <td className="px-5 py-3 text-coffee-700">{ORDER_TYPE_LABELS[order.type]}</td>
                  <td className="px-5 py-3"><StatusBadge status={order.status} /></td>
                  <td className="px-5 py-3 text-right font-semibold text-coffee-900">{formatCurrency(order.total, company.currency)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {selectedDetail && selectedTitle && (
        <AnalyticsDrawer title={selectedTitle} onClose={() => setSelectedDetail(null)}>
          {renderDetail()}
        </AnalyticsDrawer>
      )}
    </div>
  );
}

export default function DashboardPage() {
  return (
    <RoleGate allow={["owner", "manager"]}>
      <DashboardContent />
    </RoleGate>
  );
}
