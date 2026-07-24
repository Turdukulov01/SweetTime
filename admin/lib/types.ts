// Доменные типы мультитенантной админки SweetTime.
// Все доменные сущности несут companyId — изоляция тенантов обязательна.

export type Role = "owner" | "manager" | "barista";

/**
 * Локализованный текст витрины: русский обязателен, кыргызский и английский —
 * опциональны. Контракт demo-API возвращает объект `{ru, ky?, en?}` (CX-012).
 */
export interface LocalizedText {
  ru: string;
  ky?: string;
  en?: string;
}

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
  logoUrl: string | null;
  logoThumbnailUrl: string | null;
  background: BackgroundTheme;
  /** Код валюты для отображения, например "сом" */
  currency: string;
  loyalty: LoyaltyConfig;
  referral: ReferralConfig;
}

export interface BackgroundTheme {
  kind: "plain" | "pattern" | "image";
  preset: "none" | "bubbles" | "doodles" | "coffee";
  lightBase: string;
  darkBase: string;
  patternOpacity: number;
  imageUrl: string | null;
  thumbnailUrl: string | null;
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

/** Управляемая owner-ом учётная запись сотрудника компании. */
export interface StaffMember extends AdminUser {
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
}

/** Роли, которые можно выдать обычным приглашением. Owner создаётся отдельно. */
export type StaffAssignableRole = Exclude<Role, "owner">;

export interface StaffInvitation {
  id: string;
  companyId: string;
  email: string;
  role: StaffAssignableRole;
  branchId?: string;
  status: string;
  deliveryStatus: string;
  expiresAt: string;
  createdAt: string;
  sentAt?: string;
  acceptedAt?: string;
}

export interface StaffInvitationPreview {
  email: string;
  companyId: string;
  companyName: string;
  role: StaffAssignableRole;
  branchName?: string;
  expiresAt: string;
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
  /** Полный перевод из справочника; ручной вариант может иметь только label. */
  localizedName?: LocalizedText;
  /** Приплата к базовой цене, сом (целое число, может быть 0) */
  priceDelta: number;
}

export interface Product {
  id: string;
  companyId: string;
  name: string;
  /** Full storefront translations. Legacy records may contain only RU. */
  nameLocalized?: LocalizedText;
  /** Описание товара, которое возвращает и принимает product API. */
  description: string;
  descriptionLocalized?: LocalizedText;
  /** Серверный URL фото или null; произвольный локальный файл здесь не хранится. */
  imageUrl: string | null;
  categoryId?: string | null;
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
  /** «Хит продаж» — попадает в подборку хитов на витрине приложения */
  isBestSeller?: boolean;
  /** «Новинка» — попадает в подборку «Новое в меню» на витрине приложения */
  isNew?: boolean;
}

export interface Category {
  id: string;
  name: { ru: string; ky: string; en: string };
  sortOrder: number;
  active: boolean;
}

export interface ToppingCatalogItem {
  id: string;
  name: LocalizedText;
  price: number;
  sortOrder: number;
  active: boolean;
}

/** Визуал сторис (иконка-заглушка новости на витрине приложения) */
export type NewsVisual = "sparkle" | "storefront" | "qr" | "loyalty";

/** Новость-сторис витрины приложения (форма 1-в-1 с NewsStory приложения) */
export interface NewsStory {
  id: string;
  companyId: string;
  /** Порядок показа: по возрастанию */
  sortOrder: number;
  /** Опубликована ли сторис (иначе — черновик, приложению не видна) */
  isPublished: boolean;
  title: LocalizedText;
  body: LocalizedText;
  badge: LocalizedText;
  /** Акцентный цвет сторис, HEX (#RRGGBB) */
  accentColor: string;
  visual: NewsVisual;
  /** ISO-дата публикации */
  publishedAt: string;
  /** ISO-дата истечения или null (бессрочно) */
  expiresAt: string | null;
  imageUrl: string | null;
  /** Подпись кнопки перехода или null */
  ctaLabel: LocalizedText | null;
  /** Роут кнопки перехода в приложении или null */
  ctaRoute: string | null;
}

// V2 content contract. The server owns every media URL; the admin only sends
// files to the dedicated multipart endpoints and never persists arbitrary URLs.
export type ContentMediaType = "none" | "image" | "video";

export interface ContentMedia {
  type: ContentMediaType;
  url: string | null;
  thumbnailUrl?: string | null;
}

export interface ContentStory {
  id: string;
  companyId: string;
  collectionId: string | null;
  title: LocalizedText;
  body: LocalizedText;
  badge: LocalizedText;
  accentColor: string;
  visual: NewsVisual;
  isPublished: boolean;
  showOnHome: boolean;
  isPinned: boolean;
  sortOrder: number;
  publishedAt: string;
  expiresAt: string | null;
  media: ContentMedia;
  ctaLabel: LocalizedText | null;
  ctaRoute: string | null;
}

export interface StoryCollection {
  id: string;
  companyId: string;
  name: LocalizedText;
  description: LocalizedText;
  coverImageUrl: string | null;
  coverThumbnailUrl?: string | null;
  accentColor: string;
  visual: NewsVisual;
  sortOrder: number;
  isPublished: boolean;
  /** Summary count; the collection list never embeds all 40+ stories. */
  storyCount: number;
}

export interface NewsPost {
  id: string;
  companyId: string;
  title: LocalizedText;
  summary: LocalizedText;
  body: LocalizedText;
  isPublished: boolean;
  publishedAt: string;
  media: ContentMedia;
}

/** Сезонная акция витрины приложения */
export interface Promotion {
  id: string;
  companyId: string;
  /** Порядок показа: по возрастанию */
  sortOrder: number;
  /** Активна ли акция (иначе не показывается в приложении) */
  active: boolean;
  title: LocalizedText;
  description: LocalizedText;
  /** Промокод или null */
  code: string | null;
  /** Акцентный цвет карточки, HEX (#RRGGBB) */
  accentColor: string;
  imageUrl: string | null;
  thumbnailUrl: string | null;
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

export interface OrderItemTopping {
  id?: string;
  name: string;
  priceDelta?: number;
}

export interface OrderItem {
  /** Серверный snapshot названия; пустая строка означает, что legacy API его не дал. */
  name: string;
  productId?: string;
  sizeId?: string;
  toppingIds?: string[];
  quantity: number;
  /** Цена единицы приходит с V2 API или выводится только при точном делении total/quantity. */
  unitPrice?: number;
  /** Серверная сумма всей строки заказа. */
  lineTotal: number;
  imageUrl?: string;
  description?: string;
  size?: string;
  sugarPercent?: number;
  ice?: string;
  /** Display snapshots; stable IDs хранятся отдельно и не выдаются как названия. */
  toppings?: OrderItemTopping[];
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
  customerPhone?: string;
  branchName?: string;
  branchAddress?: string;
  readyTime?: string;
  comment?: string;
  itemsVersion?: 1 | 2;
  /** Может отсутствовать у старого demo API или локальных моков */
  paymentMethod?: PaymentMethod;
  promoCode?: string;
  paymentStatus?: string;
  subtotal?: number;
  discount?: number;
  pointsUsed?: number;
  pointsEarned?: number;
}

/** Срез данных одной компании — единственный формат выдачи данных компонентам */
export interface CompanyData {
  company: Company;
  branches: Branch[];
  products: Product[];
  orders: Order[];
  users: AdminUser[];
  recurring: RecurringOrder[];
  news: NewsStory[];
  promotions: Promotion[];
}
