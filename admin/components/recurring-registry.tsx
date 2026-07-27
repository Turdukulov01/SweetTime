"use client";

import {
  Fragment,
  useCallback,
  useEffect,
  useMemo,
  useState,
  type FormEvent
} from "react";
import {
  CalendarDays,
  ChevronDown,
  ChevronLeft,
  ChevronRight,
  Clock3,
  MapPin,
  Package2,
  Phone,
  RefreshCw,
  Search,
  UserRound,
  WalletCards,
  X
} from "lucide-react";
import { StatusBadge } from "@/components/status-badge";
import {
  apiFetchRecurringRegistry,
  describeApiError,
  type RecurringRegistryFilters
} from "@/lib/api";
import { useCompanyStore } from "@/lib/company-store";
import { ORDER_STATUS_LABELS } from "@/lib/labels";
import type {
  LocalizedText,
  RecurringOrderRegistry,
  RecurringPlan,
  RecurringRegistryRow,
  RecurringRegistryStatus
} from "@/lib/types";
import {
  cn,
  formatCurrency,
  formatDate,
  formatDateTime
} from "@/lib/utils";

const PAGE_SIZE = 50;

type PeriodPreset = "all" | "week" | "month" | "custom";
type StatusFilter = "all" | RecurringRegistryStatus;

interface AppliedFilters {
  search: string;
  status: StatusFilter;
  createdFrom?: string;
  createdTo?: string;
}

const STATUS_LABELS: Record<RecurringRegistryStatus, string> = {
  active: "Активен",
  completed: "Завершён",
  cancelled: "Отменён"
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

function localDateKey(value: Date): string {
  const year = value.getFullYear();
  const month = String(value.getMonth() + 1).padStart(2, "0");
  const day = String(value.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function daysAgo(days: number): string {
  const value = new Date();
  value.setHours(0, 0, 0, 0);
  value.setDate(value.getDate() - days);
  return localDateKey(value);
}

function planLabel(plan: RecurringPlan): string {
  switch (plan) {
    case "single":
      return "Один день";
    case "week":
      return "Неделя";
    case "month":
      return "Месяц";
    case "custom":
      return "Свой срок";
    default:
      return plan;
  }
}

function RegistryStatusBadge({
  status
}: {
  status: RecurringRegistryStatus;
}) {
  return (
    <span
      className={cn(
        "inline-flex rounded-full px-2.5 py-1 text-xs font-semibold",
        status === "active" &&
          "bg-emerald-50 text-emerald-700 dark:bg-emerald-400/15 dark:text-emerald-300",
        status === "completed" &&
          "bg-sky-50 text-sky-700 dark:bg-sky-400/15 dark:text-sky-300",
        status === "cancelled" &&
          "bg-red-50 text-red-700 dark:bg-red-400/15 dark:text-red-300"
      )}
    >
      {STATUS_LABELS[status]}
    </span>
  );
}

function SummaryCard({
  label,
  value,
  tone
}: {
  label: string;
  value: number;
  tone: "accent" | "green" | "blue" | "red";
}) {
  return (
    <article className="surface px-5 py-4">
      <div className="flex items-center justify-between gap-3">
        <div>
          <p className="text-xs font-medium uppercase tracking-wide text-coffee-500">
            {label}
          </p>
          <p className="mt-2 text-2xl font-semibold tabular-nums text-coffee-900">
            {value}
          </p>
        </div>
        <span
          className={cn(
            "h-10 w-2 rounded-full",
            tone === "accent" && "bg-accent",
            tone === "green" && "bg-emerald-500",
            tone === "blue" && "bg-sky-500",
            tone === "red" && "bg-red-500"
          )}
          aria-hidden="true"
        />
      </div>
    </article>
  );
}

function DetailBlock({
  title,
  icon,
  children
}: {
  title: string;
  icon: React.ReactNode;
  children: React.ReactNode;
}) {
  return (
    <section className="rounded-xl border border-coffee-900/10 bg-cream-50/60 p-4 dark:bg-white/[0.03]">
      <h3 className="flex items-center gap-2 text-sm font-semibold text-coffee-900">
        <span className="text-accent">{icon}</span>
        {title}
      </h3>
      <div className="mt-3">{children}</div>
    </section>
  );
}

function RegistryDetails({
  row,
  currency
}: {
  row: RecurringRegistryRow;
  currency: string;
}) {
  return (
    <div className="grid gap-4 p-5 lg:grid-cols-2 xl:grid-cols-4">
      <DetailBlock
        title="Клиент и подписка"
        icon={<UserRound className="h-4 w-4" />}
      >
        <dl className="space-y-2 text-sm">
          <div>
            <dt className="text-xs text-coffee-500">Клиент</dt>
            <dd className="font-medium text-coffee-900">
              {row.customer.name || "Без имени"}
            </dd>
          </div>
          <div>
            <dt className="text-xs text-coffee-500">Телефон</dt>
            <dd className="text-coffee-700">
              {row.customer.phone ?? "Не указан"}
            </dd>
          </div>
          <div>
            <dt className="text-xs text-coffee-500">ID постоянного заказа</dt>
            <dd className="break-all font-mono text-xs text-coffee-700">
              {row.id}
            </dd>
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <dt className="text-xs text-coffee-500">Подключён</dt>
              <dd className="text-coffee-700">{formatDateTime(row.createdAt)}</dd>
            </div>
            <div>
              <dt className="text-xs text-coffee-500">Обновлён</dt>
              <dd className="text-coffee-700">{formatDateTime(row.updatedAt)}</dd>
            </div>
          </div>
        </dl>
      </DetailBlock>

      <DetailBlock
        title="Товары"
        icon={<Package2 className="h-4 w-4" />}
      >
        {row.items.length === 0 ? (
          <p className="text-sm text-coffee-500">Состав не зафиксирован.</p>
        ) : (
          <ul className="space-y-3">
            {row.items.map((item, index) => (
              <li
                key={`${row.id}-${item.productId}-${item.sizeId ?? "base"}-${index}`}
                className="flex items-start gap-3"
              >
                {item.imageUrl ? (
                  <img
                    src={item.imageUrl}
                    alt=""
                    loading="lazy"
                    className="h-12 w-12 shrink-0 rounded-xl object-cover"
                  />
                ) : (
                  <span className="flex h-12 w-12 shrink-0 items-center justify-center rounded-xl bg-coffee-900/5 text-coffee-500">
                    <Package2 className="h-5 w-5" />
                  </span>
                )}
                <span className="min-w-0 text-sm">
                  <span className="block font-medium text-coffee-900">
                    {item.quantity} × {localizedLabel(item.name)}
                  </span>
                  {item.size ? (
                    <span className="mt-0.5 block text-xs text-coffee-500">
                      {localizedLabel(item.size)}
                    </span>
                  ) : null}
                  <span className="mt-0.5 block text-xs text-coffee-500">
                    {formatCurrency(item.unitPrice, currency)} за единицу ·{" "}
                    {formatCurrency(item.total, currency)}
                  </span>
                </span>
              </li>
            ))}
          </ul>
        )}
      </DetailBlock>

      <DetailBlock
        title="Расписание"
        icon={<CalendarDays className="h-4 w-4" />}
      >
        <dl className="space-y-2 text-sm">
          <div>
            <dt className="text-xs text-coffee-500">Филиал</dt>
            <dd className="flex items-center gap-1.5 font-medium text-coffee-900">
              <MapPin className="h-3.5 w-3.5 text-accent" />
              {row.branchName}
            </dd>
          </div>
          <div>
            <dt className="text-xs text-coffee-500">Время</dt>
            <dd className="flex items-center gap-1.5 text-coffee-700">
              <Clock3 className="h-3.5 w-3.5 text-accent" />
              Каждый день к {row.time}
            </dd>
          </div>
          <div>
            <dt className="text-xs text-coffee-500">Период</dt>
            <dd className="text-coffee-700">
              {planLabel(row.plan)}
              {row.plan === "custom" && row.customUntil
                ? ` · до ${formatDate(row.customUntil)} включительно`
                : ""}
            </dd>
          </div>
          <div>
            <dt className="text-xs text-coffee-500">Оплачено до</dt>
            <dd className="text-coffee-700">
              {row.paidUntil ? formatDate(row.paidUntil) : "Не указано"}
            </dd>
          </div>
        </dl>
      </DetailBlock>

      <DetailBlock
        title="Оплата и сегодняшний заказ"
        icon={<WalletCards className="h-4 w-4" />}
      >
        <dl className="space-y-2 text-sm">
          <div className="grid grid-cols-2 gap-3">
            <div>
              <dt className="text-xs text-coffee-500">За день</dt>
              <dd className="font-medium text-coffee-900">
                {formatCurrency(row.dailyTotal, currency)}
              </dd>
            </div>
            <div>
              <dt className="text-xs text-coffee-500">Предоплата</dt>
              <dd className="font-medium text-coffee-900">
                {formatCurrency(row.prepaidTotal, currency)}
              </dd>
            </div>
          </div>
          {row.lastAdjustment ? (
            <div>
              <dt className="text-xs text-coffee-500">
                Последняя корректировка
              </dt>
              <dd className="text-coffee-700">
                {row.lastAdjustment.amount >= 0 ? "Доплата" : "Возврат"}{" "}
                {formatCurrency(
                  Math.abs(row.lastAdjustment.amount),
                  currency
                )}{" "}
                · {formatDateTime(row.lastAdjustment.createdAt)} (демо)
              </dd>
            </div>
          ) : null}
          <div className="border-t border-coffee-900/10 pt-2">
            <dt className="text-xs text-coffee-500">Сегодня</dt>
            {row.todayOrder ? (
              <dd className="mt-1 space-y-1.5">
                <div className="flex flex-wrap items-center gap-2">
                  <span className="font-semibold text-coffee-900">
                    {row.todayOrder.number}
                  </span>
                  <StatusBadge status={row.todayOrder.status} />
                </div>
                <p className="text-xs text-coffee-500">
                  {ORDER_STATUS_LABELS[row.todayOrder.status]} ·{" "}
                  {formatCurrency(row.todayOrder.total, currency)}
                  {row.todayOrder.scheduledFor
                    ? ` · к ${formatDateTime(row.todayOrder.scheduledFor)}`
                    : ""}
                </p>
              </dd>
            ) : (
              <dd className="mt-1 text-coffee-500">
                Заказ на сегодня не создан.
              </dd>
            )}
          </div>
        </dl>
      </DetailBlock>
    </div>
  );
}

export function RecurringRegistry() {
  const { company } = useCompanyStore();
  const [data, setData] = useState<RecurringOrderRegistry | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [reloadKey, setReloadKey] = useState(0);
  const [expandedId, setExpandedId] = useState<string | null>(null);
  const [offset, setOffset] = useState(0);

  const [search, setSearch] = useState("");
  const [status, setStatus] = useState<StatusFilter>("all");
  const [period, setPeriod] = useState<PeriodPreset>("all");
  const [customFrom, setCustomFrom] = useState("");
  const [customTo, setCustomTo] = useState("");
  const [filterError, setFilterError] = useState<string | null>(null);
  const [applied, setApplied] = useState<AppliedFilters>({
    search: "",
    status: "all"
  });

  const requestFilters = useMemo<RecurringRegistryFilters>(
    () => ({
      ...applied,
      offset,
      limit: PAGE_SIZE
    }),
    [applied, offset]
  );

  useEffect(() => {
    let ignored = false;
    setLoading(true);
    setError(null);
    apiFetchRecurringRegistry(company.id, requestFilters)
      .then((next) => {
        if (ignored) return;
        if (offset > 0 && next.items.length === 0) {
          const lastPageOffset =
            next.total === 0
              ? 0
              : Math.floor((next.total - 1) / PAGE_SIZE) * PAGE_SIZE;
          if (lastPageOffset !== offset) {
            setOffset(lastPageOffset);
            return;
          }
        }
        setData(next);
        setExpandedId((current) =>
          current && next.items.some((item) => item.id === current)
            ? current
            : null
        );
      })
      .catch((reason: unknown) => {
        if (!ignored) setError(describeApiError(reason));
      })
      .finally(() => {
        if (!ignored) setLoading(false);
      });
    return () => {
      ignored = true;
    };
  }, [company.id, offset, requestFilters, reloadKey]);

  const applyFilters = useCallback(
    (event: FormEvent<HTMLFormElement>) => {
      event.preventDefault();
      let createdFrom: string | undefined;
      let createdTo: string | undefined;
      if (period === "week") {
        createdFrom = daysAgo(6);
        createdTo = localDateKey(new Date());
      } else if (period === "month") {
        createdFrom = daysAgo(29);
        createdTo = localDateKey(new Date());
      } else if (period === "custom") {
        createdFrom = customFrom || undefined;
        createdTo = customTo || undefined;
        if (createdFrom && createdTo && createdFrom > createdTo) {
          setFilterError("Начальная дата не может быть позже конечной.");
          return;
        }
      }
      setFilterError(null);
      setOffset(0);
      setApplied({
        search: search.trim(),
        status,
        createdFrom,
        createdTo
      });
    },
    [customFrom, customTo, period, search, status]
  );

  function resetFilters() {
    setSearch("");
    setStatus("all");
    setPeriod("all");
    setCustomFrom("");
    setCustomTo("");
    setFilterError(null);
    setOffset(0);
    setApplied({ search: "", status: "all" });
  }

  const firstVisible = data && data.total > 0 ? offset + 1 : 0;
  const lastVisible = data ? Math.min(offset + data.items.length, data.total) : 0;
  const canGoBack = offset > 0;
  const canGoForward = Boolean(data && offset + data.items.length < data.total);

  return (
    <div className="space-y-6">
      <header className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <h1 className="text-2xl">Постоянные заказы</h1>
          <p className="mt-1 max-w-3xl text-sm text-coffee-500">
            Полный реестр подписок клиентов. Оперативное расписание на сегодня
            остаётся на странице «Заказы».
          </p>
        </div>
        <button
          type="button"
          onClick={() => setReloadKey((value) => value + 1)}
          disabled={loading}
          className="focus-ring flex h-10 items-center gap-2 rounded-full border border-coffee-900/15 px-4 text-sm font-semibold text-coffee-700 transition hover:border-accent hover:text-accent disabled:cursor-wait disabled:opacity-50"
        >
          <RefreshCw className={cn("h-4 w-4", loading && "animate-spin")} />
          Обновить
        </button>
      </header>

      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
        <SummaryCard
          label="Найдено"
          value={data?.total ?? 0}
          tone="accent"
        />
        <SummaryCard
          label="Активные"
          value={data?.activeCount ?? 0}
          tone="green"
        />
        <SummaryCard
          label="Завершённые"
          value={data?.completedCount ?? 0}
          tone="blue"
        />
        <SummaryCard
          label="Отменённые"
          value={data?.cancelledCount ?? 0}
          tone="red"
        />
      </div>

      <form onSubmit={applyFilters} className="surface p-5">
        <div className="grid gap-4 lg:grid-cols-[minmax(16rem,1.5fr)_minmax(10rem,0.7fr)_minmax(12rem,0.8fr)]">
          <label className="block">
            <span className="mb-1.5 block text-xs font-semibold text-coffee-700">
              Поиск
            </span>
            <span className="relative block">
              <Search className="pointer-events-none absolute left-3.5 top-1/2 h-4 w-4 -translate-y-1/2 text-coffee-500" />
              <input
                value={search}
                onChange={(event) => setSearch(event.target.value)}
                className="input pl-10"
                placeholder="Имя, телефон или ID"
              />
            </span>
          </label>

          <label className="block">
            <span className="mb-1.5 block text-xs font-semibold text-coffee-700">
              Статус
            </span>
            <select
              value={status}
              onChange={(event) =>
                setStatus(event.target.value as StatusFilter)
              }
              className="input"
            >
              <option value="all">Все статусы</option>
              <option value="active">Активные</option>
              <option value="completed">Завершённые</option>
              <option value="cancelled">Отменённые</option>
            </select>
          </label>

          <label className="block">
            <span className="mb-1.5 block text-xs font-semibold text-coffee-700">
              Дата подключения
            </span>
            <select
              value={period}
              onChange={(event) =>
                setPeriod(event.target.value as PeriodPreset)
              }
              className="input"
            >
              <option value="all">За всё время</option>
              <option value="week">Последние 7 дней</option>
              <option value="month">Последние 30 дней</option>
              <option value="custom">Свой период</option>
            </select>
          </label>
        </div>

        {period === "custom" ? (
          <div className="mt-4 grid max-w-xl gap-3 sm:grid-cols-2">
            <label className="block">
              <span className="mb-1.5 block text-xs font-semibold text-coffee-700">
                С даты
              </span>
              <input
                type="date"
                value={customFrom}
                onChange={(event) => setCustomFrom(event.target.value)}
                className="input"
              />
            </label>
            <label className="block">
              <span className="mb-1.5 block text-xs font-semibold text-coffee-700">
                По дату
              </span>
              <input
                type="date"
                value={customTo}
                onChange={(event) => setCustomTo(event.target.value)}
                className="input"
              />
            </label>
          </div>
        ) : null}

        {filterError ? (
          <p role="alert" className="mt-3 text-sm text-red-600">
            {filterError}
          </p>
        ) : null}

        <div className="mt-4 flex flex-wrap gap-2">
          <button
            type="submit"
            className="focus-ring flex h-10 items-center gap-2 rounded-full bg-accent px-5 text-sm font-semibold text-white transition hover:opacity-90"
          >
            <Search className="h-4 w-4" />
            Применить
          </button>
          <button
            type="button"
            onClick={resetFilters}
            className="focus-ring flex h-10 items-center gap-2 rounded-full border border-coffee-900/15 px-5 text-sm font-medium text-coffee-700 transition hover:border-accent hover:text-accent"
          >
            <X className="h-4 w-4" />
            Сбросить
          </button>
        </div>
      </form>

      <section className="surface overflow-hidden">
        <div className="flex flex-wrap items-center justify-between gap-3 border-b border-coffee-900/10 px-5 py-4">
          <div>
            <h2 className="text-base">Реестр</h2>
            <p className="mt-0.5 text-xs text-coffee-500">
              {data
                ? `Показано ${firstVisible}–${lastVisible} из ${data.total}`
                : "Загрузка данных"}
            </p>
          </div>
          {loading && data ? (
            <span className="flex items-center gap-2 text-xs text-coffee-500">
              <RefreshCw className="h-3.5 w-3.5 animate-spin" />
              Обновляем
            </span>
          ) : null}
        </div>

        {error ? (
          <div className="px-5 py-12 text-center">
            <p role="alert" className="text-sm text-red-600">
              {error}
            </p>
            <button
              type="button"
              onClick={() => setReloadKey((value) => value + 1)}
              className="focus-ring mt-4 inline-flex h-10 items-center gap-2 rounded-full border border-red-200 px-5 text-sm font-semibold text-red-600"
            >
              <RefreshCw className="h-4 w-4" />
              Повторить
            </button>
          </div>
        ) : loading && !data ? (
          <div className="flex min-h-64 items-center justify-center">
            <p className="flex items-center gap-2 text-sm text-coffee-500">
              <RefreshCw className="h-4 w-4 animate-spin" />
              Загружаем постоянные заказы…
            </p>
          </div>
        ) : data?.items.length === 0 ? (
          <div className="flex min-h-64 flex-col items-center justify-center px-5 text-center">
            <Package2 className="h-9 w-9 text-coffee-500/50" />
            <h2 className="mt-3 text-base">Ничего не найдено</h2>
            <p className="mt-1 text-sm text-coffee-500">
              Измените фильтры или сбросьте выбранный период.
            </p>
          </div>
        ) : data ? (
          <div className="overflow-x-auto">
            <table className="w-full min-w-[1080px] text-left text-sm">
              <caption className="sr-only">
                Полный реестр постоянных заказов клиентов
              </caption>
              <thead className="bg-cream-100 text-xs uppercase tracking-wide text-coffee-500 dark:bg-white/5">
                <tr>
                  <th scope="col" className="w-12 px-4 py-3">
                    <span className="sr-only">Подробнее</span>
                  </th>
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
                    Срок и сумма
                  </th>
                  <th scope="col" className="px-4 py-3 font-semibold">
                    Статус
                  </th>
                </tr>
              </thead>
              <tbody>
                {data.items.map((row) => {
                  const expanded = expandedId === row.id;
                  const productSummary = row.items
                    .map((item) => `${item.quantity} × ${localizedLabel(item.name)}`)
                    .join(" + ");
                  return (
                    <Fragment key={row.id}>
                      <tr className="border-t border-coffee-900/10 align-top">
                        <td className="px-4 py-4">
                          <button
                            type="button"
                            onClick={() =>
                              setExpandedId(expanded ? null : row.id)
                            }
                            aria-expanded={expanded}
                            aria-controls={`recurring-details-${row.id}`}
                            title={expanded ? "Свернуть" : "Подробнее"}
                            className="focus-ring flex h-8 w-8 items-center justify-center rounded-full border border-coffee-900/15 text-coffee-500 transition hover:border-accent hover:text-accent"
                          >
                            <ChevronDown
                              className={cn(
                                "h-4 w-4 transition-transform",
                                expanded && "rotate-180"
                              )}
                            />
                          </button>
                        </td>
                        <td className="px-4 py-4">
                          <p className="font-semibold text-coffee-900">
                            {row.customer.name || "Без имени"}
                          </p>
                          <p className="mt-1 flex items-center gap-1 text-xs text-coffee-500">
                            <Phone className="h-3 w-3" />
                            {row.customer.phone ?? "Телефон не указан"}
                          </p>
                          <p className="mt-1 max-w-52 truncate font-mono text-[11px] text-coffee-500">
                            {row.id}
                          </p>
                        </td>
                        <td className="max-w-sm px-4 py-4">
                          <p className="line-clamp-2 font-medium text-coffee-900">
                            {productSummary || "Состав не зафиксирован"}
                          </p>
                          <p className="mt-1 text-xs text-coffee-500">
                            {row.items.length} позиций
                          </p>
                        </td>
                        <td className="px-4 py-4">
                          <p className="font-medium text-coffee-900">
                            {row.branchName}
                          </p>
                          <p className="mt-1 text-xs text-coffee-500">
                            Каждый день к {row.time}
                          </p>
                        </td>
                        <td className="px-4 py-4">
                          <p className="font-medium text-coffee-900">
                            {planLabel(row.plan)}
                            {row.plan === "custom" && row.customUntil
                              ? ` до ${formatDate(row.customUntil)}`
                              : ""}{" "}
                            ·{" "}
                            {formatCurrency(row.dailyTotal, company.currency)} /
                            день
                          </p>
                          <p className="mt-1 text-xs text-coffee-500">
                            {row.paidUntil
                              ? `Оплачено до ${formatDate(row.paidUntil)}`
                              : "Срок оплаты не указан"}{" "}
                            · предоплата{" "}
                            {formatCurrency(row.prepaidTotal, company.currency)}
                          </p>
                        </td>
                        <td className="px-4 py-4">
                          <RegistryStatusBadge status={row.status} />
                          <p className="mt-2 text-xs text-coffee-500">
                            {formatDateTime(row.updatedAt)}
                          </p>
                        </td>
                      </tr>
                      {expanded ? (
                        <tr
                          id={`recurring-details-${row.id}`}
                          className="border-t border-coffee-900/5 bg-cream-50/40 dark:bg-white/[0.02]"
                        >
                          <td colSpan={6}>
                            <RegistryDetails
                              row={row}
                              currency={company.currency}
                            />
                          </td>
                        </tr>
                      ) : null}
                    </Fragment>
                  );
                })}
              </tbody>
            </table>
          </div>
        ) : null}

        {data && data.total > PAGE_SIZE ? (
          <div className="flex items-center justify-between gap-3 border-t border-coffee-900/10 px-5 py-4">
            <p className="text-xs text-coffee-500">
              {firstVisible}–{lastVisible} из {data.total}
            </p>
            <div className="flex gap-2">
              <button
                type="button"
                disabled={!canGoBack || loading}
                onClick={() =>
                  setOffset((value) => Math.max(0, value - PAGE_SIZE))
                }
                className="focus-ring flex h-9 items-center gap-1 rounded-full border border-coffee-900/15 px-3 text-sm font-medium text-coffee-700 disabled:cursor-not-allowed disabled:opacity-40"
              >
                <ChevronLeft className="h-4 w-4" />
                Назад
              </button>
              <button
                type="button"
                disabled={!canGoForward || loading}
                onClick={() => setOffset((value) => value + PAGE_SIZE)}
                className="focus-ring flex h-9 items-center gap-1 rounded-full border border-coffee-900/15 px-3 text-sm font-medium text-coffee-700 disabled:cursor-not-allowed disabled:opacity-40"
              >
                Далее
                <ChevronRight className="h-4 w-4" />
              </button>
            </div>
          </div>
        ) : null}
      </section>
    </div>
  );
}
