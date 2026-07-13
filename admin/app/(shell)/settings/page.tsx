"use client";

// Настройки приложения (только owner): брендинг с живым превью телефона
// и правила лояльности/рефералки. Брендинг применяется мгновенно —
// updateCompany меняет company-store, откуда shell берёт --accent.

import { useEffect, useRef, useState, type FormEvent } from "react";
import {
  Bell,
  Check,
  Home,
  LayoutGrid,
  Plus,
  ShoppingCart,
  User
} from "lucide-react";
import { RoleGate } from "@/components/role-gate";
import { useCompanyStore } from "@/lib/company-store";
import type { Company, Product } from "@/lib/types";
import { cn, formatCurrency } from "@/lib/utils";

const ACCENT_PRESETS = [
  "#FF5C9A",
  "#34C99A",
  "#7C5CFF",
  "#FF8A3D",
  "#2D9CDB",
  "#F2C94C"
];

const HEX_RE = /^#?([0-9a-fA-F]{6})$/;

// ---------------------------------------------------------------------------
// Живое превью телефона: мини-версия главного экрана клиентского приложения
// ---------------------------------------------------------------------------

function PhonePreview({
  company,
  products
}: {
  company: Company;
  products: Product[];
}) {
  const accent = company.accentColor;
  const appName = company.appName.trim() || "Приложение";
  const letter = appName.charAt(0).toUpperCase();
  const drinks = products.filter((p) => p.active).slice(0, 2);

  const tabs = [
    { label: "Главная", icon: Home, active: true },
    { label: "Каталог", icon: LayoutGrid, active: false },
    { label: "Корзина", icon: ShoppingCart, active: false },
    { label: "Профиль", icon: User, active: false }
  ];

  return (
    // data-light: превью — макет клиентского приложения, всегда светлое
    // (исключается из dark-ремапа coffee-утилит в globals.css)
    <div
      data-light
      className="w-[280px] shrink-0 rounded-[2.75rem] bg-coffee-900 p-2.5 shadow-soft"
    >
      <div className="flex h-[560px] flex-col overflow-hidden rounded-[2.25rem] bg-cream-50">
        {/* Статус-бар */}
        <div className="flex items-center justify-between px-6 pt-3 text-[10px] font-semibold text-coffee-900">
          <span>9:41</span>
          <span className="flex items-center gap-1">
            <span className="h-1.5 w-1.5 rounded-full bg-coffee-900/60" />
            <span className="h-1.5 w-1.5 rounded-full bg-coffee-900/60" />
            <span className="h-1.5 w-1.5 rounded-full bg-coffee-900/60" />
          </span>
        </div>

        {/* Шапка приложения */}
        <div className="flex items-center justify-between px-5 pt-4">
          <div className="flex min-w-0 items-center gap-2">
            <span
              className="flex h-8 w-8 shrink-0 items-center justify-center rounded-xl text-sm font-bold text-white"
              style={{ backgroundColor: accent }}
            >
              {letter}
            </span>
            <div className="min-w-0">
              <p className="truncate text-[13px] font-semibold leading-tight text-coffee-900">
                {appName}
              </p>
              <p className="text-[10px] text-coffee-500">Привет, Айгерим!</p>
            </div>
          </div>
          <Bell className="h-4 w-4 shrink-0 text-coffee-500" />
        </div>

        {/* Hero-карточка */}
        <div
          className="mx-4 mt-3 rounded-2xl p-4 text-white"
          style={{
            background: `linear-gradient(135deg, ${accent}, ${accent}B3)`
          }}
        >
          <p className="text-[13px] font-semibold leading-snug">
            Соберём любимый напиток к 11:00?
          </p>
          <span className="mt-2.5 inline-block rounded-full bg-white/25 px-3 py-1 text-[10px] font-semibold">
            Заказать
          </span>
        </div>

        {/* Карточки напитков из меню компании */}
        <p className="px-5 pb-2 pt-4 text-[11px] font-semibold text-coffee-900">
          Хиты меню
        </p>
        <div className="grid grid-cols-2 gap-2 px-4">
          {drinks.map((drink) => (
            <div
              key={drink.id}
              className="rounded-xl border border-coffee-900/10 bg-white p-2.5"
            >
              <span
                className="block h-10 w-10 rounded-full"
                style={{ backgroundColor: drink.color }}
                aria-hidden="true"
              />
              <p className="mt-1.5 truncate text-[10px] font-semibold text-coffee-900">
                {drink.name}
              </p>
              <div className="mt-0.5 flex items-center justify-between">
                <p className="text-[10px] font-semibold" style={{ color: accent }}>
                  {formatCurrency(drink.price, company.currency)}
                </p>
                <span
                  className="flex h-5 w-5 items-center justify-center rounded-full text-white"
                  style={{ backgroundColor: accent }}
                >
                  <Plus className="h-3 w-3" />
                </span>
              </div>
            </div>
          ))}
        </div>

        {/* Нижняя таб-навигация */}
        <div className="mt-auto border-t border-coffee-900/10 bg-white/85 px-5 pb-4 pt-2.5">
          <div className="flex items-start justify-between">
            {tabs.map((tab) => {
              const Icon = tab.icon;
              return (
                <span
                  key={tab.label}
                  className="flex flex-col items-center gap-0.5"
                >
                  <Icon
                    className="h-4 w-4"
                    style={{
                      color: tab.active ? accent : "rgba(75, 45, 34, 0.5)"
                    }}
                  />
                  <span
                    className="text-[8px] font-medium"
                    style={{
                      color: tab.active ? accent : "rgba(75, 45, 34, 0.5)"
                    }}
                  >
                    {tab.label}
                  </span>
                </span>
              );
            })}
          </div>
        </div>
      </div>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Страница настроек
// ---------------------------------------------------------------------------

function SettingsContent() {
  const { company, products, updateCompany } = useCompanyStore();

  // Черновик hex-поля (акцент применяется только при валидном значении)
  const [hexDraft, setHexDraft] = useState(company.accentColor);
  useEffect(() => {
    setHexDraft(company.accentColor);
  }, [company.accentColor]);

  function applyHex(raw: string) {
    setHexDraft(raw);
    const match = HEX_RE.exec(raw.trim());
    if (match) {
      updateCompany({ accentColor: `#${match[1].toUpperCase()}` });
    }
  }

  // Черновик правил лояльности (применяется по кнопке «Сохранить»)
  const [loyaltyDraft, setLoyaltyDraft] = useState({
    earn: String(Math.round(company.loyalty.earnRate * 100)),
    spend: String(Math.round(company.loyalty.maxSpendShare * 100)),
    expiry: String(company.loyalty.expiryMonths),
    invited: String(company.referral.invitedBonus),
    inviter: String(company.referral.inviterBonus)
  });
  const [toastVisible, setToastVisible] = useState(false);
  const toastTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(
    () => () => {
      if (toastTimer.current) clearTimeout(toastTimer.current);
    },
    []
  );

  function saveLoyalty(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const clampPct = (v: string) =>
      Math.min(100, Math.max(0, Math.round(Number(v)) || 0));
    const clampNum = (v: string) => Math.max(0, Math.round(Number(v)) || 0);

    updateCompany({
      loyalty: {
        earnRate: clampPct(loyaltyDraft.earn) / 100,
        maxSpendShare: clampPct(loyaltyDraft.spend) / 100,
        expiryMonths: clampNum(loyaltyDraft.expiry)
      },
      referral: {
        invitedBonus: clampNum(loyaltyDraft.invited),
        inviterBonus: clampNum(loyaltyDraft.inviter)
      }
    });
    setToastVisible(true);
    if (toastTimer.current) clearTimeout(toastTimer.current);
    toastTimer.current = setTimeout(() => setToastVisible(false), 2500);
  }

  const numberField = (
    label: string,
    key: keyof typeof loyaltyDraft,
    suffix: string
  ) => (
    <label className="block">
      <span className="mb-1.5 block text-sm font-medium text-coffee-700">
        {label}
      </span>
      <div className="flex items-center gap-2">
        <input
          type="number"
          min={0}
          value={loyaltyDraft[key]}
          onChange={(e) =>
            setLoyaltyDraft({ ...loyaltyDraft, [key]: e.target.value })
          }
          className="input w-28"
        />
        <span className="text-sm text-coffee-500">{suffix}</span>
      </div>
    </label>
  );

  return (
    <div>
      <h1 className="text-2xl">Настройки приложения</h1>
      <p className="mt-1 text-sm text-coffee-500">
        Брендинг клиентского приложения {company.name} и правила лояльности
      </p>

      {/* Брендинг */}
      <section className="surface mt-6 px-6 py-6">
        <h2 className="text-base">Брендинг</h2>
        <p className="mt-1 text-sm text-coffee-500">
          Изменения сразу видны в превью и применяются к админке
        </p>

        <div className="mt-5 flex flex-col gap-8 lg:flex-row">
          <div className="max-w-md flex-1 space-y-5">
            <div className="flex items-center gap-3">
              <span
                className="flex h-12 w-12 shrink-0 items-center justify-center rounded-2xl text-lg font-bold text-white"
                style={{ backgroundColor: company.accentColor }}
              >
                {(company.appName.trim() || "П").charAt(0).toUpperCase()}
              </span>
              <label className="flex-1">
                <span className="mb-1.5 block text-sm font-medium text-coffee-700">
                  Название приложения
                </span>
                <input
                  value={company.appName}
                  onChange={(e) => updateCompany({ appName: e.target.value })}
                  placeholder="SweetTime"
                  className="input"
                />
              </label>
            </div>

            <div>
              <p className="mb-1.5 text-sm font-medium text-coffee-700">
                Акцентный цвет
              </p>
              <div className="flex flex-wrap items-center gap-2">
                {ACCENT_PRESETS.map((color) => (
                  <button
                    key={color}
                    type="button"
                    onClick={() => updateCompany({ accentColor: color })}
                    title={color}
                    style={{ backgroundColor: color }}
                    className={cn(
                      "focus-ring flex h-10 w-10 items-center justify-center rounded-full transition",
                      company.accentColor.toUpperCase() === color &&
                        "ring-2 ring-coffee-900 ring-offset-2 dark:ring-cream-50 dark:ring-offset-[#231d21]"
                    )}
                  >
                    {company.accentColor.toUpperCase() === color && (
                      <Check className="h-4 w-4 text-white" />
                    )}
                  </button>
                ))}
              </div>
              <label className="mt-3 block">
                <span className="mb-1.5 block text-sm font-medium text-coffee-700">
                  Свой цвет (hex)
                </span>
                <div className="flex items-center gap-2">
                  <span
                    className="h-9 w-9 shrink-0 rounded-full border border-coffee-900/10"
                    style={{ backgroundColor: company.accentColor }}
                    aria-hidden="true"
                  />
                  <input
                    value={hexDraft}
                    onChange={(e) => applyHex(e.target.value)}
                    placeholder="#FF5C9A"
                    className="input w-36 font-mono"
                  />
                </div>
                {!HEX_RE.test(hexDraft.trim()) && (
                  <span className="mt-1 block text-xs text-coffee-500">
                    Формат: #RRGGBB — применится после полного ввода
                  </span>
                )}
              </label>
            </div>
          </div>

          <PhonePreview company={company} products={products} />
        </div>
      </section>

      {/* Лояльность и рефералка */}
      <section className="surface mt-6 px-6 py-6">
        <h2 className="text-base">Правила лояльности и рефералки</h2>
        <p className="mt-1 text-sm text-coffee-500">
          1 балл = 1 {company.currency}. Значения применяются к клиентскому
          приложению
        </p>

        <form onSubmit={saveLoyalty} className="mt-5 max-w-2xl">
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {numberField("Кешбэк баллами", "earn", "% от заказа")}
            {numberField("Лимит списания", "spend", "% заказа")}
            {numberField("Сгорание баллов", "expiry", "мес.")}
            {numberField("Бонус приглашённому", "invited", "баллов")}
            {numberField("Бонус пригласившему", "inviter", "баллов")}
          </div>
          <button
            type="submit"
            className="focus-ring mt-6 flex h-11 items-center rounded-full bg-accent px-6 text-sm font-semibold text-white transition hover:opacity-90"
          >
            Сохранить
          </button>
        </form>
      </section>

      {/* Тост */}
      {toastVisible && (
        <div
          role="status"
          className="fixed bottom-6 right-6 z-50 flex items-center gap-2 rounded-full bg-coffee-900 px-5 py-2.5 text-sm font-medium text-white shadow-soft dark:bg-cream-50 dark:text-coffee-900"
        >
          <Check className="h-4 w-4 text-mint-300 dark:text-emerald-600" />
          Сохранено
        </div>
      )}
    </div>
  );
}

export default function SettingsPage() {
  return (
    <RoleGate allow={["owner"]}>
      <SettingsContent />
    </RoleGate>
  );
}
