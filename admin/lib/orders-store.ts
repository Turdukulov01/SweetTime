"use client";

// Очередь заказов компании.
// При заданном NEXT_PUBLIC_API_URL: инициализация из API + поллинг каждые
// 5 секунд; setStatus шлёт PATCH .../orders/{id}/status — при ошибке (например
// 409, недопустимый переход) статус откатывается и показывается тост.
// Без API — прежние мок-данные.
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
  apiEnabled,
  apiFetchOrders,
  apiPatchOrderStatus
} from "@/lib/api";
import { getCompanyData } from "@/lib/data";
import type { Order, OrderStatus } from "@/lib/types";

const POLL_INTERVAL_MS = 5000;

interface OrdersContextValue {
  orders: Order[];
  setStatus: (orderId: string, status: OrderStatus) => void;
  /** Текст последней ошибки сохранения статуса (для тоста), null — нет */
  errorMessage: string | null;
}

const OrdersContext = createContext<OrdersContextValue | null>(null);

export function OrdersProvider({
  companyId,
  children
}: {
  companyId: string;
  children: ReactNode;
}) {
  const [orders, setOrders] = useState<Order[]>(
    () => getCompanyData(companyId)?.orders ?? []
  );
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const apiModeRef = useRef(false);
  const warnedRef = useRef(false);
  const errorTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const showError = useCallback((message: string) => {
    setErrorMessage(message);
    if (errorTimerRef.current) clearTimeout(errorTimerRef.current);
    errorTimerRef.current = setTimeout(() => setErrorMessage(null), 4000);
  }, []);

  // Инициализация из API + поллинг каждые 5 секунд
  useEffect(() => {
    if (!apiEnabled) return;
    let cancelled = false;

    const load = async () => {
      try {
        const fresh = await apiFetchOrders(companyId);
        if (cancelled) return;
        apiModeRef.current = true;
        setOrders(fresh);
      } catch (error) {
        if (!warnedRef.current) {
          warnedRef.current = true;
          console.warn(
            "[admin] API заказов недоступен, работаем на мок-данных:",
            error instanceof Error ? error.message : error
          );
        }
      }
    };

    load();
    const timer = setInterval(load, POLL_INTERVAL_MS);
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

      if (!apiModeRef.current) return;

      apiPatchOrderStatus(companyId, orderId, status)
        .then((updated) => {
          setOrders((prev) =>
            prev.map((order) => (order.id === orderId ? updated : order))
          );
        })
        .catch((error) => {
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
              : `Не удалось сохранить статус: ${
                  error instanceof Error ? error.message : "ошибка сети"
                }`;
          showError(detail);
        });
    },
    [companyId, showError]
  );

  const value = useMemo(
    () => ({ orders, setStatus, errorMessage }),
    [orders, setStatus, errorMessage]
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
