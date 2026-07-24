import type {
  LocalizedText,
  Order,
  OrderStatus,
  OrderType,
  PaymentMethod
} from "./types";

type ApiSnapshotText =
  | string
  | Partial<Record<keyof LocalizedText, string | null>>;

interface ApiOrderTopping {
  id?: string | number | null;
  name?: ApiSnapshotText | null;
  label?: ApiSnapshotText | null;
  priceDelta?: number | null;
}

export interface ApiOrderItemContract {
  productId?: string | number | null;
  productName?: ApiSnapshotText | null;
  name?: ApiSnapshotText | null;
  imageUrl?: string | null;
  productDescription?: ApiSnapshotText | null;
  description?: ApiSnapshotText | null;
  size?: ApiSnapshotText | null;
  sizeId?: string | number | null;
  toppingIds?: Array<string | number> | null;
  quantity: number;
  total: number;
  unitPrice?: number | null;
  sugarPercent?: number | null;
  ice?: string | null;
  toppings?: Array<ApiSnapshotText | ApiOrderTopping> | null;
  toppingNames?: ApiSnapshotText[] | null;
}

export interface ApiOrderContract {
  id: string | number;
  number: string;
  customerName: string;
  customerPhone?: string | null;
  phone?: string | null;
  branchId: string;
  branchName?: string | null;
  branchAddress?: string | null;
  type: OrderType;
  status: OrderStatus;
  readyTime?: string | null;
  comment?: string | null;
  /** Старый backend этих полей не шлёт: отсутствие = false / null. */
  isRecurring?: boolean | null;
  scheduledFor?: string | null;
  itemsVersion?: 1 | 2;
  items: ApiOrderItemContract[];
  subtotal?: number | null;
  discount?: number | null;
  total: number;
  paymentMethod?: string | null;
  promoCode?: string | null;
  paymentStatus?: string | null;
  pointsUsed?: number | null;
  pointsEarned?: number | null;
  createdAt: string;
}

function optionalText(value: string | null | undefined): string | undefined {
  const normalized = value?.trim();
  return normalized ? normalized : undefined;
}

export function snapshotText(value: ApiSnapshotText | null | undefined): string | undefined {
  if (typeof value === "string") return optionalText(value);
  if (!value) return undefined;
  for (const language of ["ru", "ky", "en"] as const) {
    const text = optionalText(value[language]);
    if (text) return text;
  }
  return undefined;
}

function mapPaymentMethod(
  value: string | null | undefined
): PaymentMethod | undefined {
  return value === "mock" || value === "cash" || value === "qr"
    ? value
    : undefined;
}

function mapToppings(item: ApiOrderItemContract): Order["items"][number]["toppings"] {
  const source = item.toppings ?? item.toppingNames;
  if (!source) return undefined;
  const values = source.flatMap((value) => {
    if (typeof value === "string") {
      const name = optionalText(value);
      return name ? [{ name }] : [];
    }
    if ("ru" in value || "ky" in value || "en" in value) {
      const name = snapshotText(value as ApiSnapshotText);
      return name ? [{ name }] : [];
    }
    const topping = value as ApiOrderTopping;
    const name = snapshotText(topping.name ?? topping.label);
    if (!name) return [];
    return [
      {
        id:
          topping.id === null || topping.id === undefined
            ? undefined
            : String(topping.id),
        name,
        priceDelta: finiteOptional(topping.priceDelta)
      }
    ];
  });
  return values.length ? values : undefined;
}

function finiteOptional(value: number | null | undefined): number | undefined {
  return typeof value === "number" && Number.isFinite(value) ? value : undefined;
}

function exactUnitPrice(item: ApiOrderItemContract): number | undefined {
  const explicit = finiteOptional(item.unitPrice);
  if (explicit !== undefined) return explicit;
  if (
    Number.isInteger(item.quantity) &&
    item.quantity > 0 &&
    Number.isFinite(item.total) &&
    item.total % item.quantity === 0
  ) {
    return item.total / item.quantity;
  }
  return undefined;
}

export function mapApiOrder(companyId: string, value: ApiOrderContract): Order {
  return {
    id: String(value.id),
    companyId,
    number: value.number,
    customerName: value.customerName,
    customerPhone: optionalText(value.customerPhone ?? value.phone),
    branchId: value.branchId,
    branchName: optionalText(value.branchName),
    branchAddress: optionalText(value.branchAddress),
    type: value.type,
    status: value.status,
    readyTime: optionalText(value.readyTime),
    comment: optionalText(value.comment),
    isRecurring: value.isRecurring ?? false,
    scheduledFor: optionalText(value.scheduledFor),
    itemsVersion: value.itemsVersion,
    total: value.total,
    subtotal: finiteOptional(value.subtotal),
    discount: finiteOptional(value.discount),
    createdAt: value.createdAt,
    paymentMethod: mapPaymentMethod(value.paymentMethod),
    promoCode: optionalText(value.promoCode),
    paymentStatus: optionalText(value.paymentStatus),
    pointsUsed: finiteOptional(value.pointsUsed),
    pointsEarned: finiteOptional(value.pointsEarned),
    items: (value.items ?? []).map((item) => ({
      productId:
        item.productId === null || item.productId === undefined
          ? undefined
          : String(item.productId),
      sizeId:
        item.sizeId === null || item.sizeId === undefined
          ? undefined
          : String(item.sizeId),
      toppingIds: item.toppingIds?.map(String),
      name: snapshotText(item.productName ?? item.name) ?? "",
      quantity: item.quantity,
      unitPrice: exactUnitPrice(item),
      lineTotal: item.total,
      imageUrl: optionalText(item.imageUrl),
      description: snapshotText(item.productDescription ?? item.description),
      size: snapshotText(item.size),
      sugarPercent: finiteOptional(item.sugarPercent),
      ice: optionalText(item.ice),
      toppings: mapToppings(item)
    }))
  };
}
