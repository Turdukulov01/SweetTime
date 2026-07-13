"use client";

// Переключатель светлой/тёмной темы: класс `dark` на <html>, выбор в
// localStorage("admin-theme"). Начальное состояние применяет инлайн-скрипт
// в app/layout.tsx (до первого рендера, чтобы не мигало).
// Иконки переключаются чистым CSS (dark:hidden / dark:block) —
// без клиентского состояния и hydration-рассинхрона.

import { Moon, Sun } from "lucide-react";

export const THEME_STORAGE_KEY = "admin-theme";

export function ThemeToggle() {
  function toggle() {
    const isDark = document.documentElement.classList.toggle("dark");
    try {
      window.localStorage.setItem(THEME_STORAGE_KEY, isDark ? "dark" : "light");
    } catch {
      // localStorage недоступен — тема просто не переживёт перезагрузку
    }
  }

  return (
    <button
      type="button"
      onClick={toggle}
      title="Переключить тему"
      aria-label="Переключить тему"
      className="focus-ring flex h-9 w-9 items-center justify-center rounded-full border border-coffee-900/15 text-coffee-700 transition hover:border-accent hover:text-accent"
    >
      <Moon className="h-4 w-4 dark:hidden" />
      <Sun className="hidden h-4 w-4 dark:block" />
    </button>
  );
}
