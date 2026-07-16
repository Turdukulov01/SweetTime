"use client";

// Очередь заказов: доска Новый → Готовится → Готов → Выдан.
// Крупные кнопки для баристы, фильтр по филиалу (barista жёстко привязан к своему).
// Данные — из боевого API (GET /orders требует токен стаффа); если API не
// ответил, показываем ошибку, а не мок-очередь.

import { useCallback, useState } from "react";
import { Ban, ChevronRight, MapPin, ReceiptText, TriangleAlert } from "lucide-react";
import { OrderDetailsDrawer } from "@/components/order-details-drawer";
import { StatusBadge } from "@/components/status-badge";
import { useCompanyStore } from "@/lib/company-store";
import { ORDER_STATUS_LABELS, ORDER_TYPE_LABELS } from "@/lib/labels";
import { useOrders } from "@/lib/orders-store";
import { useSession } from "@/lib/session";
import type { Order, OrderStatus } from "@/lib/types";
import { cn, formatCurrency, formatTime } from "@/lib/utils";

const BOARD_COLUMNS: OrderStatus[] = ["new", "preparing", "ready", "done"];

const NEXT_ACTION: Partial<
  Record<OrderStatus, { next: OrderStatus; label: string }>
> = {
  new: { next: "preparing", label: "Принять в работу" },
  preparing: { next: "ready", label: "Готов" },
  ready: { next: "done", label: "Выдать" }
};

function OrderCard({
  order,
  branchName,
  showBranch,
  currency,
  onDetails
}: {
  order: Order;
  branchName: string;
  showBranch: boolean;
  currency: string;
  onDetails: () => void;
}) {
  const { setStatus } = useOrders();
  const action = NEXT_ACTION[order.status];
  const cancellable = ["new", "preparing", "ready"].includes(order.status);

  return (
    <article className="surface px-4 py-4">
      <div className="flex items-start justify-between gap-2">
        <div>
          <p className="text-sm font-semibold text-coffee-900">
            {order.number}
            <span className="ml-2 font-normal text-coffee-500">
              {formatTime(order.createdAt)}
            </span>
          </p>
          <p className="mt-0.5 text-xs text-coffee-500">
            {ORDER_TYPE_LABELS[order.type]} · {order.customerName}
          </p>
          {showBranch && (
            <p className="mt-0.5 flex items-center gap-1 text-xs text-coffee-500">
              <MapPin className="h-3 w-3" />
              {branchName}
            </p>
          )}
        </div>
        <p className="whitespace-nowrap text-sm font-semibold text-coffee-900">
          {formatCurrency(order.total, currency)}
        </p>
      </div>

      <ul className="mt-3 space-y-1 border-t border-coffee-900/5 pt-3">
        {order.items.map((item, index) => (
          <li
            key={index}
            className="flex items-baseline justify-between gap-2 text-sm text-coffee-700"
          >
            <span>
              {item.quantity} × {item.name || "Название не передано"}
            </span>
            <span className="whitespace-nowrap text-xs text-coffee-500">
              {formatCurrency(item.lineTotal, currency)}
            </span>
          </li>
        ))}
      </ul>

      <button
        type="button"
        onClick={onDetails}
        className="focus-ring mt-3 flex h-10 w-full items-center justify-center gap-2 rounded-full border border-coffee-900/15 text-sm font-semibold text-coffee-700 transition hover:border-accent hover:text-accent"
      >
        <ReceiptText className="h-4 w-4" />
        Подробнее
      </button>

      {(action || cancellable) && (
        <div className="mt-3 flex items-center gap-2">
          {action && (
            <button
              type="button"
              onClick={() => setStatus(order.id, action.next)}
              className="focus-ring flex h-11 flex-1 items-center justify-center gap-1.5 rounded-full bg-accent text-sm font-semibold text-white transition hover:opacity-90"
            >
              {action.label}
              <ChevronRight className="h-4 w-4" />
            </button>
          )}
          {cancellable && (
            <button
              type="button"
              onClick={() => setStatus(order.id, "cancelled")}
              title="Отменить заказ"
              className="focus-ring flex h-11 items-center justify-center gap-1.5 rounded-full border border-red-200 px-4 text-sm font-medium text-red-600 transition hover:bg-red-50 dark:border-red-400/30 dark:text-red-400 dark:hover:bg-red-500/10"
            >
              <Ban className="h-4 w-4" />
              Отменить
            </button>
          )}
        </div>
      )}
    </article>
  );
}

export default function OrdersPage() {
  const { user } = useSession();
  const { company, branches } = useCompanyStore();
  const { orders, errorMessage, loading, loadFailed } = useOrders();
  const [branchFilter, setBranchFilter] = useState<string>("all");
  const [selectedOrderId, setSelectedOrderId] = useState<string | null>(null);
  const closeDetails = useCallback(() => setSelectedOrderId(null), []);

  if (!user) return null;

  const branchName = (branchId: string) =>
    branches.find((b) => b.id === branchId)?.name ?? branchId;

  // Barista жёстко видит только свой филиал
  const isBarista = user.role === "barista";

  // Edge-case: barista без назначенного филиала не видит чужие очереди
  if (isBarista && !user.branchId) {
    return (
      <div>
        <h1 className="text-2xl">Заказы</h1>
        <div className="surface mt-6 px-6 py-16 text-center">
          <p className="text-sm font-semibold text-coffee-900">
            Вам не назначен филиал
          </p>
          <p className="mx-auto mt-1 max-w-md text-sm text-coffee-500">
            Очередь заказов недоступна. Попросите владельца или менеджера
            привязать вас к филиалу на странице «Сотрудники».
          </p>
        </div>
      </div>
    );
  }

  const effectiveBranch = isBarista ? (user.branchId as string) : branchFilter;

  const visibleOrders =
    effectiveBranch === "all"
      ? orders
      : orders.filter((o) => o.branchId === effectiveBranch);
  const selectedOrder = selectedOrderId
    ? orders.find((order) => order.id === selectedOrderId)
    : undefined;

  const byStatus = (status: OrderStatus) =>
    visibleOrders
      .filter((o) => o.status === status)
      .sort(
        (a, b) =>
          status === "done"
            ? new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
            : new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime()
      );

  const cancelled = visibleOrders
    .filter((o) => o.status === "cancelled")
    .sort(
      (a, b) =>
        new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
    );

  return (
    <div>
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl">Заказы</h1>
          <p className="mt-1 text-sm text-coffee-500">
            Очередь {company.name}: переводите заказ в следующий статус одним
            нажатием
          </p>
        </div>

        {isBarista ? (
          <span className="flex items-center gap-1.5 rounded-full bg-accent/10 px-4 py-2 text-sm font-medium text-accent">
            <MapPin className="h-4 w-4" />
            {user.branchId ? branchName(user.branchId) : "Филиал не назначен"}
          </span>
        ) : (
          <div className="flex flex-wrap items-center gap-2">
            <button
              type="button"
              onClick={() => setBranchFilter("all")}
              className={cn(
                "focus-ring h-9 rounded-full px-4 text-sm font-medium transition",
                branchFilter === "all"
                  ? "bg-accent text-white"
                  : "border border-coffee-900/15 text-coffee-700 hover:border-accent hover:text-accent"
              )}
            >
              Все филиалы
            </button>
            {branches.map((branch) => (
              <button
                key={branch.id}
                type="button"
                onClick={() => setBranchFilter(branch.id)}
                className={cn(
                  "focus-ring h-9 rounded-full px-4 text-sm font-medium transition",
                  branchFilter === branch.id
                    ? "bg-accent text-white"
                    : "border border-coffee-900/15 text-coffee-700 hover:border-accent hover:text-accent"
                )}
              >
                {branch.name}
              </button>
            ))}
          </div>
        )}
      </div>

      {loadFailed && (
        <div className="surface mt-6 px-6 py-16 text-center">
          <p className="text-sm font-semibold text-coffee-900">
            Очередь заказов недоступна
          </p>
          <p className="mx-auto mt-1 max-w-md text-sm text-coffee-500">
            {errorMessage ?? "Сервер не ответил."} Показываем пустую очередь:
            мок-данные вместо боевых не подставляются.
          </p>
        </div>
      )}

      {!loadFailed && loading && orders.length === 0 && (
        <p className="mt-6 text-sm text-coffee-500">Загружаем очередь…</p>
      )}

      <div
        className={cn(
          "mt-6 grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-4",
          (loadFailed || (loading && orders.length === 0)) && "hidden"
        )}
      >
        {BOARD_COLUMNS.map((status) => {
          const columnOrders = byStatus(status);
          return (
            <section key={status} className="min-w-0">
              <div className="mb-3 flex items-center gap-2">
                <StatusBadge status={status} />
                <span className="text-sm text-coffee-500">
                  {columnOrders.length}
                </span>
              </div>
              <div className="space-y-3">
                {columnOrders.map((order) => (
                  <OrderCard
                    key={order.id}
                    order={order}
                    branchName={branchName(order.branchId)}
                    showBranch={!isBarista && effectiveBranch === "all"}
                    currency={company.currency}
                    onDetails={() => setSelectedOrderId(order.id)}
                  />
                ))}
                {columnOrders.length === 0 && (
                  <p className="rounded-2xl border border-dashed border-coffee-900/15 px-4 py-6 text-center text-sm text-coffee-500">
                    Нет заказов «{ORDER_STATUS_LABELS[status]}»
                  </p>
                )}
              </div>
            </section>
          );
        })}
      </div>

      {cancelled.length > 0 && (
        <div className="mt-8">
          <h2 className="text-base text-coffee-700">
            Отменённые ({cancelled.length})
          </h2>
          <ul className="mt-3 space-y-2">
            {cancelled.map((order) => (
              <li
                key={order.id}
                className="surface flex flex-wrap items-center justify-between gap-2 px-4 py-3 text-sm text-coffee-500"
              >
                <span className="font-medium text-coffee-700">
                  {order.number}
                </span>
                <span>{formatTime(order.createdAt)}</span>
                <span>{order.customerName}</span>
                {!isBarista && effectiveBranch === "all" && (
                  <span>{branchName(order.branchId)}</span>
                )}
                <span className="line-through">
                  {formatCurrency(order.total, company.currency)}
                </span>
                <StatusBadge status="cancelled" />
                <button
                  type="button"
                  onClick={() => setSelectedOrderId(order.id)}
                  className="focus-ring flex h-9 items-center gap-1.5 rounded-full border border-coffee-900/15 px-3 text-xs font-semibold text-coffee-700 transition hover:border-accent hover:text-accent"
                >
                  <ReceiptText className="h-3.5 w-3.5" />
                  Подробнее
                </button>
              </li>
            ))}
          </ul>
        </div>
      )}

      {/* Тост ошибки действия (403, 409, сеть). Ошибку загрузки показываем выше */}
      {errorMessage && !loadFailed && (
        <div
          role="alert"
          className="fixed bottom-6 right-6 z-50 flex items-center gap-2 rounded-full bg-red-600 px-5 py-2.5 text-sm font-medium text-white shadow-soft"
        >
          <TriangleAlert className="h-4 w-4" />
          {errorMessage}
        </div>
      )}

      {selectedOrder && (
        <OrderDetailsDrawer
          order={selectedOrder}
          branchName={branchName(selectedOrder.branchId)}
          currency={company.currency}
          onClose={closeDetails}
        />
      )}
    </div>
  );
}
