"use client";

// Дашборд владельца/менеджера: оперативные показатели и demo-аналитика.
// Клиенты в demo-контракте идентифицируются по customerName; для production
// потребуется стабильный customerId, paymentStatus и paidAt.

import { useEffect, useRef, useState, type ReactNode } from "react";
import {
  CircleDollarSign,
  CreditCard,
  Package2,
  ReceiptText,
  RefreshCw,
  Repeat2,
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
import {
  apiCompleteManualRecurringRefund,
  apiFetchRecurringAnalytics,
  describeApiError
} from "@/lib/api";
import { useCompanyStore } from "@/lib/company-store";
import { ORDER_STATUS_LABELS, ORDER_TYPE_LABELS } from "@/lib/labels";
import { useOrders } from "@/lib/orders-store";
import type {
  LocalizedText,
  Order,
  PaymentMethod,
  RecurringOrderAnalytics,
  RecurringPlan,
  RecurringRefundStatus
} from "@/lib/types";
import {
  formatCurrency,
  formatDate,
  formatDateTime,
  isToday
} from "@/lib/utils";

const DAY_MS = 24 * 60 * 60 * 1000;
const RECURRING_REFRESH_MS = 30_000;

type DetailKey =
  | "orders"
  | "recurring"
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

const RECURRING_PLAN_LABELS: Record<RecurringPlan, string> = {
  single: "Один день",
  week: "Неделя",
  month: "Месяц",
  custom: "Свой срок"
};

const REFUND_STATUS_LABELS: Record<RecurringRefundStatus, string> = {
  pending: "Ожидает отправки",
  processing: "Обрабатывается",
  refunded: "Возвращено автоматически",
  manual_required: "Нужна ручная выдача",
  manual_paid: "Выдано вручную",
  failed: "Нужна проверка"
};

function localizedLabel(
  value: string | LocalizedText | null | undefined,
  fallback = "Без названия"
): string {
  if (typeof value === "string") return value.trim() || fallback;
  return (
    value?.ru?.trim() ||
    value?.ky?.trim() ||
    value?.en?.trim() ||
    fallback
  );
}

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
  children,
  wide = false,
  eyebrow = "Demo-аналитика",
  footer
}: {
  title: string;
  onClose: () => void;
  children: ReactNode;
  wide?: boolean;
  eyebrow?: string;
  footer?: ReactNode;
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
        className={`relative flex h-full w-full flex-col bg-cream-50 shadow-2xl dark:bg-[#171315] ${
          wide ? "max-w-6xl" : "max-w-xl"
        }`}
      >
        <header className="flex items-center justify-between border-b border-coffee-900/10 px-6 py-5">
          <div>
            <p className="text-xs font-semibold uppercase tracking-wider text-accent">
              {eyebrow}
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
          {footer ??
            "Клиенты считаются по имени. Для точной production-аналитики нужен customerId."}
        </footer>
      </aside>
    </div>
  );
}

function DashboardContent() {
  const { company, branches } = useCompanyStore();
  const { orders } = useOrders();
  const [selectedDetail, setSelectedDetail] = useState<DetailKey | null>(null);
  const [recurringAnalytics, setRecurringAnalytics] =
    useState<RecurringOrderAnalytics | null>(null);
  const [recurringLoading, setRecurringLoading] = useState(true);
  const [recurringError, setRecurringError] = useState<string | null>(null);
  const [recurringRefreshKey, setRecurringRefreshKey] = useState(0);
  const [manualRefundClaim, setManualRefundClaim] = useState("");
  const [manualRefundPending, setManualRefundPending] = useState(false);
  const [manualRefundMessage, setManualRefundMessage] = useState<string | null>(
    null
  );
  const [manualRefundError, setManualRefundError] = useState<string | null>(
    null
  );
  const manualRefundKeyRef = useRef<{
    claim: string;
    key: string;
  } | null>(null);

  const completeManualRefund = async () => {
    const claim = manualRefundClaim.trim();
    if (!claim || manualRefundPending) return;
    const previous = manualRefundKeyRef.current;
    const key =
      previous?.claim === claim
        ? previous.key
        : `admin-manual-refund:${crypto.randomUUID()}`;
    manualRefundKeyRef.current = { claim, key };
    setManualRefundPending(true);
    setManualRefundMessage(null);
    setManualRefundError(null);
    try {
      const refund = await apiCompleteManualRecurringRefund(
        company.id,
        claim,
        key
      );
      setManualRefundMessage(
        `Возврат ${formatCurrency(
          refund.amount,
          refund.currency
        )} отмечен как выданный.`
      );
      setManualRefundClaim("");
      manualRefundKeyRef.current = null;
      setRecurringRefreshKey((value) => value + 1);
    } catch (error) {
      // Keep the same idempotency key. If the response was lost after a
      // successful payout confirmation, Retry receives the original result.
      setManualRefundError(describeApiError(error));
    } finally {
      setManualRefundPending(false);
    }
  };

  useEffect(() => {
    let disposed = false;
    let inFlight = false;
    let refreshTimer: ReturnType<typeof setTimeout> | undefined;

    setRecurringAnalytics(null);
    setRecurringError(null);
    setRecurringLoading(true);

    const scheduleRefresh = () => {
      if (refreshTimer) clearTimeout(refreshTimer);
      refreshTimer = setTimeout(() => {
        void load(false);
      }, RECURRING_REFRESH_MS);
    };

    const load = async (initial: boolean) => {
      if (disposed || inFlight) return;
      inFlight = true;
      if (initial) setRecurringLoading(true);
      try {
        const next = await apiFetchRecurringAnalytics(company.id);
        if (disposed) return;
        setRecurringAnalytics(next);
        setRecurringError(null);
      } catch (error) {
        if (!disposed) setRecurringError(describeApiError(error));
      } finally {
        inFlight = false;
        if (!disposed) {
          setRecurringLoading(false);
          scheduleRefresh();
        }
      }
    };

    const refreshWhenActive = () => {
      if (document.visibilityState === "visible") void load(false);
    };

    void load(true);
    window.addEventListener("focus", refreshWhenActive);
    window.addEventListener("online", refreshWhenActive);
    document.addEventListener("visibilitychange", refreshWhenActive);
    return () => {
      disposed = true;
      if (refreshTimer) clearTimeout(refreshTimer);
      window.removeEventListener("focus", refreshWhenActive);
      window.removeEventListener("online", refreshWhenActive);
      document.removeEventListener("visibilitychange", refreshWhenActive);
    };
  }, [company.id, recurringRefreshKey]);

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
      key: "recurring",
      label: "Постоянные заказы",
      value: recurringAnalytics
        ? String(recurringAnalytics.activeCount)
        : recurringLoading
          ? "Загрузка…"
          : "Недоступно",
      hint: recurringAnalytics
        ? `Сегодня покупок: ${recurringAnalytics.purchasesToday} · создано: ${recurringAnalytics.generatedToday}`
        : recurringError
          ? "Не удалось обновить — откройте детали"
          : "Сводка по активным подпискам",
      icon: Repeat2
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
      case "recurring": {
        const summary = recurringAnalytics
          ? [
              {
                label: "Активных",
                value: String(recurringAnalytics.activeCount)
              },
              {
                label: "Создано сегодня",
                value: String(recurringAnalytics.generatedToday)
              },
              {
                label: "Завершено сегодня",
                value: String(recurringAnalytics.completedToday)
              },
              {
                label: "Покупок сегодня",
                value: String(recurringAnalytics.purchasesToday)
              },
              {
                label: "Сумма одного дня",
                value: formatCurrency(
                  recurringAnalytics.committedDailyAmount,
                  company.currency
                )
              }
            ]
          : [];

        return (
          <>
            <div aria-live="polite">
              {recurringLoading && !recurringAnalytics ? (
                <EmptyDetail>Загружаем постоянные заказы…</EmptyDetail>
              ) : null}
              {recurringError ? (
                <div
                  role="alert"
                  className="flex flex-col gap-3 rounded-xl border border-red-500/25 bg-red-500/5 px-4 py-3 text-sm text-red-700 sm:flex-row sm:items-center sm:justify-between dark:text-red-300"
                >
                  <span>{recurringError}</span>
                  <button
                    type="button"
                    onClick={() => setRecurringRefreshKey((value) => value + 1)}
                    className="focus-ring inline-flex min-h-10 shrink-0 items-center justify-center gap-2 rounded-xl border border-red-500/30 px-3 font-semibold transition hover:bg-red-500/10"
                  >
                    <RefreshCw className="h-4 w-4" />
                    Повторить
                  </button>
                </div>
              ) : null}
            </div>

            {recurringAnalytics ? (
              <>
                <DetailSection title="Сводка">
                  <div className="grid grid-cols-2 gap-2 lg:grid-cols-5">
                    {summary.map((item) => (
                      <div
                        key={item.label}
                        className="rounded-xl bg-cream-100 px-4 py-3 dark:bg-white/5"
                      >
                        <p className="text-xs text-coffee-500">{item.label}</p>
                        <p className="mt-1 text-lg font-semibold text-coffee-900">
                          {item.value}
                        </p>
                      </div>
                    ))}
                  </div>
                </DetailSection>

                <DetailSection title="Возвраты по отменённым постоянным заказам">
                  <div className="grid gap-4 lg:grid-cols-[minmax(0,1fr)_minmax(280px,360px)]">
                    <div className="space-y-2">
                      {recurringAnalytics.refunds.length === 0 ? (
                        <EmptyDetail>Возвратов пока нет.</EmptyDetail>
                      ) : (
                        recurringAnalytics.refunds.map((refund) => (
                          <div
                            key={refund.id}
                            className="flex flex-col gap-2 rounded-xl border border-coffee-900/10 px-4 py-3 text-sm sm:flex-row sm:items-center sm:justify-between"
                          >
                            <div>
                              <p className="font-semibold text-coffee-900">
                                {formatCurrency(refund.amount, refund.currency)}
                                {" · "}
                                {REFUND_STATUS_LABELS[refund.status]}
                              </p>
                              <p className="mt-1 text-xs text-coffee-500">
                                {formatDateTime(refund.createdAt)}
                                {" · "}
                                {refund.paymentMethod === "cash"
                                  ? "Наличные"
                                  : refund.paymentMethod === "qr"
                                    ? "QR-оплата"
                                    : "Демо-оплата"}
                                {" · "}
                                {refund.refundableOccurrences} будущих выдач
                              </p>
                              {refund.claimCode ? (
                                <p className="mt-1 font-mono text-xs font-semibold text-coffee-900">
                                  {refund.claimCode}
                                </p>
                              ) : null}
                            </div>
                            <span
                              className={`inline-flex w-fit rounded-full px-2.5 py-1 text-xs font-semibold ${
                                refund.status === "manual_required"
                                  ? "bg-amber-500/15 text-amber-700 dark:text-amber-300"
                                  : refund.status === "refunded" ||
                                      refund.status === "manual_paid"
                                    ? "bg-emerald-500/15 text-emerald-700 dark:text-emerald-300"
                                    : "bg-coffee-900/5 text-coffee-500 dark:bg-white/10"
                              }`}
                            >
                              {REFUND_STATUS_LABELS[refund.status]}
                            </span>
                          </div>
                        ))
                      )}
                    </div>

                    <form
                      className="rounded-xl border border-coffee-900/10 bg-cream-100 p-4 dark:bg-white/5"
                      onSubmit={(event) => {
                        event.preventDefault();
                        void completeManualRefund();
                      }}
                    >
                      <h4 className="font-semibold text-coffee-900">
                        Подтвердить ручную выдачу
                      </h4>
                      <p className="mt-1 text-xs leading-5 text-coffee-500">
                        Для наличных или недоступного платёжного провайдера.
                        Сначала выдайте клиенту указанную сумму, затем введите
                        код из его приложения. Один код нельзя погасить дважды.
                      </p>
                      <label className="mt-3 block text-xs font-semibold text-coffee-700">
                        QR-ссылка или код RF-…
                        <textarea
                          value={manualRefundClaim}
                          onChange={(event) => {
                            setManualRefundClaim(event.target.value);
                            setManualRefundMessage(null);
                            setManualRefundError(null);
                            if (
                              manualRefundKeyRef.current?.claim !==
                              event.target.value.trim()
                            ) {
                              manualRefundKeyRef.current = null;
                            }
                          }}
                          rows={3}
                          className="focus-ring mt-1 w-full resize-y rounded-xl border border-coffee-900/15 bg-white px-3 py-2 font-mono text-sm font-normal text-coffee-900 dark:bg-coffee-950"
                          placeholder="RF-1234-ABCD-5678"
                        />
                      </label>
                      {manualRefundError ? (
                        <p role="alert" className="mt-2 text-xs text-red-600">
                          {manualRefundError}
                        </p>
                      ) : null}
                      {manualRefundMessage ? (
                        <p
                          role="status"
                          className="mt-2 text-xs text-emerald-700 dark:text-emerald-300"
                        >
                          {manualRefundMessage}
                        </p>
                      ) : null}
                      <button
                        type="submit"
                        disabled={
                          manualRefundPending || !manualRefundClaim.trim()
                        }
                        className="focus-ring mt-3 inline-flex min-h-10 w-full items-center justify-center gap-2 rounded-xl bg-primary px-4 text-sm font-semibold text-white transition hover:brightness-95 disabled:cursor-not-allowed disabled:opacity-50"
                      >
                        {manualRefundPending ? (
                          <RefreshCw className="h-4 w-4 animate-spin" />
                        ) : (
                          <ReceiptText className="h-4 w-4" />
                        )}
                        {manualRefundPending
                          ? "Проверяем…"
                          : "Возврат выдан"}
                      </button>
                    </form>
                  </div>
                </DetailSection>

                <DetailSection title="Подключённые постоянные заказы">
                  {recurringAnalytics.rows.length === 0 ? (
                    <EmptyDetail>
                      Активных постоянных заказов пока нет.
                    </EmptyDetail>
                  ) : (
                    <div className="overflow-x-auto rounded-xl border border-coffee-900/10">
                      <table className="min-w-[1120px] w-full text-left text-sm">
                        <caption className="sr-only">
                          Клиенты, состав, филиал, срок, суммы и сегодняшний
                          статус постоянных заказов
                        </caption>
                        <thead className="bg-cream-100 text-xs uppercase tracking-wide text-coffee-500 dark:bg-white/5">
                          <tr>
                            <th scope="col" className="px-4 py-3 font-semibold">
                              Клиент
                            </th>
                            <th scope="col" className="px-4 py-3 font-semibold">
                              Товары
                            </th>
                            <th scope="col" className="px-4 py-3 font-semibold">
                              Филиал и время
                            </th>
                            <th scope="col" className="px-4 py-3 font-semibold">
                              Срок
                            </th>
                            <th scope="col" className="px-4 py-3 font-semibold">
                              Сумма
                            </th>
                            <th scope="col" className="px-4 py-3 font-semibold">
                              Сегодня
                            </th>
                          </tr>
                        </thead>
                        <tbody>
                          {recurringAnalytics.rows.map((recurring) => (
                            <tr
                              key={recurring.id}
                              className="border-t border-coffee-900/10 align-top"
                            >
                              <td className="px-4 py-4">
                                <p className="font-semibold text-coffee-900">
                                  {recurring.customer.name || "Без имени"}
                                </p>
                                <p className="mt-1 text-xs text-coffee-500">
                                  {recurring.customer.phone ??
                                    "Телефон не указан"}
                                </p>
                              </td>
                              <td className="max-w-sm px-4 py-4">
                                <div className="space-y-2">
                                  {recurring.items.map((item) => (
                                    <div
                                      key={`${recurring.id}-${item.productId}-${
                                        item.sizeId ?? "base"
                                      }`}
                                      className="flex min-w-64 items-center gap-3"
                                    >
                                      {item.imageUrl ? (
                                        <img
                                          src={item.imageUrl}
                                          alt=""
                                          loading="lazy"
                                          className="h-11 w-11 shrink-0 rounded-lg object-cover"
                                        />
                                      ) : (
                                        <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-lg bg-cream-100 text-coffee-500 dark:bg-white/5">
                                          <Package2 className="h-5 w-5" />
                                        </span>
                                      )}
                                      <span className="min-w-0">
                                        <span className="block font-medium text-coffee-900">
                                          {item.quantity} × {localizedLabel(item.name)}
                                        </span>
                                        <span className="mt-0.5 block text-xs text-coffee-500">
                                          {item.size
                                            ? `${localizedLabel(item.size)} · `
                                            : ""}
                                          {formatCurrency(
                                            item.total,
                                            company.currency
                                          )}
                                        </span>
                                      </span>
                                    </div>
                                  ))}
                                </div>
                              </td>
                              <td className="px-4 py-4">
                                <p className="font-medium text-coffee-900">
                                  {recurring.branchName}
                                </p>
                                <p className="mt-1 text-xs text-coffee-500">
                                  Каждый день к {recurring.time}
                                </p>
                              </td>
                              <td className="px-4 py-4">
                                <p className="font-medium text-coffee-900">
                                  {RECURRING_PLAN_LABELS[recurring.plan]}
                                </p>
                                <p className="mt-1 text-xs text-coffee-500">
                                  {recurring.paidUntil
                                    ? `Оплачено до ${formatDate(recurring.paidUntil)}`
                                    : "Дата окончания не указана"}
                                </p>
                              </td>
                              <td className="px-4 py-4">
                                <p className="font-medium text-coffee-900">
                                  {formatCurrency(
                                    recurring.dailyTotal,
                                    company.currency
                                  )}{" "}
                                  / день
                                </p>
                                <p className="mt-1 text-xs text-coffee-500">
                                  Предоплата:{" "}
                                  {formatCurrency(
                                    recurring.prepaidTotal,
                                    company.currency
                                  )}
                                </p>
                                {recurring.lastAdjustment ? (
                                  <p className="mt-1 text-xs text-coffee-500">
                                    {recurring.lastAdjustment.amount >= 0
                                      ? "Доплата"
                                      : "Кредит"}
                                    :{" "}
                                    {formatCurrency(
                                      Math.abs(recurring.lastAdjustment.amount),
                                      company.currency
                                    )}{" "}
                                    ·{" "}
                                    {formatDateTime(
                                      recurring.lastAdjustment.createdAt
                                    )}
                                  </p>
                                ) : null}
                              </td>
                              <td className="px-4 py-4">
                                {recurring.todayOrder ? (
                                  <div className="space-y-2">
                                    <p className="font-semibold text-coffee-900">
                                      {recurring.todayOrder.number}
                                    </p>
                                    <StatusBadge
                                      status={recurring.todayOrder.status}
                                    />
                                    <p className="text-xs text-coffee-500">
                                      {
                                        ORDER_STATUS_LABELS[
                                          recurring.todayOrder.status
                                        ]
                                      }{" "}
                                      ·{" "}
                                      {formatCurrency(
                                        recurring.todayOrder.total,
                                        company.currency
                                      )}
                                    </p>
                                    {recurring.todayOrder.scheduledFor ? (
                                      <p className="text-xs text-coffee-500">
                                        К{" "}
                                        {formatDateTime(
                                          recurring.todayOrder.scheduledFor
                                        )}
                                      </p>
                                    ) : null}
                                  </div>
                                ) : (
                                  <span className="text-xs text-coffee-500">
                                    Сегодня ещё не создан
                                  </span>
                                )}
                              </td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </div>
                  )}
                </DetailSection>
              </>
            ) : null}
          </>
        );
      }
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
        <AnalyticsDrawer
          title={selectedTitle}
          onClose={() => setSelectedDetail(null)}
          wide={selectedDetail === "recurring"}
          eyebrow={
            selectedDetail === "recurring"
              ? "Серверная аналитика"
              : "Demo-аналитика"
          }
          footer={
            selectedDetail === "recurring"
              ? "Сервер считает активность и сегодняшний день в часовом поясе бизнеса. Сводка обновляется автоматически каждые 30 секунд."
              : undefined
          }
        >
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
