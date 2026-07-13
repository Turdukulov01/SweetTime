import type { OrderStatus, OrderType, Role } from "@/lib/types";

export const ORDER_STATUS_LABELS: Record<OrderStatus, string> = {
  new: "Новый",
  preparing: "Готовится",
  ready: "Готов",
  done: "Выдан",
  cancelled: "Отменён"
};

export const ORDER_TYPE_LABELS: Record<OrderType, string> = {
  pickup: "Самовывоз",
  scheduled: "Ко времени",
  qr: "QR со столика"
};

export const ROLE_LABELS: Record<Role, string> = {
  owner: "Владелец",
  manager: "Менеджер",
  barista: "Бариста"
};
