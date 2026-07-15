"use client";

// Хранилище JWT-сессии сотрудника (localStorage) + подписка на её изменения.
//
// Отдельный модуль, чтобы разорвать цикл импортов: `lib/api.ts` читает токен и
// обновляет пару токенов, `lib/session.ts` пишет/чистит сессию и отдаёт её UI.
// Оба зависят от этого модуля, а не друг от друга.
//
// Токены живут в localStorage, поэтому сессия переживает перезагрузку страницы.

import type { AdminUser, Role } from "@/lib/types";

const STORAGE_KEY = "sweettime-admin-session";
const SESSION_EVENT = "sweettime-admin-session-changed";

const ROLES: Role[] = ["owner", "manager", "barista"];

/** Сохранённая сессия: пара токенов + профиль из ответа /auth/staff/login */
export interface StoredSession {
  accessToken: string;
  refreshToken: string;
  user: AdminUser;
}

/**
 * Разбор профиля сотрудника. branchId допускаем и как null (так его отдаёт API),
 * наружу нормализуем в undefined — иначе валидная сессия «терялась» бы молча.
 */
function parseAdminUser(value: unknown): AdminUser | null {
  if (typeof value !== "object" || value === null) return null;
  const u = value as Record<string, unknown>;
  const ok =
    typeof u.id === "string" &&
    typeof u.email === "string" &&
    typeof u.name === "string" &&
    typeof u.companyId === "string" &&
    u.companyId.length > 0 &&
    typeof u.role === "string" &&
    ROLES.includes(u.role as Role) &&
    (u.branchId === undefined ||
      u.branchId === null ||
      typeof u.branchId === "string");
  if (!ok) return null;
  return {
    id: u.id as string,
    email: u.email as string,
    name: u.name as string,
    role: u.role as Role,
    companyId: u.companyId as string,
    branchId: typeof u.branchId === "string" ? u.branchId : undefined
  };
}

function parseStoredSession(value: unknown): StoredSession | null {
  if (typeof value !== "object" || value === null) return null;
  const s = value as Record<string, unknown>;
  if (
    typeof s.accessToken !== "string" ||
    s.accessToken.length === 0 ||
    typeof s.refreshToken !== "string" ||
    s.refreshToken.length === 0
  ) {
    return null;
  }
  const user = parseAdminUser(s.user);
  if (!user) return null;
  return { accessToken: s.accessToken, refreshToken: s.refreshToken, user };
}

/**
 * Текущая сессия из localStorage или null. Данные чужого/старого формата
 * (например демо-сессия прошлых версий) не проходят разбор → null.
 */
export function readStoredSession(): StoredSession | null {
  if (typeof window === "undefined") return null;
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY);
    if (!raw) return null;
    return parseStoredSession(JSON.parse(raw));
  } catch {
    return null;
  }
}

export function writeStoredSession(session: StoredSession): void {
  if (typeof window === "undefined") return;
  window.localStorage.setItem(STORAGE_KEY, JSON.stringify(session));
  notifySessionChange();
}

/**
 * Обновление пары токенов после refresh. Пользователь и компания не меняются,
 * поэтому подписчиков не дёргаем — лишний ре-рендер не нужен.
 */
export function updateStoredTokens(
  accessToken: string,
  refreshToken: string
): void {
  if (typeof window === "undefined") return;
  const current = readStoredSession();
  if (!current) return;
  window.localStorage.setItem(
    STORAGE_KEY,
    JSON.stringify({ ...current, accessToken, refreshToken })
  );
}

export function clearStoredSession(): void {
  if (typeof window === "undefined") return;
  window.localStorage.removeItem(STORAGE_KEY);
  notifySessionChange();
}

export function notifySessionChange(): void {
  if (typeof window === "undefined") return;
  window.dispatchEvent(new Event(SESSION_EVENT));
}

/** Подписка на вход/выход в этой и других вкладках */
export function subscribeSession(listener: () => void): () => void {
  window.addEventListener(SESSION_EVENT, listener);
  window.addEventListener("storage", listener);
  return () => {
    window.removeEventListener(SESSION_EVENT, listener);
    window.removeEventListener("storage", listener);
  };
}
