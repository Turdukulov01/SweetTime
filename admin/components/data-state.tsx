"use client";

// Экраны состояния данных компании: загрузка и честная ошибка API.
// Мок-подмены нет: если сервер не ответил, оператор видит ошибку, а не
// «красивые» неверные цифры.

import { LogOut, RefreshCw, TriangleAlert } from "lucide-react";

export function DataLoading({ message }: { message: string }) {
  return (
    <div className="flex min-h-screen items-center justify-center px-4">
      <p className="text-sm text-coffee-500">{message}</p>
    </div>
  );
}

export function DataError({
  message,
  onRetry,
  onLogout
}: {
  message: string;
  onRetry: () => void;
  onLogout: () => void;
}) {
  return (
    <div className="flex min-h-screen items-center justify-center px-4">
      <div className="surface w-full max-w-md px-6 py-6 text-center">
        <span className="mx-auto flex h-11 w-11 items-center justify-center rounded-full bg-red-100 text-red-600">
          <TriangleAlert className="h-5 w-5" />
        </span>
        <h1 className="mt-3 text-lg">Не удалось загрузить данные компании</h1>
        <p role="alert" className="mt-2 text-sm text-coffee-500">
          {message}
        </p>
        <div className="mt-5 flex justify-center gap-2">
          <button
            type="button"
            onClick={onRetry}
            className="focus-ring flex h-10 items-center gap-2 rounded-full bg-candy-500 px-5 text-sm font-semibold text-white transition hover:bg-candy-700"
          >
            <RefreshCw className="h-4 w-4" />
            Повторить
          </button>
          <button
            type="button"
            onClick={onLogout}
            className="focus-ring flex h-10 items-center gap-2 rounded-full border border-coffee-900/15 px-5 text-sm font-medium text-coffee-700 transition hover:border-candy-500 hover:text-candy-500"
          >
            <LogOut className="h-4 w-4" />
            Выйти
          </button>
        </div>
      </div>
    </div>
  );
}

/** Плавающий тост об ошибке действия (например 403 «Недостаточно прав») */
export function ErrorToast({ message }: { message: string }) {
  return (
    <div
      role="alert"
      className="fixed bottom-6 right-6 z-50 flex items-center gap-2 rounded-full bg-red-600 px-5 py-2.5 text-sm font-medium text-white shadow-soft"
    >
      <TriangleAlert className="h-4 w-4" />
      {message}
    </div>
  );
}
