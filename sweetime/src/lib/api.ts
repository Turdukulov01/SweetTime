/**
 * API layer for Sweetime.
 *
 * Every function here returns a Promise and is the single seam between the UI
 * and data. Today it resolves against local mock data with a small simulated
 * delay; swap the body of each function for a `fetch(`${API_BASE}/...`)` call
 * once the real backend (см. Этап 13) is available — no component code needs
 * to change.
 */
import {
  ADMIN_ORDERS,
  ADMIN_USERS,
  ANALYTICS,
  CATEGORIES,
  COUPONS,
  MOCK_ORDERS,
  MOCK_USER,
  PRODUCTS,
  REVIEWS,
  getProductBySlug,
} from '@/lib/mock-data';
import type { Order, Product, User } from '@/types';

export const API_BASE = process.env.NEXT_PUBLIC_API_BASE_URL ?? '/api';

function delay<T>(value: T, ms = 250): Promise<T> {
  return new Promise((resolve) => setTimeout(() => resolve(value), ms));
}

export interface ProductQuery {
  search?: string;
  categorySlug?: string;
  tag?: Product['tags'][number];
  sort?: 'popular' | 'price-asc' | 'price-desc' | 'rating' | 'new';
  page?: number;
  perPage?: number;
}

export interface ProductQueryResult {
  items: Product[];
  total: number;
  page: number;
  perPage: number;
}

export async function fetchProducts(query: ProductQuery = {}): Promise<ProductQueryResult> {
  const { search, categorySlug, tag, sort = 'popular', page = 1, perPage = 8 } = query;

  let items = [...PRODUCTS];

  if (search) {
    const q = search.trim().toLowerCase();
    items = items.filter(
      (p) => p.name.toLowerCase().includes(q) || p.description.toLowerCase().includes(q),
    );
  }

  if (categorySlug) {
    const cat = CATEGORIES.find((c) => c.slug === categorySlug);
    if (cat) items = items.filter((p) => p.categoryId === cat.id);
  }

  if (tag) {
    items = items.filter((p) => p.tags.includes(tag));
  }

  switch (sort) {
    case 'price-asc':
      items.sort((a, b) => a.price - b.price);
      break;
    case 'price-desc':
      items.sort((a, b) => b.price - a.price);
      break;
    case 'rating':
      items.sort((a, b) => b.rating - a.rating);
      break;
    case 'new':
      items.sort((a, b) => Number(b.tags.includes('new')) - Number(a.tags.includes('new')));
      break;
    default:
      items.sort((a, b) => b.reviewsCount - a.reviewsCount);
  }

  const total = items.length;
  const start = (page - 1) * perPage;
  const paged = items.slice(start, start + perPage);

  return delay({ items: paged, total, page, perPage });
}

export async function fetchProductBySlug(slug: string): Promise<Product | null> {
  return delay(getProductBySlug(slug) ?? null);
}

export async function fetchCategories() {
  return delay(CATEGORIES);
}

export async function fetchReviews(productId?: string) {
  return delay(productId ? REVIEWS.filter((r) => r.productId === productId) : REVIEWS);
}

export async function fetchCurrentUser(): Promise<User> {
  return delay(MOCK_USER);
}

export async function fetchOrders(): Promise<Order[]> {
  return delay(MOCK_ORDERS);
}

export async function fetchAdminOrders() {
  return delay(ADMIN_ORDERS);
}

export async function fetchAdminUsers() {
  return delay(ADMIN_USERS);
}

export async function fetchCoupons() {
  return delay(COUPONS);
}

export async function fetchAnalytics() {
  return delay(ANALYTICS);
}

export async function validateCoupon(code: string) {
  const coupon = COUPONS.find((c) => c.code.toLowerCase() === code.trim().toLowerCase());
  if (!coupon || !coupon.active) {
    return delay({ valid: false as const, message: 'Промокод не найден или больше не активен' });
  }
  return delay({ valid: true as const, coupon });
}

// --- Auth stubs -----------------------------------------------------------
// Replace with real calls to your auth backend / NextAuth / Clerk / etc.

export async function requestSmsCode(phone: string) {
  console.info(`[mock] SMS code requested for ${phone}`);
  return delay({ success: true, devCode: '0000' }, 600);
}

export async function verifySmsCode(phone: string, code: string) {
  return delay({ success: code === '0000', user: code === '0000' ? MOCK_USER : null }, 500);
}

export async function loginWithProvider(provider: 'google' | 'apple') {
  console.info(`[mock] OAuth login requested via ${provider}`);
  return delay({ success: true, user: MOCK_USER }, 600);
}
