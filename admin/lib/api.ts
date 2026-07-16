"use client";

// Fetch-клиент боевого API (backend/api, JWT). Все доменные ручки тенант-скоупнуты:
// /api/companies/{companyId}/...
//
// Авторизация: в каждый запрос подставляется `Authorization: Bearer <accessToken>`
// из localStorage-сессии (lib/auth-storage). На 401 клиент один раз пробует
// обновить пару токенов через /auth/refresh и повторяет запрос; если refresh не
// удался — сессия чистится и пользователь уходит на /login.
//
// Ошибки НЕ глотаются: каждая неуспешная ручка бросает ApiError(status, detail),
// вызывающий код показывает её пользователю.

import { useSyncExternalStore } from "react";
import {
  clearStoredSession,
  readStoredSession,
  updateStoredTokens
} from "@/lib/auth-storage";
import {
  isIdempotentRead,
  READ_RETRY_DELAYS_MS,
  shouldRetryRead
} from "@/lib/api-retry";
import { drainSseFrames } from "@/lib/sse";
import type {
  AdminUser,
  Branch,
  Company,
  LocalizedText,
  NewsStory,
  NewsVisual,
  ContentMedia,
  ContentMediaType,
  ContentStory,
  StoryCollection,
  NewsPost,
  Order,
  PaymentMethod,
  OrderStatus,
  OrderType,
  Product,
  Promotion,
  Role
} from "@/lib/types";

const API_URL = (process.env.NEXT_PUBLIC_API_URL ?? "").replace(/\/+$/, "");

/** Задан ли адрес API (NEXT_PUBLIC_API_URL). Без него админка работать не может. */
export const apiEnabled = API_URL.length > 0;

export class ApiError extends Error {
  constructor(
    public readonly status: number,
    message: string
  ) {
    super(message);
    this.name = "ApiError";
  }
}

/** Человеческий текст ошибки для UI (русский, без технических подробностей) */
export function describeApiError(error: unknown): string {
  if (error instanceof ApiError) {
    if (error.status === 0) {
      return `API недоступен (${API_URL || "адрес не задан"}). Проверьте, что сервер запущен.`;
    }
    if (error.status === 401) return "Сессия истекла — войдите заново.";
    if (error.status === 403) return "Недостаточно прав";
    if (error.status === 409) return error.message || "Конфликт данных. Обновите страницу и повторите.";
    if (error.status === 413) return "Файл слишком большой.";
    if (error.status === 415) return "Формат файла не поддерживается.";
    if (error.status === 422) return error.message || "Проверьте заполненные поля.";
    if (error.status >= 500) {
      return "Сервер временно не смог обработать запрос. Повторите через несколько секунд.";
    }
    return error.message;
  }
  return error instanceof Error ? error.message : "Неизвестная ошибка";
}

// ---------------------------------------------------------------------------
// Статус API для индикатора в topbar: результат последнего запроса
// ---------------------------------------------------------------------------

export type ApiStatus = "off" | "unknown" | "live" | "down";

let currentStatus: ApiStatus = apiEnabled ? "unknown" : "off";
const listeners = new Set<() => void>();

function setApiStatus(next: ApiStatus): void {
  if (currentStatus === next) return;
  currentStatus = next;
  listeners.forEach((listener) => listener());
}

function subscribe(listener: () => void): () => void {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

/** Хук статуса API: "live" — зелёная точка, остальное — серая */
export function useApiStatus(): ApiStatus {
  return useSyncExternalStore(
    subscribe,
    () => currentStatus,
    () => (apiEnabled ? "unknown" : "off")
  );
}

// ---------------------------------------------------------------------------
// Базовый запрос: Bearer-токен, refresh на 401, разбор ошибок
// ---------------------------------------------------------------------------

/** Тело ошибки FastAPI: {"detail": "..."} */
async function toApiError(response: Response): Promise<ApiError> {
  let detail = `HTTP ${response.status}`;
  try {
    const body = (await response.json()) as { detail?: unknown };
    if (typeof body.detail === "string") detail = body.detail;
    if (Array.isArray(body.detail)) {
      const messages = body.detail
        .map((item) => {
          if (typeof item === "string") return item;
          if (typeof item === "object" && item !== null && "msg" in item) {
            return String((item as { msg: unknown }).msg);
          }
          return "";
        })
        .filter(Boolean);
      if (messages.length) detail = messages.join("; ");
    }
  } catch {
    // тело не JSON — оставляем HTTP-код
  }
  return new ApiError(response.status, detail);
}

async function sendRaw(path: string, init: RequestInit): Promise<Response> {
  const method = init.method ?? "GET";
  const retryDelays = isIdempotentRead(method) ? READ_RETRY_DELAYS_MS : [];

  for (let attempt = 0; attempt <= retryDelays.length; attempt += 1) {
    try {
      const response = await fetch(`${API_URL}${path}`, {
        ...init,
        cache: "no-store"
      });
      // Сервер ответил — он жив, даже если вернул ошибку уровня запроса.
      setApiStatus("live");
      if (
        attempt < retryDelays.length &&
        shouldRetryRead(method, response.status)
      ) {
        await new Promise((resolve) => setTimeout(resolve, retryDelays[attempt]));
        continue;
      }
      return response;
    } catch {
      if (attempt < retryDelays.length) {
        await new Promise((resolve) => setTimeout(resolve, retryDelays[attempt]));
        continue;
      }
      setApiStatus("down");
      throw new ApiError(0, "API недоступен");
    }
  }

  throw new ApiError(0, "API недоступен");
}

/** Обновление пары токенов. Параллельные 401 ждут один и тот же запрос. */
let refreshInFlight: Promise<boolean> | null = null;

function refreshTokens(): Promise<boolean> {
  if (refreshInFlight) return refreshInFlight;

  refreshInFlight = (async () => {
    const session = readStoredSession();
    if (!session) return false;
    try {
      const response = await fetch(
        `${API_URL}/api/companies/${session.user.companyId}/auth/refresh`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ refreshToken: session.refreshToken }),
          cache: "no-store"
        }
      );
      if (!response.ok) return false;
      const body = (await response.json()) as {
        accessToken?: unknown;
        refreshToken?: unknown;
      };
      if (
        typeof body.accessToken !== "string" ||
        typeof body.refreshToken !== "string"
      ) {
        return false;
      }
      updateStoredTokens(body.accessToken, body.refreshToken);
      return true;
    } catch {
      return false;
    }
  })();

  return refreshInFlight.finally(() => {
    refreshInFlight = null;
  });
}

/** Refresh не помог: чистим сессию и уводим на страницу входа. */
function forceLogout(): void {
  clearStoredSession();
  if (
    typeof window !== "undefined" &&
    window.location.pathname !== "/login"
  ) {
    window.location.replace("/login");
  }
}

/**
 * Запрос к API с авторизацией. На 401 — одна попытка refresh + повтор;
 * если и после этого 401 — logout и редирект на /login.
 */
async function authorizedFetch(
  path: string,
  init: RequestInit
): Promise<Response> {
  if (!apiEnabled) {
    throw new ApiError(0, "Адрес API не задан (NEXT_PUBLIC_API_URL)");
  }

  const send = () => {
    const headers = new Headers(init.headers);
    const isFormData =
      typeof FormData !== "undefined" && init.body instanceof FormData;
    if (init.body !== undefined && !isFormData && !headers.has("Content-Type")) {
      headers.set("Content-Type", "application/json");
    }
    const token = readStoredSession()?.accessToken;
    if (token) headers.set("Authorization", `Bearer ${token}`);
    return sendRaw(path, { ...init, headers });
  };

  const response = await send();
  if (response.status !== 401) return response;

  if (!(await refreshTokens())) {
    forceLogout();
    throw new ApiError(401, "Сессия истекла — войдите заново.");
  }

  const retried = await send();
  if (retried.status === 401) {
    forceLogout();
    throw new ApiError(401, "Сессия истекла — войдите заново.");
  }
  return retried;
}

async function request<T>(path: string, init: RequestInit = {}): Promise<T> {
  const response = await authorizedFetch(path, init);
  if (!response.ok) throw await toApiError(response);
  return (await response.json()) as T;
}

/** DELETE-запрос без тела ответа (сервер отвечает 204 No Content). */
async function requestVoid(path: string, method = "DELETE"): Promise<void> {
  const response = await authorizedFetch(path, { method });
  if (!response.ok) throw await toApiError(response);
}

// ---------------------------------------------------------------------------
// Авторизация сотрудника
// ---------------------------------------------------------------------------

interface ApiStaffUser {
  id: string;
  email: string;
  name: string;
  role: string;
  companyId: string;
  branchId?: string | null;
}

interface ApiLoginResponse {
  accessToken: string;
  refreshToken: string;
  user: ApiStaffUser;
}

export interface StaffLoginResult {
  accessToken: string;
  refreshToken: string;
  user: AdminUser;
}

const KNOWN_ROLES: Role[] = ["owner", "manager", "barista"];

function mapStaffUser(u: ApiStaffUser): AdminUser {
  if (!KNOWN_ROLES.includes(u.role as Role)) {
    throw new ApiError(0, `Неизвестная роль сотрудника: ${u.role}`);
  }
  return {
    id: u.id,
    email: u.email,
    name: u.name,
    role: u.role as Role,
    companyId: u.companyId,
    branchId: u.branchId ?? undefined
  };
}

/**
 * Вход сотрудника. Компанию сервер определяет по email — в пути её нет.
 * Неверные креды → ApiError(401).
 */
export async function apiStaffLogin(
  email: string,
  password: string
): Promise<StaffLoginResult> {
  if (!apiEnabled) {
    throw new ApiError(0, "Адрес API не задан (NEXT_PUBLIC_API_URL)");
  }
  // Мимо authorizedFetch: 401 здесь — «неверный пароль», а не истёкшая сессия
  const response = await sendRaw("/api/auth/staff/login", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email: email.trim(), password })
  });
  if (!response.ok) throw await toApiError(response);

  const body = (await response.json()) as ApiLoginResponse;
  return {
    accessToken: body.accessToken,
    refreshToken: body.refreshToken,
    user: mapStaffUser(body.user)
  };
}

// ---------------------------------------------------------------------------
// Формы ответов API и маппинг в доменные типы админки
// ---------------------------------------------------------------------------

interface ApiLocalized {
  ru: string;
  ky?: string | null;
  en?: string | null;
}

/** {ru, ky:null, en:null} с сервера → доменный LocalizedText (null → undefined) */
function mapLocalized(v: ApiLocalized): LocalizedText {
  return {
    ru: v.ru,
    ky: v.ky ?? undefined,
    en: v.en ?? undefined
  };
}

/** LocalizedText → тело запроса: пустые ky/en опускаем, ru всегда шлём */
function serializeLocalized(v: LocalizedText): Record<string, string> {
  const out: Record<string, string> = { ru: v.ru.trim() };
  if (v.ky && v.ky.trim()) out.ky = v.ky.trim();
  if (v.en && v.en.trim()) out.en = v.en.trim();
  return out;
}

interface ApiModifier {
  id: string | number;
  name: string | ApiLocalized;
  priceDelta: number;
}

interface ApiProduct {
  id: string | number;
  name: string;
  category: string;
  description?: string;
  price: number;
  color: string;
  sizes: ApiModifier[];
  toppings: ApiModifier[];
  availableBranchIds: string[];
  active: boolean;
  isNew?: boolean;
  isBestSeller?: boolean;
}

interface ApiBranch {
  id: string | number;
  name: string;
  address: string;
  hours: string;
  phone: string;
  isOpen: boolean;
}

interface ApiOrderItem {
  productName: string;
  size?: string | null;
  quantity: number;
  total: number;
}

interface ApiOrder {
  id: string | number;
  number: string;
  customerName: string;
  branchId: string;
  type: OrderType;
  status: OrderStatus;
  items: ApiOrderItem[];
  total: number;
  createdAt: string;
  paymentMethod?: PaymentMethod;
}

function mapProduct(companyId: string, p: ApiProduct): Product {
  return {
    id: String(p.id),
    companyId,
    name: p.name,
    category: p.category,
    color: p.color,
    price: p.price,
    sizes: (p.sizes ?? []).map((s) => ({
      id: String(s.id),
      label: typeof s.name === "string" ? s.name : s.name.ru,
      priceDelta: s.priceDelta
    })),
    toppings: (p.toppings ?? []).map((t) => ({
      id: String(t.id),
      label: typeof t.name === "string" ? t.name : t.name.ru,
      priceDelta: t.priceDelta
    })),
    availableBranchIds: p.availableBranchIds ?? [],
    active: p.active,
    isBestSeller: p.isBestSeller ?? false,
    isNew: p.isNew ?? false
  };
}

function mapBranch(companyId: string, b: ApiBranch): Branch {
  return {
    id: String(b.id),
    companyId,
    name: b.name,
    address: b.address,
    hours: b.hours,
    phone: b.phone,
    isOpen: b.isOpen
  };
}

function mapOrder(companyId: string, o: ApiOrder): Order {
  return {
    id: String(o.id),
    companyId,
    number: o.number,
    customerName: o.customerName,
    branchId: o.branchId,
    type: o.type,
    status: o.status,
    total: o.total,
    createdAt: o.createdAt,
    paymentMethod: o.paymentMethod,
    items: (o.items ?? []).map((item) => ({
      name: item.size ? `${item.productName} (${item.size})` : item.productName,
      quantity: item.quantity,
      unitPrice:
        item.quantity > 0 ? Math.round(item.total / item.quantity) : item.total
    }))
  };
}

/** Патч товара админки → форма API (label → name) */
function serializeProductPatch(
  patch: Partial<Omit<Product, "id" | "companyId">>
): Record<string, unknown> {
  const body: Record<string, unknown> = {};
  if (patch.name !== undefined) body.name = patch.name;
  if (patch.category !== undefined) body.category = patch.category;
  if (patch.color !== undefined) body.color = patch.color;
  if (patch.price !== undefined) body.price = patch.price;
  if (patch.active !== undefined) body.active = patch.active;
  if (patch.isBestSeller !== undefined) body.isBestSeller = patch.isBestSeller;
  if (patch.isNew !== undefined) body.isNew = patch.isNew;
  if (patch.availableBranchIds !== undefined)
    body.availableBranchIds = patch.availableBranchIds;
  if (patch.sizes !== undefined)
    body.sizes = patch.sizes.map((s) => ({
      id: s.id,
      name: s.label,
      priceDelta: s.priceDelta
    }));
  if (patch.toppings !== undefined)
    body.toppings = patch.toppings.map((t) => ({
      id: t.id,
      name: t.label,
      priceDelta: t.priceDelta
    }));
  return body;
}

// ---------------------------------------------------------------------------
// Публичные функции клиента
// ---------------------------------------------------------------------------

export async function apiFetchConfig(companyId: string): Promise<Company> {
  const config = await request<Company>(`/api/companies/${companyId}/config`);
  return { ...config, id: companyId };
}

export async function apiPatchConfig(
  companyId: string,
  patch: Partial<Omit<Company, "id">>
): Promise<Company> {
  const config = await request<Company>(`/api/companies/${companyId}/config`, {
    method: "PATCH",
    body: JSON.stringify(patch)
  });
  return { ...config, id: companyId };
}

export async function apiFetchProducts(companyId: string): Promise<Product[]> {
  const products = await request<ApiProduct[]>(
    `/api/companies/${companyId}/products`
  );
  return products.map((p) => mapProduct(companyId, p));
}

export async function apiCreateProduct(
  companyId: string,
  product: Omit<Product, "id" | "companyId">
): Promise<Product> {
  const created = await request<ApiProduct>(
    `/api/companies/${companyId}/products`,
    { method: "POST", body: JSON.stringify(serializeProductPatch(product)) }
  );
  return mapProduct(companyId, created);
}

export async function apiPatchProduct(
  companyId: string,
  productId: string,
  patch: Partial<Omit<Product, "id" | "companyId">>
): Promise<Product> {
  const updated = await request<ApiProduct>(
    `/api/companies/${companyId}/products/${productId}`,
    { method: "PATCH", body: JSON.stringify(serializeProductPatch(patch)) }
  );
  return mapProduct(companyId, updated);
}

export async function apiFetchBranches(companyId: string): Promise<Branch[]> {
  const branches = await request<ApiBranch[]>(
    `/api/companies/${companyId}/branches`
  );
  return branches.map((b) => mapBranch(companyId, b));
}

export async function apiCreateBranch(
  companyId: string,
  branch: Omit<Branch, "id" | "companyId">
): Promise<Branch> {
  const created = await request<ApiBranch>(
    `/api/companies/${companyId}/branches`,
    { method: "POST", body: JSON.stringify(branch) }
  );
  return mapBranch(companyId, created);
}

export async function apiPatchBranch(
  companyId: string,
  branchId: string,
  patch: Partial<Omit<Branch, "id" | "companyId">>
): Promise<Branch> {
  const updated = await request<ApiBranch>(
    `/api/companies/${companyId}/branches/${branchId}`,
    { method: "PATCH", body: JSON.stringify(patch) }
  );
  return mapBranch(companyId, updated);
}

export async function apiFetchOrders(companyId: string): Promise<Order[]> {
  const orders = await request<ApiOrder[]>(
    `/api/companies/${companyId}/orders`
  );
  return orders.map((o) => mapOrder(companyId, o));
}

export type OrderStreamEventType =
  | "reconcile"
  | "order.created"
  | "order.updated";

export interface OrderStreamNotice {
  type: OrderStreamEventType;
  id?: string;
}

/**
 * Authenticated SSE over fetch. Native EventSource cannot attach a Bearer
 * header and would force the JWT into the URL, so the admin reads the response
 * stream directly. Events are wake-ups only; GET /orders remains authoritative.
 */
export async function apiWatchOrderEvents(
  companyId: string,
  options: {
    signal: AbortSignal;
    lastEventId?: string;
    onNotice: (notice: OrderStreamNotice) => void;
  }
): Promise<void> {
  const headers = new Headers({ Accept: "text/event-stream" });
  if (options.lastEventId) {
    headers.set("Last-Event-ID", options.lastEventId);
  }
  const response = await authorizedFetch(
    `/api/companies/${companyId}/orders/events`,
    { method: "GET", headers, signal: options.signal }
  );
  if (!response.ok) throw await toApiError(response);
  if (!response.body) {
    throw new ApiError(0, "Браузер не поддерживает поток событий заказов");
  }

  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";
  try {
    while (!options.signal.aborted) {
      const { done, value } = await reader.read();
      if (done) return;
      buffer += decoder.decode(value, { stream: true });
      const drained = drainSseFrames(buffer);
      buffer = drained.rest;
      for (const frame of drained.frames) {
        if (
          frame.event === "reconcile" ||
          frame.event === "order.created" ||
          frame.event === "order.updated"
        ) {
          options.onNotice({ type: frame.event, id: frame.id });
        }
      }
    }
  } finally {
    reader.releaseLock();
  }
}

export async function apiPatchOrderStatus(
  companyId: string,
  orderId: string,
  status: OrderStatus
): Promise<Order> {
  const updated = await request<ApiOrder>(
    `/api/companies/${companyId}/orders/${orderId}/status`,
    { method: "PATCH", body: JSON.stringify({ status }) }
  );
  return mapOrder(companyId, updated);
}

// ---------------------------------------------------------------------------
// Новости-сторис
// ---------------------------------------------------------------------------

interface ApiNews {
  id: string | number;
  sortOrder: number;
  isPublished: boolean;
  title: ApiLocalized;
  body: ApiLocalized;
  badge: ApiLocalized;
  accentColor: string;
  visual: NewsVisual;
  publishedAt: string;
  expiresAt: string | null;
  imageUrl: string | null;
  ctaLabel: ApiLocalized | null;
  ctaRoute: string | null;
}

function mapNews(companyId: string, n: ApiNews): NewsStory {
  return {
    id: String(n.id),
    companyId,
    sortOrder: n.sortOrder,
    isPublished: n.isPublished,
    title: mapLocalized(n.title),
    body: mapLocalized(n.body),
    badge: mapLocalized(n.badge),
    accentColor: n.accentColor,
    visual: n.visual,
    publishedAt: n.publishedAt,
    expiresAt: n.expiresAt ?? null,
    imageUrl: n.imageUrl ?? null,
    ctaLabel: n.ctaLabel ? mapLocalized(n.ctaLabel) : null,
    ctaRoute: n.ctaRoute ?? null
  };
}

function serializeNewsPatch(
  patch: Partial<Omit<NewsStory, "id" | "companyId">>
): Record<string, unknown> {
  const body: Record<string, unknown> = {};
  if (patch.sortOrder !== undefined) body.sortOrder = patch.sortOrder;
  if (patch.isPublished !== undefined) body.isPublished = patch.isPublished;
  if (patch.title !== undefined) body.title = serializeLocalized(patch.title);
  if (patch.body !== undefined) body.body = serializeLocalized(patch.body);
  if (patch.badge !== undefined) body.badge = serializeLocalized(patch.badge);
  if (patch.accentColor !== undefined) body.accentColor = patch.accentColor;
  if (patch.visual !== undefined) body.visual = patch.visual;
  if (patch.publishedAt !== undefined) body.publishedAt = patch.publishedAt;
  if (patch.expiresAt !== undefined) body.expiresAt = patch.expiresAt;
  if (patch.imageUrl !== undefined) body.imageUrl = patch.imageUrl;
  if (patch.ctaLabel !== undefined)
    body.ctaLabel = patch.ctaLabel ? serializeLocalized(patch.ctaLabel) : null;
  if (patch.ctaRoute !== undefined) body.ctaRoute = patch.ctaRoute;
  return body;
}

export async function apiFetchNews(companyId: string): Promise<NewsStory[]> {
  const news = await request<ApiNews[]>(`/api/companies/${companyId}/news`);
  return news.map((n) => mapNews(companyId, n));
}

export async function apiCreateNews(
  companyId: string,
  news: Omit<NewsStory, "id" | "companyId">
): Promise<NewsStory> {
  const created = await request<ApiNews>(`/api/companies/${companyId}/news`, {
    method: "POST",
    body: JSON.stringify(serializeNewsPatch(news))
  });
  return mapNews(companyId, created);
}

export async function apiPatchNews(
  companyId: string,
  newsId: string,
  patch: Partial<Omit<NewsStory, "id" | "companyId">>
): Promise<NewsStory> {
  const updated = await request<ApiNews>(
    `/api/companies/${companyId}/news/${newsId}`,
    { method: "PATCH", body: JSON.stringify(serializeNewsPatch(patch)) }
  );
  return mapNews(companyId, updated);
}

export async function apiDeleteNews(
  companyId: string,
  newsId: string
): Promise<void> {
  await requestVoid(`/api/companies/${companyId}/news/${newsId}`);
}

// ---------------------------------------------------------------------------
// V2 content management (owner / manager only)
// ---------------------------------------------------------------------------

export type ContentStoryWrite = Omit<
  ContentStory,
  "id" | "companyId" | "media"
>;
export type StoryCollectionWrite = Omit<
  StoryCollection,
  | "id"
  | "companyId"
  | "coverImageUrl"
  | "coverThumbnailUrl"
  | "storyCount"
>;
export type NewsPostWrite = Omit<NewsPost, "id" | "companyId" | "media">;

interface ApiContentMedia {
  type?: ContentMediaType | null;
  url?: string | null;
  thumbnailUrl?: string | null;
}

interface ApiContentStory {
  id: string | number;
  collectionId?: string | number | null;
  title?: ApiLocalized | null;
  body?: ApiLocalized | null;
  badge?: ApiLocalized | null;
  accentColor?: string;
  visual?: NewsVisual;
  isPublished?: boolean;
  showOnHome?: boolean;
  isPinned?: boolean;
  sortOrder?: number;
  publishedAt?: string;
  expiresAt?: string | null;
  media?: ApiContentMedia | null;
  mediaType?: ContentMediaType | null;
  mediaUrl?: string | null;
  imageUrl?: string | null;
  thumbnailUrl?: string | null;
  ctaLabel?: ApiLocalized | null;
  ctaRoute?: string | null;
}

interface ApiStoryCollection {
  id: string | number;
  name?: ApiLocalized | null;
  description?: ApiLocalized | null;
  coverImageUrl?: string | null;
  coverThumbnailUrl?: string | null;
  cover?: ApiContentMedia | null;
  accentColor?: string;
  visual?: NewsVisual;
  sortOrder?: number;
  isPublished?: boolean;
  storyCount?: number;
}

interface ApiNewsPost {
  id: string | number;
  title?: ApiLocalized | null;
  summary?: ApiLocalized | null;
  body?: ApiLocalized | null;
  isPublished?: boolean;
  publishedAt?: string;
  media?: ApiContentMedia | null;
  mediaType?: ContentMediaType | null;
  mediaUrl?: string | null;
  thumbnailUrl?: string | null;
}

const emptyLocalizedText = (): LocalizedText => ({ ru: "", ky: "", en: "" });

function mapLocalizedOrEmpty(value?: ApiLocalized | null): LocalizedText {
  return value ? mapLocalized(value) : emptyLocalizedText();
}

function serializeLocalizedComplete(value: LocalizedText): Record<string, string> {
  return {
    ru: value.ru.trim(),
    ky: (value.ky ?? "").trim(),
    en: (value.en ?? "").trim()
  };
}

function mapContentMedia(
  media?: ApiContentMedia | null,
  fallbackType?: ContentMediaType | null,
  fallbackUrl?: string | null,
  fallbackThumbnail?: string | null
): ContentMedia {
  const url = media?.url ?? fallbackUrl ?? null;
  const type = media?.type ?? fallbackType ?? (url ? "image" : "none");
  return {
    type,
    url,
    thumbnailUrl: media?.thumbnailUrl ?? fallbackThumbnail ?? null
  };
}

function contentBase(companyId: string): string {
  return `/api/companies/${encodeURIComponent(companyId)}/admin/content`;
}

function mapContentStory(companyId: string, value: ApiContentStory): ContentStory {
  return {
    id: String(value.id),
    companyId,
    collectionId:
      value.collectionId === undefined || value.collectionId === null
        ? null
        : String(value.collectionId),
    title: mapLocalizedOrEmpty(value.title),
    body: mapLocalizedOrEmpty(value.body),
    badge: mapLocalizedOrEmpty(value.badge),
    accentColor: value.accentColor ?? "#FF5C9A",
    visual: value.visual ?? "sparkle",
    isPublished: value.isPublished ?? false,
    showOnHome: value.showOnHome ?? false,
    isPinned: value.isPinned ?? false,
    sortOrder: value.sortOrder ?? 0,
    publishedAt: value.publishedAt ?? new Date(0).toISOString(),
    expiresAt: value.expiresAt ?? null,
    media: mapContentMedia(
      value.media,
      value.mediaType,
      value.mediaUrl ?? value.imageUrl,
      value.thumbnailUrl
    ),
    ctaLabel: value.ctaLabel ? mapLocalized(value.ctaLabel) : null,
    ctaRoute: value.ctaRoute ?? null
  };
}

function serializeContentStory(value: ContentStoryWrite): Record<string, unknown> {
  return {
    collectionId: value.collectionId,
    title: serializeLocalizedComplete(value.title),
    body: serializeLocalizedComplete(value.body),
    badge: serializeLocalizedComplete(value.badge),
    accentColor: value.accentColor,
    visual: value.visual,
    isPublished: value.isPublished,
    showOnHome: value.showOnHome,
    isPinned: value.isPinned,
    sortOrder: value.sortOrder,
    publishedAt: value.publishedAt,
    expiresAt: value.expiresAt,
    ctaLabel: value.ctaLabel
      ? serializeLocalizedComplete(value.ctaLabel)
      : null,
    ctaRoute: value.ctaRoute
  };
}

function mapStoryCollection(
  companyId: string,
  value: ApiStoryCollection
): StoryCollection {
  return {
    id: String(value.id),
    companyId,
    name: mapLocalizedOrEmpty(value.name),
    description: mapLocalizedOrEmpty(value.description),
    coverImageUrl: value.cover?.url ?? value.coverImageUrl ?? null,
    coverThumbnailUrl:
      value.cover?.thumbnailUrl ?? value.coverThumbnailUrl ?? null,
    accentColor: value.accentColor ?? "#FF5C9A",
    visual: value.visual ?? "sparkle",
    sortOrder: value.sortOrder ?? 0,
    isPublished: value.isPublished ?? false,
    storyCount: value.storyCount ?? 0
  };
}

function serializeStoryCollection(
  value: StoryCollectionWrite
): Record<string, unknown> {
  return {
    name: serializeLocalizedComplete(value.name),
    description: serializeLocalizedComplete(value.description),
    accentColor: value.accentColor,
    visual: value.visual,
    sortOrder: value.sortOrder,
    isPublished: value.isPublished
  };
}

function mapNewsPost(companyId: string, value: ApiNewsPost): NewsPost {
  return {
    id: String(value.id),
    companyId,
    title: mapLocalizedOrEmpty(value.title),
    summary: mapLocalizedOrEmpty(value.summary),
    body: mapLocalizedOrEmpty(value.body),
    isPublished: value.isPublished ?? false,
    publishedAt: value.publishedAt ?? new Date(0).toISOString(),
    media: mapContentMedia(
      value.media,
      value.mediaType,
      value.mediaUrl,
      value.thumbnailUrl
    )
  };
}

function serializeNewsPost(value: NewsPostWrite): Record<string, unknown> {
  return {
    title: serializeLocalizedComplete(value.title),
    summary: serializeLocalizedComplete(value.summary),
    body: serializeLocalizedComplete(value.body),
    isPublished: value.isPublished,
    publishedAt: value.publishedAt
  };
}

export async function apiFetchContentStories(companyId: string): Promise<ContentStory[]> {
  const values = await request<ApiContentStory[]>(`${contentBase(companyId)}/stories`);
  return values.map((value) => mapContentStory(companyId, value));
}

export async function apiCreateContentStory(
  companyId: string,
  value: ContentStoryWrite
): Promise<ContentStory> {
  const created = await request<ApiContentStory>(`${contentBase(companyId)}/stories`, {
    method: "POST",
    body: JSON.stringify(serializeContentStory(value))
  });
  return mapContentStory(companyId, created);
}

export async function apiPatchContentStory(
  companyId: string,
  storyId: string,
  value: ContentStoryWrite
): Promise<ContentStory> {
  const updated = await request<ApiContentStory>(
    `${contentBase(companyId)}/stories/${encodeURIComponent(storyId)}`,
    { method: "PATCH", body: JSON.stringify(serializeContentStory(value)) }
  );
  return mapContentStory(companyId, updated);
}

export async function apiDeleteContentStory(companyId: string, storyId: string): Promise<void> {
  await requestVoid(`${contentBase(companyId)}/stories/${encodeURIComponent(storyId)}`);
}

export async function apiUploadStoryMedia(
  companyId: string,
  storyId: string,
  file: File
): Promise<ContentStory> {
  const form = new FormData();
  form.set("file", file, file.name);
  const value = await request<ApiContentStory>(
    `${contentBase(companyId)}/stories/${encodeURIComponent(storyId)}/media`,
    { method: "PUT", body: form }
  );
  return mapContentStory(companyId, value);
}

export async function apiDeleteStoryMedia(companyId: string, storyId: string): Promise<ContentStory> {
  const value = await request<ApiContentStory>(
    `${contentBase(companyId)}/stories/${encodeURIComponent(storyId)}/media`,
    { method: "DELETE" }
  );
  return mapContentStory(companyId, value);
}

export async function apiFetchStoryCollections(companyId: string): Promise<StoryCollection[]> {
  const values = await request<ApiStoryCollection[]>(`${contentBase(companyId)}/story-collections`);
  return values.map((value) => mapStoryCollection(companyId, value));
}

export async function apiCreateStoryCollection(
  companyId: string,
  value: StoryCollectionWrite
): Promise<StoryCollection> {
  const created = await request<ApiStoryCollection>(`${contentBase(companyId)}/story-collections`, {
    method: "POST",
    body: JSON.stringify(serializeStoryCollection(value))
  });
  return mapStoryCollection(companyId, created);
}

export async function apiPatchStoryCollection(
  companyId: string,
  collectionId: string,
  value: StoryCollectionWrite
): Promise<StoryCollection> {
  const updated = await request<ApiStoryCollection>(
    `${contentBase(companyId)}/story-collections/${encodeURIComponent(collectionId)}`,
    { method: "PATCH", body: JSON.stringify(serializeStoryCollection(value)) }
  );
  return mapStoryCollection(companyId, updated);
}

export async function apiDeleteStoryCollection(companyId: string, collectionId: string): Promise<void> {
  await requestVoid(`${contentBase(companyId)}/story-collections/${encodeURIComponent(collectionId)}`);
}

export async function apiUploadCollectionCover(
  companyId: string,
  collectionId: string,
  file: File
): Promise<StoryCollection> {
  const form = new FormData();
  form.set("file", file, file.name);
  const value = await request<ApiStoryCollection>(
    `${contentBase(companyId)}/story-collections/${encodeURIComponent(collectionId)}/cover`,
    { method: "PUT", body: form }
  );
  return mapStoryCollection(companyId, value);
}

export async function apiDeleteCollectionCover(
  companyId: string,
  collectionId: string
): Promise<StoryCollection> {
  const value = await request<ApiStoryCollection>(
    `${contentBase(companyId)}/story-collections/${encodeURIComponent(collectionId)}/cover`,
    { method: "DELETE" }
  );
  return mapStoryCollection(companyId, value);
}

export async function apiFetchNewsPosts(companyId: string): Promise<NewsPost[]> {
  const values = await request<ApiNewsPost[]>(`${contentBase(companyId)}/news-posts`);
  return values.map((value) => mapNewsPost(companyId, value));
}

export async function apiCreateNewsPost(companyId: string, value: NewsPostWrite): Promise<NewsPost> {
  const created = await request<ApiNewsPost>(`${contentBase(companyId)}/news-posts`, {
    method: "POST",
    body: JSON.stringify(serializeNewsPost(value))
  });
  return mapNewsPost(companyId, created);
}

export async function apiPatchNewsPost(
  companyId: string,
  postId: string,
  value: NewsPostWrite
): Promise<NewsPost> {
  const updated = await request<ApiNewsPost>(
    `${contentBase(companyId)}/news-posts/${encodeURIComponent(postId)}`,
    { method: "PATCH", body: JSON.stringify(serializeNewsPost(value)) }
  );
  return mapNewsPost(companyId, updated);
}

export async function apiDeleteNewsPost(companyId: string, postId: string): Promise<void> {
  await requestVoid(`${contentBase(companyId)}/news-posts/${encodeURIComponent(postId)}`);
}

export async function apiUploadNewsPostMedia(
  companyId: string,
  postId: string,
  file: File
): Promise<NewsPost> {
  const form = new FormData();
  form.set("file", file, file.name);
  const value = await request<ApiNewsPost>(
    `${contentBase(companyId)}/news-posts/${encodeURIComponent(postId)}/media`,
    { method: "PUT", body: form }
  );
  return mapNewsPost(companyId, value);
}

export async function apiDeleteNewsPostMedia(companyId: string, postId: string): Promise<NewsPost> {
  const value = await request<ApiNewsPost>(
    `${contentBase(companyId)}/news-posts/${encodeURIComponent(postId)}/media`,
    { method: "DELETE" }
  );
  return mapNewsPost(companyId, value);
}

// ---------------------------------------------------------------------------
// Сезонные акции
// ---------------------------------------------------------------------------

interface ApiPromotion {
  id: string | number;
  sortOrder: number;
  active: boolean;
  title: ApiLocalized;
  description: ApiLocalized;
  code: string | null;
  accentColor: string;
}

function mapPromotion(companyId: string, p: ApiPromotion): Promotion {
  return {
    id: String(p.id),
    companyId,
    sortOrder: p.sortOrder,
    active: p.active,
    title: mapLocalized(p.title),
    description: mapLocalized(p.description),
    code: p.code ?? null,
    accentColor: p.accentColor
  };
}

function serializePromotionPatch(
  patch: Partial<Omit<Promotion, "id" | "companyId">>
): Record<string, unknown> {
  const body: Record<string, unknown> = {};
  if (patch.sortOrder !== undefined) body.sortOrder = patch.sortOrder;
  if (patch.active !== undefined) body.active = patch.active;
  if (patch.title !== undefined) body.title = serializeLocalized(patch.title);
  if (patch.description !== undefined)
    body.description = serializeLocalized(patch.description);
  if (patch.code !== undefined) body.code = patch.code;
  if (patch.accentColor !== undefined) body.accentColor = patch.accentColor;
  return body;
}

export async function apiFetchPromotions(
  companyId: string
): Promise<Promotion[]> {
  const promotions = await request<ApiPromotion[]>(
    `/api/companies/${companyId}/promotions`
  );
  return promotions.map((p) => mapPromotion(companyId, p));
}

export async function apiCreatePromotion(
  companyId: string,
  promotion: Omit<Promotion, "id" | "companyId">
): Promise<Promotion> {
  const created = await request<ApiPromotion>(
    `/api/companies/${companyId}/promotions`,
    { method: "POST", body: JSON.stringify(serializePromotionPatch(promotion)) }
  );
  return mapPromotion(companyId, created);
}

export async function apiPatchPromotion(
  companyId: string,
  promotionId: string,
  patch: Partial<Omit<Promotion, "id" | "companyId">>
): Promise<Promotion> {
  const updated = await request<ApiPromotion>(
    `/api/companies/${companyId}/promotions/${promotionId}`,
    { method: "PATCH", body: JSON.stringify(serializePromotionPatch(patch)) }
  );
  return mapPromotion(companyId, updated);
}

export async function apiDeletePromotion(
  companyId: string,
  promotionId: string
): Promise<void> {
  await requestVoid(`/api/companies/${companyId}/promotions/${promotionId}`);
}
