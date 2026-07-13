"use client";

// Клиентская демо-сессия в localStorage. Настоящая авторизация (JWT) — на
// этапе Backend; интерфейс модуля сохранится: login/logout/useSession.

import { useEffect, useState } from "react";
import { authenticate, getAdminUser, getCompanyData } from "@/lib/data";
import type { AdminUser, Company, Role } from "@/lib/types";

const STORAGE_KEY = "sweettime-admin-session";
const SESSION_EVENT = "sweettime-admin-session-changed";

export interface SessionData {
  userId: string;
  companyId: string;
  role: Role;
}

export type SessionStatus = "loading" | "authenticated" | "unauthenticated";

export interface SessionState {
  status: SessionStatus;
  session: SessionData | null;
  user: AdminUser | null;
  company: Company | null;
}

function readSession(): SessionData | null {
  if (typeof window === "undefined") return null;
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as SessionData;
    // Сессия валидна только если пользователь существует и не сменил компанию
    const user = getAdminUser(parsed.userId);
    if (!user || user.companyId !== parsed.companyId) return null;
    return parsed;
  } catch {
    return null;
  }
}

function notifyChange(): void {
  window.dispatchEvent(new Event(SESSION_EVENT));
}

/** Демо-вход. Возвращает сессию или null при неверных данных. */
export function login(email: string, password: string): SessionData | null {
  const user = authenticate(email, password);
  if (!user) return null;
  const session: SessionData = {
    userId: user.id,
    companyId: user.companyId,
    role: user.role
  };
  window.localStorage.setItem(STORAGE_KEY, JSON.stringify(session));
  notifyChange();
  return session;
}

export function logout(): void {
  window.localStorage.removeItem(STORAGE_KEY);
  notifyChange();
}

function resolveState(): SessionState {
  const session = readSession();
  if (!session) {
    return {
      status: "unauthenticated",
      session: null,
      user: null,
      company: null
    };
  }
  const user = getAdminUser(session.userId);
  const company = getCompanyData(session.companyId)?.company ?? null;
  if (!user || !company) {
    return {
      status: "unauthenticated",
      session: null,
      user: null,
      company: null
    };
  }
  return { status: "authenticated", session, user, company };
}

/**
 * Хук текущей сессии. До монтирования возвращает status: "loading"
 * (localStorage недоступен при SSR), затем реагирует на login/logout
 * в этой и других вкладках.
 */
export function useSession(): SessionState {
  const [state, setState] = useState<SessionState>({
    status: "loading",
    session: null,
    user: null,
    company: null
  });

  useEffect(() => {
    const sync = () => setState(resolveState());
    sync();
    window.addEventListener(SESSION_EVENT, sync);
    window.addEventListener("storage", sync);
    return () => {
      window.removeEventListener(SESSION_EVENT, sync);
      window.removeEventListener("storage", sync);
    };
  }, []);

  return state;
}
