import { clsx, type ClassValue } from "clsx";

export function cn(...inputs: ClassValue[]): string {
  return clsx(inputs);
}

/** Формат суммы: "1 234 сом" (пробел-разделитель тысяч, без копеек). */
export function formatCurrency(amount: number, currency = "сом"): string {
  const formatted = new Intl.NumberFormat("ru-RU", {
    maximumFractionDigits: 0
  })
    .format(amount)
    .replace(/ /g, " ");
  return `${formatted} ${currency}`;
}

/** Русская плюрализация: pluralRu(3, "размер", "размера", "размеров"). */
export function pluralRu(
  count: number,
  one: string,
  few: string,
  many: string
): string {
  const mod10 = Math.abs(count) % 10;
  const mod100 = Math.abs(count) % 100;
  if (mod10 === 1 && mod100 !== 11) return one;
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return few;
  return many;
}

/** Дата: "15.07.2026". */
export function formatDate(iso: string): string {
  return new Date(iso).toLocaleDateString("ru-RU", {
    day: "2-digit",
    month: "2-digit",
    year: "numeric"
  });
}

/** Время заказа: "14:05". */
export function formatTime(iso: string): string {
  const d = new Date(iso);
  return d.toLocaleTimeString("ru-RU", { hour: "2-digit", minute: "2-digit" });
}

/** Дата и время для таблиц: "сегодня 14:05" или "10.07 18:40". */
export function formatDateTime(iso: string): string {
  const d = new Date(iso);
  const now = new Date();
  const sameDay =
    d.getFullYear() === now.getFullYear() &&
    d.getMonth() === now.getMonth() &&
    d.getDate() === now.getDate();
  if (sameDay) return `сегодня ${formatTime(iso)}`;
  const date = d.toLocaleDateString("ru-RU", {
    day: "2-digit",
    month: "2-digit"
  });
  return `${date} ${formatTime(iso)}`;
}

/** ISO-строка приходится на сегодняшний день? */
export function isToday(iso: string): boolean {
  const d = new Date(iso);
  const now = new Date();
  return (
    d.getFullYear() === now.getFullYear() &&
    d.getMonth() === now.getMonth() &&
    d.getDate() === now.getDate()
  );
}

/** "#FF5C9A" → "255 92 154" (для CSS-переменной --accent). */
export function hexToRgbTriplet(hex: string): string {
  const clean = hex.replace("#", "");
  const value = parseInt(
    clean.length === 3
      ? clean
          .split("")
          .map((c) => c + c)
          .join("")
      : clean,
    16
  );
  if (Number.isNaN(value)) return "255 92 154";
  return `${(value >> 16) & 255} ${(value >> 8) & 255} ${value & 255}`;
}
