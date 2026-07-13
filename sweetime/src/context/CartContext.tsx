'use client';

import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import type { CartCustomization, CartItem, Coupon } from '@/types';
import { BONUS_MAX_REDEEM_SHARE, DELIVERY_FEE, FREE_DELIVERY_THRESHOLD } from '@/lib/constants';
import { validateCoupon } from '@/lib/api';

const STORAGE_KEY = 'sweetime:cart';

interface CartContextValue {
  items: CartItem[];
  addItem: (productId: string, unitPrice: number, customization: CartCustomization, quantity?: number) => void;
  removeItem: (itemId: string) => void;
  updateQuantity: (itemId: string, quantity: number) => void;
  clearCart: () => void;
  coupon: Coupon | null;
  couponError: string | null;
  applyCoupon: (code: string) => Promise<void>;
  removeCoupon: () => void;
  redeemedBonuses: number;
  setRedeemedBonuses: (n: number) => void;
  subtotal: number;
  discount: number;
  deliveryFee: number;
  total: number;
  itemCount: number;
}

const CartContext = createContext<CartContextValue | null>(null);

function makeItemId(productId: string, customization: CartCustomization) {
  return `${productId}__${customization.size}__${customization.ice}__${customization.sugar}__${customization.toppingIds
    .slice()
    .sort()
    .join(',')}`;
}

export function CartProvider({ children }: { children: React.ReactNode }) {
  const [items, setItems] = useState<CartItem[]>([]);
  const [coupon, setCoupon] = useState<Coupon | null>(null);
  const [couponError, setCouponError] = useState<string | null>(null);
  const [redeemedBonuses, setRedeemedBonuses] = useState(0);
  const [hydrated, setHydrated] = useState(false);

  useEffect(() => {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (raw) setItems(JSON.parse(raw));
    } catch {
      // ignore corrupted storage
    } finally {
      setHydrated(true);
    }
  }, []);

  useEffect(() => {
    if (!hydrated) return;
    localStorage.setItem(STORAGE_KEY, JSON.stringify(items));
  }, [items, hydrated]);

  const addItem = useCallback<CartContextValue['addItem']>(
    (productId, unitPrice, customization, quantity = 1) => {
      const id = makeItemId(productId, customization);
      setItems((prev) => {
        const existing = prev.find((i) => i.id === id);
        if (existing) {
          return prev.map((i) => (i.id === id ? { ...i, quantity: i.quantity + quantity } : i));
        }
        return [...prev, { id, productId, quantity, customization, unitPrice }];
      });
    },
    [],
  );

  const removeItem = useCallback((itemId: string) => {
    setItems((prev) => prev.filter((i) => i.id !== itemId));
  }, []);

  const updateQuantity = useCallback((itemId: string, quantity: number) => {
    setItems((prev) =>
      quantity <= 0
        ? prev.filter((i) => i.id !== itemId)
        : prev.map((i) => (i.id === itemId ? { ...i, quantity } : i)),
    );
  }, []);

  const clearCart = useCallback(() => {
    setItems([]);
    setCoupon(null);
    setRedeemedBonuses(0);
  }, []);

  const applyCoupon = useCallback(async (code: string) => {
    setCouponError(null);
    const result = await validateCoupon(code);
    if (result.valid) {
      setCoupon(result.coupon);
    } else {
      setCoupon(null);
      setCouponError(result.message);
    }
  }, []);

  const removeCoupon = useCallback(() => {
    setCoupon(null);
    setCouponError(null);
  }, []);

  const subtotal = useMemo(
    () => items.reduce((sum, i) => sum + i.unitPrice * i.quantity, 0),
    [items],
  );

  const couponDiscount = useMemo(() => {
    if (!coupon) return 0;
    if (coupon.minOrder && subtotal < coupon.minOrder) return 0;
    return coupon.type === 'percent' ? Math.round((subtotal * coupon.value) / 100) : coupon.value;
  }, [coupon, subtotal]);

  const maxBonusRedeem = Math.floor(subtotal * BONUS_MAX_REDEEM_SHARE);
  const effectiveBonuses = Math.min(redeemedBonuses, maxBonusRedeem);

  const discount = couponDiscount + effectiveBonuses;

  const deliveryFee = subtotal === 0 || subtotal >= FREE_DELIVERY_THRESHOLD ? 0 : DELIVERY_FEE;

  const total = Math.max(subtotal - discount, 0) + deliveryFee;

  const itemCount = items.reduce((sum, i) => sum + i.quantity, 0);

  const value: CartContextValue = {
    items,
    addItem,
    removeItem,
    updateQuantity,
    clearCart,
    coupon,
    couponError,
    applyCoupon,
    removeCoupon,
    redeemedBonuses: effectiveBonuses,
    setRedeemedBonuses,
    subtotal,
    discount,
    deliveryFee,
    total,
    itemCount,
  };

  return <CartContext.Provider value={value}>{children}</CartContext.Provider>;
}

export function useCart() {
  const ctx = useContext(CartContext);
  if (!ctx) throw new Error('useCart must be used within CartProvider');
  return ctx;
}
