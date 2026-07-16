"use client";

// Очередь заказов компании.
//
// Источник — ТОЛЬКО боевой API: GET /api/companies/{cid}/orders требует
// Bearer-токен стаффа (его подставляет lib/api). SSE почти мгновенно будит GET-сверку,
// последовательный polling остаётся резервным. setStatus шлёт PATCH .../orders/{id}/status; при ошибке (409 —
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
  apiWatchOrderEvents,
  describeApiError
} from "@/lib/api";
import type { Order, OrderStatus } from "@/lib/types";

const POLL_INTERVAL_MS = 15000;
const HIDDEN_POLL_INTERVAL_MS = 60000;
const STREAM_RECONNECT_DELAYS_MS = [1000, 2000, 5000, 10000] as const;

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
  const refreshOrdersRef = useRef<() => void>(() => undefined);

  const showError = useCallback((message: string) => {
    setErrorMessage(message);
    if (errorTimerRef.current) clearTimeout(errorTimerRef.current);
    errorTimerRef.current = setTimeout(() => setErrorMessage(null), 4000);
  }, []);

  // Инициализация + последовательный polling: следующий GET начинается только
  // после завершения предыдущего. Focus/online/visible запускают сверку сразу.
  useEffect(() => {
    let cancelled = false;
    let loadedOnce = false;
    let inFlight = false;
    let rerunRequested = false;
    let timer: ReturnType<typeof setTimeout> | null = null;
    setLoading(true);
    setLoadFailed(false);

    const schedule = (delay?: number) => {
      if (cancelled) return;
      if (timer) clearTimeout(timer);
      const interval =
        delay ??
        (document.visibilityState === "visible"
          ? POLL_INTERVAL_MS
          : HIDDEN_POLL_INTERVAL_MS);
      timer = setTimeout(() => void load(), interval);
    };

    const load = async () => {
      if (cancelled) return;
      if (inFlight) {
        rerunRequested = true;
        return;
      }
      inFlight = true;
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
        } else {
          showError(
            `Не удалось обновить очередь. Показываем последние данные: ${describeApiError(error)}`
          );
        }
      } finally {
        inFlight = false;
        if (!cancelled) {
          setLoading(false);
          if (rerunRequested) {
            rerunRequested = false;
            schedule(0);
          } else {
            schedule();
          }
        }
      }
    };

    const refreshNow = () => {
      if (timer) clearTimeout(timer);
      void load();
    };
    refreshOrdersRef.current = refreshNow;
    const handleVisibility = () => {
      if (document.visibilityState === "visible") refreshNow();
    };

    void load();
    window.addEventListener("focus", refreshNow);
    window.addEventListener("online", refreshNow);
    document.addEventListener("visibilitychange", handleVisibility);
    return () => {
      cancelled = true;
      if (timer) clearTimeout(timer);
      window.removeEventListener("focus", refreshNow);
      window.removeEventListener("online", refreshNow);
      document.removeEventListener("visibilitychange", handleVisibility);
      if (refreshOrdersRef.current === refreshNow) {
        refreshOrdersRef.current = () => undefined;
      }
      if (errorTimerRef.current) clearTimeout(errorTimerRef.current);
    };
  }, [companyId, showError]);

  // Быстрый канал: SSE несёт только tenant-scoped wake-up. После каждого
  // сигнала перечитываем PostgreSQL через обычный GET; polling выше страхует
  // рестарт, потерянное событие и долгий сетевой разрыв.
  useEffect(() => {
    let cancelled = false;
    let stream: AbortController | null = null;
    let reconnectTimer: ReturnType<typeof setTimeout> | null = null;
    let reconnectAttempt = 0;
    let lastEventId: string | undefined;

    const clearReconnect = () => {
      if (reconnectTimer) clearTimeout(reconnectTimer);
      reconnectTimer = null;
    };

    const stop = () => {
      clearReconnect();
      const active = stream;
      stream = null;
      active?.abort();
    };

    const scheduleReconnect = () => {
      if (
        cancelled ||
        document.visibilityState !== "visible" ||
        !navigator.onLine
      ) {
        return;
      }
      const index = Math.min(
        reconnectAttempt,
        STREAM_RECONNECT_DELAYS_MS.length - 1
      );
      reconnectAttempt += 1;
      reconnectTimer = setTimeout(connect, STREAM_RECONNECT_DELAYS_MS[index]);
    };

    const connect = () => {
      if (
        cancelled ||
        stream !== null ||
        document.visibilityState !== "visible" ||
        !navigator.onLine
      ) {
        return;
      }
      clearReconnect();
      const controller = new AbortController();
      stream = controller;
      void apiWatchOrderEvents(companyId, {
        signal: controller.signal,
        lastEventId,
        onNotice: (notice) => {
          if (notice.id) lastEventId = notice.id;
          reconnectAttempt = 0;
          refreshOrdersRef.current();
        }
      })
        .catch(() => {
          // GET reconciliation owns user-visible availability errors.
        })
        .finally(() => {
          if (stream !== controller) return;
          stream = null;
          if (!controller.signal.aborted) scheduleReconnect();
        });
    };

    const handleVisibility = () => {
      if (document.visibilityState === "visible") {
        refreshOrdersRef.current();
        connect();
      } else {
        stop();
      }
    };
    const handleOnline = () => {
      reconnectAttempt = 0;
      refreshOrdersRef.current();
      connect();
    };
    const handleOffline = () => stop();

    connect();
    document.addEventListener("visibilitychange", handleVisibility);
    window.addEventListener("online", handleOnline);
    window.addEventListener("offline", handleOffline);
    return () => {
      cancelled = true;
      stop();
      document.removeEventListener("visibilitychange", handleVisibility);
      window.removeEventListener("online", handleOnline);
      window.removeEventListener("offline", handleOffline);
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
