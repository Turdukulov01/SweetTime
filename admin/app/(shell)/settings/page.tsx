"use client";

// Настройки приложения (только owner): локальный черновик даёт живое превью,
// но общий store, телефон и API меняются только после явного «Сохранить».

import { useEffect, useRef, useState, type FormEvent } from "react";
import {
  Bell,
  Check,
  Home,
  ImageIcon,
  LayoutGrid,
  Plus,
  ShoppingCart,
  User
} from "lucide-react";
import { RoleGate } from "@/components/role-gate";
import { useCompanyStore } from "@/lib/company-store";
import type { Company, NewsStory, Product, Promotion } from "@/lib/types";
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

function PreviewDrinkCard({
  drink,
  accent,
  currency
}: {
  drink: Product;
  accent: string;
  currency: string;
}) {
  return (
    <div className="rounded-xl border border-coffee-900/10 bg-white p-2.5">
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
          {formatCurrency(drink.price, currency)}
        </p>
        <span
          className="flex h-5 w-5 items-center justify-center rounded-full text-white"
          style={{ backgroundColor: accent }}
        >
          <Plus className="h-3 w-3" />
        </span>
      </div>
    </div>
  );
}

function PhonePreview({
  company,
  products,
  news,
  promotions
}: {
  company: Company;
  products: Product[];
  news: NewsStory[];
  promotions: Promotion[];
}) {
  const accent = company.accentColor;
  const appName = company.appName.trim() || "Приложение";

  const stories = [...news]
    .filter((n) => n.isPublished)
    .sort((a, b) => a.sortOrder - b.sortOrder)
    .slice(0, 4);
  const promo = [...promotions]
    .filter((p) => p.active)
    .sort((a, b) => a.sortOrder - b.sortOrder)[0];
  const bestSellers = products
    .filter((p) => p.active && p.isBestSeller)
    .slice(0, 2);
  const newItems = products.filter((p) => p.active && p.isNew).slice(0, 2);
  // fallback, чтобы блоки не были пустыми, если флаги ещё не проставлены
  const hits = bestSellers.length ? bestSellers : products.filter((p) => p.active).slice(0, 2);

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
      <div
        className="flex h-[560px] flex-col overflow-hidden rounded-[2.25rem] bg-cream-50 bg-cover bg-center"
        style={{
          backgroundColor: company.background.lightBase,
          backgroundImage:
            company.background.kind === "image" && company.background.imageUrl
              ? `url(${company.background.imageUrl})`
              : undefined
        }}
      >
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
        <div className="flex items-center justify-between px-5 pb-1 pt-3">
          <div className="flex min-w-0 items-center gap-2">
            <span className="flex h-8 w-8 shrink-0 items-center justify-center overflow-hidden rounded-xl bg-coffee-900/5">
              {company.logoThumbnailUrl || company.logoUrl ? (
                <img src={company.logoThumbnailUrl || company.logoUrl || ""} alt="" className="h-full w-full object-cover" />
              ) : (
                <ImageIcon className="h-4 w-4 text-coffee-400" />
              )}
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

        {/* Прокручиваемое содержимое главного экрана */}
        <div className="flex-1 overflow-y-auto pb-2">
          {/* Лента сторис (новости) */}
          {stories.length > 0 && (
            <div className="flex gap-3 overflow-x-auto px-5 py-3">
              {stories.map((story) => (
                <span
                  key={story.id}
                  className="flex w-12 shrink-0 flex-col items-center gap-1"
                >
                  <span
                    className="flex h-12 w-12 items-center justify-center rounded-full p-[2px]"
                    style={{ background: `linear-gradient(135deg, ${story.accentColor}, ${story.accentColor}80)` }}
                  >
                    <span className="flex h-full w-full items-center justify-center rounded-full bg-cream-50 text-[9px] font-bold" style={{ color: story.accentColor }}>
                      {(story.badge.ru || story.title.ru || "•").charAt(0)}
                    </span>
                  </span>
                  <span className="w-full truncate text-center text-[8px] text-coffee-700">
                    {story.title.ru}
                  </span>
                </span>
              ))}
            </div>
          )}

          {/* Сезонная акция */}
          {promo && (
            <div
              className="mx-4 mt-1 rounded-2xl p-4 text-white"
              style={{ background: `linear-gradient(135deg, ${promo.accentColor}, ${promo.accentColor}B3)` }}
            >
              <p className="text-[9px] font-semibold uppercase tracking-wide text-white/80">
                Сезонная акция
              </p>
              <p className="mt-0.5 text-[13px] font-semibold leading-snug">
                {promo.title.ru}
              </p>
              {promo.code && (
                <span className="mt-2 inline-block rounded-full bg-white/25 px-3 py-1 font-mono text-[10px] font-bold">
                  {promo.code}
                </span>
              )}
            </div>
          )}

          {/* Хиты продаж */}
          <p className="px-5 pb-2 pt-4 text-[11px] font-semibold text-coffee-900">
            Хиты продаж
          </p>
          <div className="grid grid-cols-2 gap-2 px-4">
            {hits.map((drink) => (
              <PreviewDrinkCard
                key={drink.id}
                drink={drink}
                accent={accent}
                currency={company.currency}
              />
            ))}
          </div>

          {/* Новое в меню */}
          {newItems.length > 0 && (
            <>
              <p className="px-5 pb-2 pt-4 text-[11px] font-semibold text-coffee-900">
                Новое в меню
              </p>
              <div className="grid grid-cols-2 gap-2 px-4">
                {newItems.map((drink) => (
                  <PreviewDrinkCard
                    key={drink.id}
                    drink={drink}
                    accent={accent}
                    currency={company.currency}
                  />
                ))}
              </div>
            </>
          )}
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
  const {
    company, products, news, promotions, updateCompany,
    putCompanyLogo, deleteCompanyLogo,
    putCompanyBackground, deleteCompanyBackground
  } = useCompanyStore();

  const [brandingDraft, setBrandingDraft] = useState({
    appName: company.appName,
    accentColor: company.accentColor,
    background: company.background
  });
  const [logoFile, setLogoFile] = useState<File | null>(null);
  const [backgroundFile, setBackgroundFile] = useState<File | null>(null);
  const [removeLogo, setRemoveLogo] = useState(false);
  const [removeBackground, setRemoveBackground] = useState(false);
  const [hexDraft, setHexDraft] = useState(company.accentColor);
  useEffect(() => {
    setBrandingDraft({
      appName: company.appName,
      accentColor: company.accentColor,
      background: company.background
    });
    setHexDraft(company.accentColor);
  }, [company.appName, company.accentColor, company.background]);

  const logoPreview = logoFile ? URL.createObjectURL(logoFile) : null;
  const backgroundPreview = backgroundFile ? URL.createObjectURL(backgroundFile) : null;
  useEffect(() => () => {
    if (logoPreview) URL.revokeObjectURL(logoPreview);
    if (backgroundPreview) URL.revokeObjectURL(backgroundPreview);
  }, [logoPreview, backgroundPreview]);

  function applyHex(raw: string) {
    setHexDraft(raw);
    const match = HEX_RE.exec(raw.trim());
    if (match) {
      setBrandingDraft((current) => ({
        ...current,
        accentColor: `#${match[1].toUpperCase()}`
      }));
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
  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);
  const toastTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(
    () => () => {
      if (toastTimer.current) clearTimeout(toastTimer.current);
    },
    []
  );

  async function saveSettings(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const clampPct = (v: string) =>
      Math.min(100, Math.max(0, Math.round(Number(v)) || 0));
    const clampNum = (v: string) => Math.max(0, Math.round(Number(v)) || 0);

    setSaving(true);
    setSaveError(null);
    try {
      await updateCompany({
        appName: brandingDraft.appName.trim() || company.appName,
        accentColor: brandingDraft.accentColor,
        background: brandingDraft.background,
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
      if (removeLogo) await deleteCompanyLogo();
      if (logoFile) await putCompanyLogo(logoFile);
      if (removeBackground) await deleteCompanyBackground();
      if (backgroundFile) await putCompanyBackground(backgroundFile);
      setLogoFile(null);
      setBackgroundFile(null);
      setRemoveLogo(false);
      setRemoveBackground(false);
      setToastVisible(true);
      if (toastTimer.current) clearTimeout(toastTimer.current);
      toastTimer.current = setTimeout(() => setToastVisible(false), 2500);
    } catch {
      setSaveError("Не удалось сохранить настройки. Изменения остались в черновике.");
    } finally {
      setSaving(false);
    }
  }

  const previewCompany: Company = { ...company, ...brandingDraft };

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
          Изменения видны только в превью до нажатия «Сохранить»
        </p>

        <div className="mt-5 flex flex-col gap-8 lg:flex-row">
          <div className="max-w-md flex-1 space-y-5">
            <div className="flex items-center gap-3">
              <span className="flex h-12 w-12 shrink-0 items-center justify-center overflow-hidden rounded-2xl bg-coffee-900/5">
                {!removeLogo && (logoPreview || company.logoThumbnailUrl || company.logoUrl) ? (
                  <img src={logoPreview || company.logoThumbnailUrl || company.logoUrl || ""} alt="Предпросмотр логотипа" className="h-full w-full object-cover" />
                ) : (
                  <ImageIcon className="h-6 w-6 text-coffee-400" />
                )}
              </span>
              <label className="flex-1">
                <span className="mb-1.5 block text-sm font-medium text-coffee-700">
                  Название приложения
                </span>
                <input
                  value={brandingDraft.appName}
                  onChange={(e) =>
                    setBrandingDraft({
                      ...brandingDraft,
                      appName: e.target.value
                    })
                  }
                  placeholder="SweetTime"
                  className="input"
                />
              </label>
            </div>

            <div>
              <p className="mb-1.5 text-sm font-medium text-coffee-700">Логотип бизнеса</p>
              <input
                type="file"
                accept="image/png,image/jpeg,image/webp"
                onChange={(event) => {
                  setLogoFile(event.target.files?.[0] ?? null);
                  setRemoveLogo(false);
                }}
                className="input"
              />
              {(logoFile || company.logoUrl) && (
                <button type="button" className="mt-2 text-sm text-red-600" onClick={() => { setLogoFile(null); setRemoveLogo(true); }}>
                  Убрать логотип
                </button>
              )}
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
                    onClick={() => {
                      setBrandingDraft({ ...brandingDraft, accentColor: color });
                      setHexDraft(color);
                    }}
                    title={color}
                    style={{ backgroundColor: color }}
                    className={cn(
                      "focus-ring flex h-10 w-10 items-center justify-center rounded-full transition",
                      brandingDraft.accentColor.toUpperCase() === color &&
                        "ring-2 ring-coffee-900 ring-offset-2 dark:ring-cream-50 dark:ring-offset-[#231d21]"
                    )}
                  >
                    {brandingDraft.accentColor.toUpperCase() === color && (
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
                    style={{ backgroundColor: brandingDraft.accentColor }}
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

            <div className="space-y-3 border-t border-coffee-900/10 pt-4">
              <p className="text-sm font-medium text-coffee-700">Фон приложения</p>
              <div className="grid grid-cols-2 gap-3">
                <label className="text-sm">Стиль
                  <select className="input mt-1" value={brandingDraft.background.kind} onChange={(e) => setBrandingDraft({ ...brandingDraft, background: { ...brandingDraft.background, kind: e.target.value as "plain" | "pattern" | "image" } })}>
                    <option value="plain">Однотонный</option>
                    <option value="pattern">Узор</option>
                    <option value="image">Своя картинка</option>
                  </select>
                </label>
                <label className="text-sm">Узор
                  <select className="input mt-1" value={brandingDraft.background.preset} onChange={(e) => setBrandingDraft({ ...brandingDraft, background: { ...brandingDraft.background, preset: e.target.value as "none" | "bubbles" | "doodles" | "coffee" } })}>
                    <option value="none">Без узора</option>
                    <option value="bubbles">Пузырьки</option>
                    <option value="doodles">Дудлы</option>
                    <option value="coffee">Кофе</option>
                  </select>
                </label>
                <label className="text-sm">Светлый фон
                  <input type="color" className="mt-1 h-11 w-full rounded-xl" value={brandingDraft.background.lightBase} onChange={(e) => setBrandingDraft({ ...brandingDraft, background: { ...brandingDraft.background, lightBase: e.target.value.toUpperCase() } })} />
                </label>
                <label className="text-sm">Тёмный фон
                  <input type="color" className="mt-1 h-11 w-full rounded-xl" value={brandingDraft.background.darkBase} onChange={(e) => setBrandingDraft({ ...brandingDraft, background: { ...brandingDraft.background, darkBase: e.target.value.toUpperCase() } })} />
                </label>
              </div>
              <input type="file" accept="image/png,image/jpeg,image/webp" onChange={(event) => { setBackgroundFile(event.target.files?.[0] ?? null); setRemoveBackground(false); setBrandingDraft({ ...brandingDraft, background: { ...brandingDraft.background, kind: "image" } }); }} className="input" />
              {!removeBackground && (backgroundPreview || company.background.imageUrl) && (
                <img src={backgroundPreview || company.background.thumbnailUrl || company.background.imageUrl || ""} alt="Предпросмотр фона" className="h-28 w-full rounded-2xl object-cover" />
              )}
              {(backgroundFile || company.background.imageUrl) && (
                <button type="button" className="text-sm text-red-600" onClick={() => { setBackgroundFile(null); setRemoveBackground(true); setBrandingDraft({ ...brandingDraft, background: { ...brandingDraft.background, kind: "plain" } }); }}>
                  Убрать изображение фона
                </button>
              )}
            </div>
          </div>

          <PhonePreview
            company={previewCompany}
            products={products}
            news={news}
            promotions={promotions}
          />
        </div>
      </section>

      {/* Лояльность и рефералка */}
      <section className="surface mt-6 px-6 py-6">
        <h2 className="text-base">Правила лояльности и рефералки</h2>
        <p className="mt-1 text-sm text-coffee-500">
          1 балл = 1 {company.currency}. Значения применяются к клиентскому
          приложению
        </p>

        <form onSubmit={saveSettings} className="mt-5 max-w-2xl">
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {numberField("Кешбэк баллами", "earn", "% от заказа")}
            {numberField("Лимит списания", "spend", "% заказа")}
            {numberField("Сгорание баллов", "expiry", "мес.")}
            {numberField("Бонус приглашённому", "invited", "баллов")}
            {numberField("Бонус пригласившему", "inviter", "баллов")}
          </div>
          <button
            type="submit"
            disabled={saving || !HEX_RE.test(hexDraft.trim())}
            style={{ backgroundColor: brandingDraft.accentColor }}
            className="focus-ring mt-6 flex h-11 items-center rounded-full px-6 text-sm font-semibold text-white transition hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-50"
          >
            {saving ? "Сохраняем…" : "Сохранить все настройки"}
          </button>
          {saveError && (
            <p role="alert" className="mt-3 text-sm text-red-600">
              {saveError}
            </p>
          )}
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
