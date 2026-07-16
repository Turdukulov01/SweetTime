"use client";

import { useEffect, useRef, useState } from "react";
import {
  CalendarClock,
  Coins,
  CreditCard,
  ImageIcon,
  MapPin,
  MessageSquareText,
  Phone,
  ReceiptText,
  UserRound,
  X
} from "lucide-react";
import { StatusBadge } from "@/components/status-badge";
import { ORDER_TYPE_LABELS } from "@/lib/labels";
import type { Order } from "@/lib/types";
import { formatCurrency } from "@/lib/utils";

const PAYMENT_METHOD_LABELS: Record<string, string> = {
  mock: "Демо-оплата",
  cash: "Наличные",
  qr: "QR-оплата"
};

const PAYMENT_STATUS_LABELS: Record<string, string> = {
  pending: "Ожидает оплаты",
  paid: "Оплачен",
  failed: "Ошибка оплаты",
  refunded: "Возвращён",
  cancelled: "Отменён"
};

const ICE_LABELS: Record<string, string> = {
  none: "Без льда",
  less: "Меньше льда",
  regular: "Обычный лёд",
  extra: "Больше льда"
};

function displayEnum(value: string, labels: Record<string, string>): string {
  return labels[value.toLowerCase()] ?? value;
}

function fullDate(value: string): string {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;
  return new Intl.DateTimeFormat("ru-RU", {
    dateStyle: "long",
    timeStyle: "short"
  }).format(date);
}

function Detail({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <dt className="text-xs font-medium text-coffee-500">{label}</dt>
      <dd className="mt-1 text-sm font-semibold text-coffee-900">{value}</dd>
    </div>
  );
}

function ProductImage({ src, name }: { src?: string; name: string }) {
  const [failed, setFailed] = useState(false);

  if (!src || failed) {
    return (
      <div
        role="img"
        aria-label="Фото товара отсутствует"
        className="flex h-20 w-20 shrink-0 items-center justify-center rounded-xl bg-coffee-900/5 text-coffee-400"
      >
        <ImageIcon className="h-6 w-6" />
      </div>
    );
  }

  return (
    <div className="h-20 w-20 shrink-0 overflow-hidden rounded-xl bg-coffee-900/5">
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img
        src={src}
        alt={name ? `Фото: ${name}` : "Фото товара"}
        loading="lazy"
        decoding="async"
        onError={() => setFailed(true)}
        className="h-full w-full object-cover"
      />
    </div>
  );
}

export function OrderDetailsDrawer({
  order,
  branchName,
  currency,
  onClose
}: {
  order: Order;
  branchName: string;
  currency: string;
  onClose: () => void;
}) {
  const closeButtonRef = useRef<HTMLButtonElement>(null);
  const resolvedBranchName = order.branchName ?? branchName;

  useEffect(() => {
    const previousFocus = document.activeElement as HTMLElement | null;
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    closeButtonRef.current?.focus();
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") onClose();
    };
    document.addEventListener("keydown", handleKeyDown);
    return () => {
      document.removeEventListener("keydown", handleKeyDown);
      document.body.style.overflow = previousOverflow;
      previousFocus?.focus();
    };
  }, [onClose]);

  return (
    <div className="fixed inset-0 z-50">
      <button
        type="button"
        aria-label="Закрыть подробности заказа"
        onClick={onClose}
        className="absolute inset-0 h-full w-full bg-coffee-900/35 backdrop-blur-[2px] dark:bg-black/65"
      />
      <aside
        role="dialog"
        aria-modal="true"
        aria-labelledby="order-details-title"
        className="absolute inset-y-0 right-0 flex w-full flex-col bg-cream-50 shadow-soft dark:bg-[#1d181b] sm:max-w-2xl"
      >
        <header className="flex shrink-0 items-center justify-between gap-4 border-b border-coffee-900/10 px-5 py-4 sm:px-6">
          <div className="min-w-0">
            <p className="text-xs font-semibold uppercase tracking-wide text-accent">
              Подробности заказа
            </p>
            <h2 id="order-details-title" className="mt-0.5 truncate text-xl">
              {order.number}
            </h2>
          </div>
          <button
            ref={closeButtonRef}
            type="button"
            onClick={onClose}
            title="Закрыть"
            className="focus-ring flex h-10 w-10 shrink-0 items-center justify-center rounded-full text-coffee-500 transition hover:bg-coffee-900/5"
          >
            <X className="h-5 w-5" />
          </button>
        </header>

        <div className="flex-1 overflow-y-auto px-5 py-5 sm:px-6">
          <section className="surface p-4 sm:p-5">
            <div className="flex flex-wrap items-center justify-between gap-3">
              <StatusBadge status={order.status} />
              <span className="text-sm text-coffee-500">{fullDate(order.createdAt)}</span>
            </div>
            <dl className="mt-5 grid gap-4 sm:grid-cols-2">
              <Detail label="Филиал" value={resolvedBranchName} />
              {order.branchAddress && (
                <Detail label="Адрес филиала" value={order.branchAddress} />
              )}
              <Detail label="Получение" value={ORDER_TYPE_LABELS[order.type]} />
              {order.readyTime && <Detail label="Время готовности" value={order.readyTime} />}
              {order.paymentMethod && (
                <Detail
                  label="Способ оплаты"
                  value={displayEnum(order.paymentMethod, PAYMENT_METHOD_LABELS)}
                />
              )}
              {order.paymentStatus && (
                <Detail
                  label="Статус оплаты"
                  value={displayEnum(order.paymentStatus, PAYMENT_STATUS_LABELS)}
                />
              )}
            </dl>
            <div className="mt-4 grid gap-3 border-t border-coffee-900/10 pt-4 sm:grid-cols-2">
              <div className="flex items-start gap-2.5">
                <UserRound className="mt-0.5 h-4 w-4 shrink-0 text-accent" />
                <div>
                  <p className="text-xs text-coffee-500">Клиент</p>
                  <p className="mt-0.5 text-sm font-semibold text-coffee-900">
                    {order.customerName}
                  </p>
                </div>
              </div>
              {order.customerPhone && (
                <div className="flex items-start gap-2.5">
                  <Phone className="mt-0.5 h-4 w-4 shrink-0 text-accent" />
                  <div>
                    <p className="text-xs text-coffee-500">Телефон</p>
                    <a
                      href={`tel:${order.customerPhone}`}
                      className="focus-ring mt-0.5 inline-block rounded text-sm font-semibold text-coffee-900 hover:text-accent"
                    >
                      {order.customerPhone}
                    </a>
                  </div>
                </div>
              )}
            </div>
          </section>

          {order.comment && (
            <section className="mt-4 rounded-2xl border border-accent/20 bg-accent/5 p-4">
              <h3 className="flex items-center gap-2 text-sm font-semibold text-coffee-900">
                <MessageSquareText className="h-4 w-4 text-accent" />
                Комментарий к заказу
              </h3>
              <p className="mt-2 whitespace-pre-wrap text-sm leading-relaxed text-coffee-700">
                {order.comment}
              </p>
            </section>
          )}

          <section className="mt-6">
            <div className="flex items-center justify-between gap-3">
              <h3 className="flex items-center gap-2 text-base">
                <ReceiptText className="h-5 w-5 text-accent" />
                Состав заказа
              </h3>
              <span className="text-xs font-medium text-coffee-500">
                {order.items.length} поз.
              </span>
            </div>

            {order.items.length === 0 ? (
              <p className="surface mt-3 px-4 py-8 text-center text-sm text-coffee-500">
                Сервер не передал состав заказа.
              </p>
            ) : (
              <ol className="mt-3 space-y-3">
                {order.items.map((item, index) => (
                  <li key={`${item.productId ?? item.name}-${index}`} className="surface p-4">
                    <div className="flex gap-3">
                      <ProductImage src={item.imageUrl} name={item.name} />
                      <div className="min-w-0 flex-1">
                        <div className="flex items-start justify-between gap-3">
                          <div className="min-w-0">
                            <p className="text-sm font-semibold text-coffee-900">
                              {item.quantity} × {item.name || "Название не передано"}
                            </p>
                            {item.description && (
                              <p className="mt-1 text-xs leading-relaxed text-coffee-500">
                                {item.description}
                              </p>
                            )}
                          </div>
                          <p className="shrink-0 text-sm font-semibold text-coffee-900">
                            {formatCurrency(item.lineTotal, currency)}
                          </p>
                        </div>

                        <dl className="mt-3 grid gap-x-4 gap-y-2 text-xs sm:grid-cols-2">
                          {item.size && (
                            <div className="flex justify-between gap-2 sm:block">
                              <dt className="text-coffee-500">Размер</dt>
                              <dd className="font-medium text-coffee-700">{item.size}</dd>
                            </div>
                          )}
                          {item.sugarPercent !== undefined && (
                            <div className="flex justify-between gap-2 sm:block">
                              <dt className="text-coffee-500">Сахар</dt>
                              <dd className="font-medium text-coffee-700">{item.sugarPercent}%</dd>
                            </div>
                          )}
                          {item.ice && (
                            <div className="flex justify-between gap-2 sm:block">
                              <dt className="text-coffee-500">Лёд</dt>
                              <dd className="font-medium text-coffee-700">
                                {displayEnum(item.ice, ICE_LABELS)}
                              </dd>
                            </div>
                          )}
                          {item.unitPrice !== undefined && (
                            <div className="flex justify-between gap-2 sm:block">
                              <dt className="text-coffee-500">За единицу</dt>
                              <dd className="font-medium text-coffee-700">
                                {formatCurrency(item.unitPrice, currency)}
                              </dd>
                            </div>
                          )}
                        </dl>
                        {item.toppings && item.toppings.length > 0 && (
                          <div className="mt-3 border-t border-coffee-900/5 pt-3">
                            <p className="text-xs text-coffee-500">Топпинги</p>
                            <div className="mt-1.5 flex flex-wrap gap-1.5">
                              {item.toppings.map((topping, toppingIndex) => (
                                <span
                                  key={`${topping.id ?? topping.name}-${toppingIndex}`}
                                  className="rounded-full bg-coffee-900/5 px-2.5 py-1 text-xs font-medium text-coffee-700"
                                >
                                  {topping.name}
                                  {topping.priceDelta !== undefined && topping.priceDelta !== 0
                                    ? ` · ${topping.priceDelta > 0 ? "+" : "−"}${formatCurrency(Math.abs(topping.priceDelta), currency)}`
                                    : ""}
                                </span>
                              ))}
                            </div>
                          </div>
                        )}
                      </div>
                    </div>
                  </li>
                ))}
              </ol>
            )}
          </section>

          <section className="surface mt-6 p-4 sm:p-5">
            <h3 className="flex items-center gap-2 text-base">
              <CreditCard className="h-5 w-5 text-accent" />
              Итог
            </h3>
            <dl className="mt-4 space-y-2 text-sm">
              {order.subtotal !== undefined && (
                <div className="flex justify-between gap-4 text-coffee-700">
                  <dt>Сумма позиций</dt>
                  <dd>{formatCurrency(order.subtotal, currency)}</dd>
                </div>
              )}
              {order.discount !== undefined && order.discount !== 0 && (
                <div className="flex justify-between gap-4 text-coffee-700">
                  <dt>Скидка</dt>
                  <dd>−{formatCurrency(Math.abs(order.discount), currency)}</dd>
                </div>
              )}
              {order.pointsUsed !== undefined && (
                <div className="flex justify-between gap-4 text-coffee-700">
                  <dt className="flex items-center gap-1.5">
                    <Coins className="h-4 w-4 text-accent" />
                    Списано баллов
                  </dt>
                  <dd>{order.pointsUsed}</dd>
                </div>
              )}
              {order.promoCode && (
                <div className="flex justify-between gap-4 text-coffee-700">
                  <dt>Промокод</dt>
                  <dd className="font-medium">{order.promoCode}</dd>
                </div>
              )}
              <div className="flex justify-between gap-4 border-t border-coffee-900/10 pt-3 text-base font-semibold text-coffee-900">
                <dt>К оплате</dt>
                <dd>{formatCurrency(order.total, currency)}</dd>
              </div>
              {order.pointsEarned !== undefined && (
                <div className="flex justify-between gap-4 text-sm text-accent">
                  <dt>Начислено баллов</dt>
                  <dd>+{order.pointsEarned}</dd>
                </div>
              )}
            </dl>
          </section>

          <div className="mt-5 grid gap-3 text-xs text-coffee-500 sm:grid-cols-2">
            <span className="flex items-center gap-1.5">
              <MapPin className="h-3.5 w-3.5" /> {resolvedBranchName}
            </span>
            <span className="flex items-center gap-1.5 sm:justify-end">
              <CalendarClock className="h-3.5 w-3.5" /> {fullDate(order.createdAt)}
            </span>
          </div>
        </div>

        <footer className="shrink-0 border-t border-coffee-900/10 px-5 py-4 sm:px-6">
          <button
            type="button"
            onClick={onClose}
            className="focus-ring h-11 w-full rounded-full bg-accent px-5 text-sm font-semibold text-white transition hover:opacity-90"
          >
            Закрыть
          </button>
        </footer>
      </aside>
    </div>
  );
}
