// Доменные типы мультитенантной админки SweetTime.
// Все доменные сущности несут companyId — изоляция тенантов обязательна.

export type Role = "owner" | "manager" | "barista";

export interface LoyaltyConfig {
  /** Доля начисления баллов от суммы заказа, например 0.05 = 5% */
  earnRate: number;
  /** Максимальная доля заказа, оплачиваемая баллами, например 0.3 = 30% */
  maxSpendShare: number;
  /** Срок сгорания баллов в месяцах */
  expiryMonths: number;
}

export interface ReferralConfig {
  /** Баллы приглашённому пользователю */
  invitedBonus: number;
  /** Баллы пригласившему после первого выполненного заказа приглашённого */
  inviterBonus: number;
}

export interface Company {
  id: string;
  /** Юридическое/внутреннее название компании */
  name: string;
  /** Название брендированного клиентского приложения */
  appName: string;
  /** Акцентный цвет бренда, HEX (#RRGGBB) */
  accentColor: string;
  /** Код валюты для отображения, например "сом" */
  currency: string;
  loyalty: LoyaltyConfig;
  referral: ReferralConfig;
}

export interface AdminUser {
  id: string;
  email: string;
  name: string;
  role: Role;
  companyId: string;
  /** Для barista — филиал, к которому привязан сотрудник */
  branchId?: string;
}

export interface Branch {
  id: string;
  companyId: string;
  name: string;
  address: string;
  /** Часы работы, например "09:00–22:00" */
  hours: string;
  phone: string;
  /** Принимает ли филиал заказы сейчас */
  isOpen: boolean;
}

export interface ModifierOption {
  id: string;
  label: string;
  /** Приплата к базовой цене, сом (целое число, может быть 0) */
  priceDelta: number;
}

export interface Product {
  id: string;
  companyId: string;
  name: string;
  /** Категория меню, отображаемая строка на русском */
  category: string;
  /** Цвет фото-заглушки товара, HEX (#RRGGBB) */
  color: string;
  /** Базовая цена, сом (целое число) */
  price: number;
  /** Модификатор «размер» — выбор одного варианта */
  sizes: ModifierOption[];
  /** Модификаторы «топпинги» — множественный выбор */
  toppings: ModifierOption[];
  /** Филиалы, в которых товар доступен */
  availableBranchIds: string[];
  /** Включён ли товар в меню */
  active: boolean;
}

export type RecurringPlan = "week" | "month";

/** «Постоянный заказ» — предоплаченный любимый напиток к нужному времени */
export interface RecurringOrder {
  id: string;
  companyId: string;
  customerName: string;
  /** Название напитка с модификаторами */
  productName: string;
  /** Время готовности, например "11:00" */
  readyTime: string;
  branchId: string;
  plan: RecurringPlan;
  /** Оплачено до (ISO-дата) */
  paidUntil: string;
  /** Активна ли подписка сейчас */
  active: boolean;
}

export type OrderType = "pickup" | "scheduled" | "qr";

export type OrderStatus = "new" | "preparing" | "ready" | "done" | "cancelled";

export type PaymentMethod = "mock" | "cash" | "qr";

export interface OrderItem {
  /** Название позиции с учётом модификаторов, например "Розовая луна (L, тапиока)" */
  name: string;
  quantity: number;
  /** Итоговая цена за единицу с учётом модификаторов, сом */
  unitPrice: number;
}

export interface Order {
  id: string;
  companyId: string;
  /** Человекочитаемый номер заказа, например "SW-1061" */
  number: string;
  items: OrderItem[];
  branchId: string;
  type: OrderType;
  status: OrderStatus;
  /** Итоговая сумма заказа, сом */
  total: number;
  /** ISO-строка времени создания */
  createdAt: string;
  customerName: string;
  /** Может отсутствовать у старого demo API или локальных моков */
  paymentMethod?: PaymentMethod;
}

/** Срез данных одной компании — единственный формат выдачи данных компонентам */
export interface CompanyData {
  company: Company;
  branches: Branch[];
  products: Product[];
  orders: Order[];
  users: AdminUser[];
  recurring: RecurringOrder[];
}
