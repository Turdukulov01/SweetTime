export type Size = 'S' | 'M' | 'L';
export type IceLevel = 'Без льда' | 'Мало льда' | 'Стандарт' | 'Много льда';
export type SugarLevel = '0%' | '30%' | '50%' | '70%' | '100%' | '120%';

export interface Topping {
  id: string;
  name: string;
  price: number;
}

export interface Review {
  id: string;
  author: string;
  avatarColor: string;
  rating: 1 | 2 | 3 | 4 | 5;
  date: string;
  text: string;
  productId?: string;
}

export interface Category {
  id: string;
  name: string;
  slug: string;
  emoji: string;
  color: 'pink' | 'mint' | 'caramel';
}

export interface Product {
  id: string;
  name: string;
  slug: string;
  categoryId: string;
  price: number;
  oldPrice?: number;
  images: string[];
  description: string;
  tags: Array<'new' | 'bestseller' | 'sale' | 'signature'>;
  rating: number;
  reviewsCount: number;
  calories: number;
  caffeine: 'нет' | 'низкое' | 'среднее' | 'высокое';
  availableSizes: Size[];
  availableToppings: string[];
}

export interface CartCustomization {
  size: Size;
  ice: IceLevel;
  sugar: SugarLevel;
  toppingIds: string[];
}

export interface CartItem {
  id: string;
  productId: string;
  quantity: number;
  customization: CartCustomization;
  unitPrice: number;
}

export interface Address {
  id: string;
  label: string;
  street: string;
  apartment?: string;
  city: string;
  comment?: string;
  isDefault?: boolean;
}

export type OrderStatus =
  | 'processing'
  | 'preparing'
  | 'delivering'
  | 'completed'
  | 'cancelled';

export interface Order {
  id: string;
  date: string;
  status: OrderStatus;
  items: Array<{
    name: string;
    quantity: number;
    price: number;
    customization: string;
  }>;
  total: number;
  bonusesEarned: number;
  deliveryType: 'delivery' | 'pickup';
}

export interface User {
  id: string;
  name: string;
  phone: string;
  email?: string;
  bonusBalance: number;
  favoriteDrinkIds: string[];
  addresses: Address[];
}

export interface Coupon {
  id: string;
  code: string;
  type: 'percent' | 'fixed';
  value: number;
  minOrder?: number;
  active: boolean;
  usageCount: number;
  expiresAt: string;
}

export interface AdminOrderRow {
  id: string;
  customer: string;
  total: number;
  status: OrderStatus;
  date: string;
  itemsCount: number;
}

export interface AdminUser {
  id: string;
  name: string;
  phone: string;
  orders: number;
  bonusBalance: number;
  joined: string;
}

export interface AnalyticsPoint {
  label: string;
  revenue: number;
  orders: number;
}
