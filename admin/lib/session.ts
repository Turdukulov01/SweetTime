"use client";

// Сессия сотрудника на боевом JWT (backend/api).
//
// login(email, password) → POST /api/auth/staff/login (компанию сервер определяет
// по email). Успех → {accessToken, refreshToken, user} в localStorage; companyId
// берётся ИЗ ПРОФИЛЯ ТОКЕНА, а не из локальных списков.
// Сессия переживает перезагрузку страницы: источник истины — localStorage.

import { useEffect, useState } from "react";
import { ApiError, apiStaffLogin, describeApiError } from "@/lib/api";
import {
  clearStoredSession,
  readStoredSession,
  subscribeSession,
  writeStoredSession,
  type StoredSession
} from "@/lib/auth-storage";
import type { AdminUser } from "@/lib/types";

export type SessionStatus = "loading" | "authenticated" | "unauthenticated";

export interface SessionState {
  status: SessionStatus;
  session: StoredSession | null;
  user: AdminUser | null;
  /** Компания сотрудника из токена — ключ скоупа всех данных админки */
  companyId: string | null;
}

export type LoginResult = { ok: true } | { ok: false; error: string };

/** Вход сотрудника. При ошибке возвращает текст для формы (по-русски). */
export async function login(
  email: string,
  password: string
): Promise<LoginResult> {
  try {
    const { accessToken, refreshToken, user } = await apiStaffLogin(
      email,
      password
    );
    writeStoredSession({ accessToken, refreshToken, user });
    return { ok: true };
  } catch (error) {
    if (error instanceof ApiError && error.status === 401) {
      return { ok: false, error: "Неверный email или пароль" };
    }
    return { ok: false, error: describeApiError(error) };
  }
}

export function logout(): void {
  clearStoredSession();
}

function resolveState(): SessionState {
  const session = readStoredSession();
  if (!session) {
    return {
      status: "unauthenticated",
      session: null,
      user: null,
      companyId: null
    };
  }
  return {
    status: "authenticated",
    session,
    user: session.user,
    companyId: session.user.companyId
  };
}

/**
 * Хук текущей сессии. До монтирования — status: "loading" (localStorage при SSR
 * недоступен), затем реагирует на login/logout в этой и других вкладках.
 */
export function useSession(): SessionState {
  const [state, setState] = useState<SessionState>({
    status: "loading",
    session: null,
    user: null,
    companyId: null
  });

  useEffect(() => {
    const sync = () => setState(resolveState());
    sync();
    return subscribeSession(sync);
  }, []);

  return state;
}
