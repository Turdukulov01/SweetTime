"use client";

// Очередь заказов компании.
//
// Источник — ТОЛЬКО боевой API: GET /api/companies/{cid}/orders требует
// Bearer-токен стаффа (его подставляет lib/api). Инициализация + поллинг раз в
// 5 секунд. setStatus шлёт PATCH .../orders/{id}/status; при ошибке (409 —
// недопустимый переход, 403 — недостаточно прав, сеть) статус откатывается и
// показывается тост. Мок-подмены нет: если API недоступен — пустая очередь и
// честное сообщение об ошибке.
//
// Провайдер монтируется в shell с key={companyId}, поэтому при перелогине
// стор пересоздаётся и данные чужой компании не «протекают».

import {
  createContext,
  createElement,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode
} from "react";
import {
  ApiError,
  apiFetchOrders,
  apiPatchOrderStatus,
  describeApiError
} from "@/lib/api";
import type { Order, OrderStatus } from "@/lib/types";

const POLL_INTERVAL_MS = 5000;

interface OrdersContextValue {
  orders: Order[];
  setStatus: (orderId: string, status: OrderStatus) => void;
  /** Текст последней ошибки (загрузка или сохранение статуса), null — нет */
  errorMessage: string | null;
  /** Идёт первая загрузка очереди */
  loading: boolean;
  /** Очередь ни разу не загрузилась (API недоступен) — показать пустое состояние */
  loadFailed: boolean;
}

const OrdersContext = createContext<OrdersContextValue | null>(null);

export function OrdersProvider({
  companyId,
  children
}: {
  companyId: string;
  children: ReactNode;
}) {
  const [orders, setOrders] = useState<Order[]>([]);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [loadFailed, setLoadFailed] = useState(false);

  const errorTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const showError = useCallback((message: string) => {
    setErrorMessage(message);
    if (errorTimerRef.current) clearTimeout(errorTimerRef.current);
    errorTimerRef.current = setTimeout(() => setErrorMessage(null), 4000);
  }, []);

  // Инициализация из API + поллинг каждые 5 секунд
  useEffect(() => {
    let cancelled = false;
    let loadedOnce = false;
    setLoading(true);
    setLoadFailed(false);

    const load = async () => {
      try {
        const fresh = await apiFetchOrders(companyId);
        if (cancelled) return;
        loadedOnce = true;
        setOrders(fresh);
        setLoadFailed(false);
      } catch (error) {
        if (cancelled) return;
        // Первая загрузка не удалась — честно показываем это, а не моки
        if (!loadedOnce) {
          setLoadFailed(true);
          setErrorMessage(describeApiError(error));
        }
      } finally {
        if (!cancelled) setLoading(false);
      }
    };

    void load();
    const timer = setInterval(() => void load(), POLL_INTERVAL_MS);
    return () => {
      cancelled = true;
      clearInterval(timer);
      if (errorTimerRef.current) clearTimeout(errorTimerRef.current);
    };
  }, [companyId]);

  const setStatus = useCallback(
    (orderId: string, status: OrderStatus) => {
      // Оптимистичное обновление; прежний статус — для отката
      let prevStatus: OrderStatus | null = null;
      setOrders((prev) =>
        prev.map((order) => {
          if (order.id !== orderId) return order;
          prevStatus = order.status;
          return { ...order, status };
        })
      );

      apiPatchOrderStatus(companyId, orderId, status)
        .then((updated) => {
          setOrders((prev) =>
            prev.map((order) => (order.id === orderId ? updated : order))
          );
        })
        .catch((error: unknown) => {
          // Откат к прежнему статусу
          setOrders((prev) =>
            prev.map((order) =>
              order.id === orderId && prevStatus !== null
                ? { ...order, status: prevStatus }
                : order
            )
          );
          const detail =
            error instanceof ApiError && error.status === 409
              ? `Сервер отклонил переход: ${error.message}`
              : describeApiError(error);
          showError(detail);
        });
    },
    [companyId, showError]
  );

  const value = useMemo(
    () => ({ orders, setStatus, errorMessage, loading, loadFailed }),
    [orders, setStatus, errorMessage, loading, loadFailed]
  );

  return createElement(OrdersContext.Provider, { value }, children);
}

export function useOrders(): OrdersContextValue {
  const ctx = useContext(OrdersContext);
  if (!ctx) {
    throw new Error("useOrders должен вызываться внутри <OrdersProvider>");
  }
  return ctx;
}
