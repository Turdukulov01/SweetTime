"use client";

// Тонкий fetch-клиент demo-API (контракт: docs/design/DEMO_API.md).
// Все ручки тенант-скоупнуты: /api/companies/{companyId}/...
// При отсутствии NEXT_PUBLIC_API_URL клиент выключен (apiEnabled = false),
// сторы остаются на мок-данных.

import { useSyncExternalStore } from "react";
import type {
  Branch,
  Company,
  Order,
  PaymentMethod,
  OrderStatus,
  OrderType,
  Product
} from "@/lib/types";

const API_URL = (process.env.NEXT_PUBLIC_API_URL ?? "").replace(/\/+$/, "");

/** Включена ли интеграция с API (задан NEXT_PUBLIC_API_URL) */
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

/** Хук статуса API: "live" — зелёная точка, остальное — серая (моки) */
export function useApiStatus(): ApiStatus {
  return useSyncExternalStore(
    subscribe,
    () => currentStatus,
    () => (apiEnabled ? "unknown" : "off")
  );
}

// ---------------------------------------------------------------------------
// Базовый запрос
// ---------------------------------------------------------------------------

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  if (!apiEnabled) throw new ApiError(0, "API отключён (NEXT_PUBLIC_API_URL)");

  let response: Response;
  try {
    response = await fetch(`${API_URL}${path}`, {
      ...init,
      headers: {
        "Content-Type": "application/json",
        ...(init?.headers ?? {})
      },
      cache: "no-store"
    });
  } catch {
    setApiStatus("down");
    throw new ApiError(0, "API недоступен");
  }

  // Сервер ответил — он жив, даже если вернул ошибку уровня запроса
  setApiStatus("live");

  if (!response.ok) {
    let detail = `HTTP ${response.status}`;
    try {
      const body = (await response.json()) as { detail?: unknown };
      if (typeof body.detail === "string") detail = body.detail;
    } catch {
      // тело не JSON — оставляем HTTP-код
    }
    throw new ApiError(response.status, detail);
  }

  return (await response.json()) as T;
}

// ---------------------------------------------------------------------------
// Формы ответов API и маппинг в доменные типы админки
// ---------------------------------------------------------------------------

interface ApiModifier {
  name: string;
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
    sizes: (p.sizes ?? []).map((s, i) => ({
      id: `s${i}`,
      label: s.name,
      priceDelta: s.priceDelta
    })),
    toppings: (p.toppings ?? []).map((t, i) => ({
      id: `t${i}`,
      label: t.name,
      priceDelta: t.priceDelta
    })),
    availableBranchIds: p.availableBranchIds ?? [],
    active: p.active
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
  if (patch.availableBranchIds !== undefined)
    body.availableBranchIds = patch.availableBranchIds;
  if (patch.sizes !== undefined)
    body.sizes = patch.sizes.map((s) => ({
      name: s.label,
      priceDelta: s.priceDelta
    }));
  if (patch.toppings !== undefined)
    body.toppings = patch.toppings.map((t) => ({
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
