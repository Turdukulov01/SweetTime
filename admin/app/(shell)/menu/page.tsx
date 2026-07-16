"use client";

// Меню компании: таблица товаров + боковая панель создания/редактирования.
// Мутации company-store подтверждаются боевым product API и откатываются при ошибке.

import { useEffect, useState, type ReactNode } from "react";
import { ImageIcon, Minus, Pencil, Plus, X } from "lucide-react";
import { RoleGate } from "@/components/role-gate";
import { Toggle } from "@/components/toggle";
import { useCompanyStore } from "@/lib/company-store";
import {
  apiCreateCategory,
  apiDeleteProductImage,
  apiFetchCategories,
  apiPutProductImage
} from "@/lib/api";
import type { Category, ModifierOption, Product } from "@/lib/types";
import { cn, formatCurrency, pluralRu } from "@/lib/utils";

const PRODUCT_COLORS = [
  "#ff9ec6",
  "#8fe5c7",
  "#ffd39e",
  "#ffc857",
  "#efb8c8",
  "#b98560",
  "#7b4b35",
  "#d4a373"
];

const uid = () => Math.random().toString(36).slice(2, 9);

interface ProductDraft {
  name: string;
  description: string;
  imageUrl: string;
  category: string;
  categoryId: string | null;
  color: string;
  priceText: string;
  sizes: ModifierOption[];
  toppings: ModifierOption[];
  availableBranchIds: string[];
  active: boolean;
  isBestSeller: boolean;
  isNew: boolean;
}

function draftFromProduct(product: Product): ProductDraft {
  return {
    name: product.name,
    description: product.description,
    imageUrl: product.imageUrl ?? "",
    category: product.category,
    categoryId: product.categoryId ?? null,
    color: product.color,
    priceText: String(product.price),
    sizes: product.sizes.map((s) => ({ ...s })),
    toppings: product.toppings.map((t) => ({ ...t })),
    availableBranchIds: [...product.availableBranchIds],
    active: product.active,
    isBestSeller: product.isBestSeller ?? false,
    isNew: product.isNew ?? false
  };
}

function ProductImage({
  imageUrl,
  color,
  name,
  className
}: {
  imageUrl: string | null | undefined;
  color: string;
  name: string;
  className: string;
}) {
  const [failed, setFailed] = useState(false);

  if (!imageUrl || failed) {
    return (
      <span
        role="img"
        aria-label={imageUrl ? "Фото товара недоступно" : "Фото товара не задано"}
        className={cn(
          "flex shrink-0 items-center justify-center overflow-hidden text-coffee-700/45",
          className
        )}
        style={{ backgroundColor: color }}
      >
        <ImageIcon className="h-5 w-5" />
      </span>
    );
  }

  return (
    <span className={cn("block shrink-0 overflow-hidden", className)}>
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img
        src={imageUrl}
        alt={name ? `Фото: ${name}` : "Фото товара"}
        loading="lazy"
        decoding="async"
        onError={() => setFailed(true)}
        className="h-full w-full object-cover"
      />
    </span>
  );
}

function Field({ label, children }: { label: string; children: ReactNode }) {
  return (
    <label className="block">
      <span className="mb-1.5 block text-sm font-medium text-coffee-700">
        {label}
      </span>
      {children}
    </label>
  );
}

/** Редактор списка модификаторов (размеры или топпинги) */
function ModifierEditor({
  title,
  options,
  basePrice,
  useFinalPrice = false,
  onChange
}: {
  title: string;
  options: ModifierOption[];
  basePrice?: number;
  useFinalPrice?: boolean;
  onChange: (next: ModifierOption[]) => void;
}) {
  return (
    <div>
      <p className="mb-1.5 text-sm font-medium text-coffee-700">{title}</p>
      <div className="space-y-2">
        {options.map((option, index) => (
          <div key={option.id} className="flex items-center gap-2">
            <input
              value={option.label}
              onChange={(e) => {
                const next = [...options];
                next[index] = { ...option, label: e.target.value };
                onChange(next);
              }}
              placeholder="Название"
              className="input flex-1"
            />
            <div className="flex items-center gap-1">
              {!useFinalPrice && <span className="text-xs text-coffee-500">+</span>}
              <input
                type="number"
                min={0}
                value={String(
                  useFinalPrice
                    ? (basePrice ?? 0) + option.priceDelta
                    : option.priceDelta
                )}
                onChange={(e) => {
                  const next = [...options];
                  const entered = Math.max(
                    0,
                    Math.round(Number(e.target.value)) || 0
                  );
                  next[index] = {
                    ...option,
                    priceDelta: useFinalPrice
                      ? entered - (basePrice ?? 0)
                      : entered
                  };
                  onChange(next);
                }}
                className="input w-20"
              />
              <span className="text-xs text-coffee-500">сом</span>
            </div>
            <button
              type="button"
              onClick={() => onChange(options.filter((o) => o.id !== option.id))}
              title="Удалить"
              className="focus-ring flex h-8 w-8 shrink-0 items-center justify-center rounded-full text-coffee-500 transition hover:bg-red-50 hover:text-red-600 dark:hover:bg-red-500/10 dark:hover:text-red-400"
            >
              <Minus className="h-4 w-4" />
            </button>
          </div>
        ))}
        <button
          type="button"
          onClick={() =>
            onChange([...options, { id: `m-${uid()}`, label: "", priceDelta: 0 }])
          }
          className="focus-ring flex h-9 items-center gap-1.5 rounded-full border border-dashed border-coffee-900/20 px-4 text-sm text-coffee-700 transition hover:border-accent hover:text-accent"
        >
          <Plus className="h-4 w-4" />
          Добавить
        </button>
      </div>
    </div>
  );
}

function ProductPanel({
  product,
  categories,
  onCategoryCreated,
  onClose
}: {
  /** null — режим «новый товар» */
  product: Product | null;
  categories: Category[];
  onCategoryCreated: (category: Category) => void;
  onClose: () => void;
}) {
  const { company, branches, addProduct, updateProduct } =
    useCompanyStore();
  const [draft, setDraft] = useState<ProductDraft>(() =>
    product
      ? draftFromProduct(product)
      : {
          name: "",
          description: "",
          imageUrl: "",
          category: "",
          categoryId: null,
          color: PRODUCT_COLORS[0],
          priceText: "",
          sizes: [],
          toppings: [],
          availableBranchIds: branches.map((b) => b.id),
          active: true,
          isBestSeller: false,
          isNew: false
        }
  );
  const [newCategory, setNewCategory] = useState({ ru: "", ky: "", en: "" });
  const [showNewCategory, setShowNewCategory] = useState(false);
  const [categoryError, setCategoryError] = useState<string | null>(null);
  const [mediaBusy, setMediaBusy] = useState(false);
  const [mediaError, setMediaError] = useState<string | null>(null);

  const price = Math.max(0, Math.round(Number(draft.priceText)) || 0);
  const canSave =
    draft.name.trim().length > 0 && price > 0 && draft.categoryId !== null;

  function toggleBranch(branchId: string) {
    setDraft((prev) => ({
      ...prev,
      availableBranchIds: prev.availableBranchIds.includes(branchId)
        ? prev.availableBranchIds.filter((id) => id !== branchId)
        : [...prev.availableBranchIds, branchId]
    }));
  }

  async function createCategory() {
    if (!newCategory.ru.trim() || !newCategory.ky.trim() || !newCategory.en.trim()) return;
    setCategoryError(null);
    try {
      const created = await apiCreateCategory(
        company.id,
        {
          ru: newCategory.ru.trim(),
          ky: newCategory.ky.trim(),
          en: newCategory.en.trim()
        },
        categories.length
      );
      onCategoryCreated(created);
      setDraft((current) => ({
        ...current,
        categoryId: created.id,
        category: created.name.ru
      }));
      setNewCategory({ ru: "", ky: "", en: "" });
      setShowNewCategory(false);
    } catch {
      setCategoryError("Не удалось создать категорию.");
    }
  }

  async function uploadImage(file: File) {
    if (!product) return;
    setMediaBusy(true);
    setMediaError(null);
    try {
      const updated = await apiPutProductImage(company.id, product.id, file);
      setDraft((current) => ({ ...current, imageUrl: updated.imageUrl ?? "" }));
      updateProduct(product.id, { imageUrl: updated.imageUrl });
    } catch {
      setMediaError("Не удалось загрузить фото. Проверьте формат и размер файла.");
    } finally {
      setMediaBusy(false);
    }
  }

  async function removeImage() {
    if (!product) {
      setDraft((current) => ({ ...current, imageUrl: "" }));
      return;
    }
    setMediaBusy(true);
    setMediaError(null);
    try {
      await apiDeleteProductImage(company.id, product.id);
      setDraft((current) => ({ ...current, imageUrl: "" }));
      updateProduct(product.id, { imageUrl: null });
    } catch {
      setMediaError("Не удалось удалить фото.");
    } finally {
      setMediaBusy(false);
    }
  }

  function handleSave() {
    if (!canSave) return;
    const payload = {
      name: draft.name.trim(),
      description: draft.description.trim(),
      imageUrl: draft.imageUrl.trim() || null,
      category: draft.category.trim() || "Прочее",
      categoryId: draft.categoryId,
      color: draft.color,
      price,
      sizes: draft.sizes.filter((s) => s.label.trim()),
      toppings: draft.toppings.filter((t) => t.label.trim()),
      availableBranchIds: draft.availableBranchIds,
      active: draft.active,
      isBestSeller: draft.isBestSeller,
      isNew: draft.isNew
    };
    if (product) {
      updateProduct(product.id, payload);
    } else {
      addProduct({
        id: `${company.id}-p-${uid()}`,
        companyId: company.id,
        ...payload
      });
    }
    onClose();
  }

  return (
    <div className="fixed inset-0 z-50">
      <div
        className="absolute inset-0 bg-coffee-900/30 dark:bg-black/60"
        onClick={onClose}
        aria-hidden="true"
      />
      <aside className="absolute right-0 top-0 flex h-full w-full max-w-md flex-col bg-cream-50 shadow-soft dark:bg-[#1d181b]">
        <header className="flex items-center justify-between border-b border-coffee-900/10 px-6 py-4">
          <h2 className="text-lg">
            {product ? "Редактировать товар" : "Новый товар"}
          </h2>
          <button
            type="button"
            onClick={onClose}
            title="Закрыть"
            className="focus-ring flex h-9 w-9 items-center justify-center rounded-full text-coffee-500 transition hover:bg-coffee-900/5"
          >
            <X className="h-5 w-5" />
          </button>
        </header>

        <div className="flex-1 space-y-5 overflow-y-auto px-6 py-5">
          <Field label="Название">
            <input
              value={draft.name}
              onChange={(e) => setDraft({ ...draft, name: e.target.value })}
              placeholder="Например, Клубничный латте"
              className="input"
            />
          </Field>

          <Field label="Описание">
            <textarea
              value={draft.description}
              onChange={(e) =>
                setDraft({ ...draft, description: e.target.value })
              }
              placeholder="Кратко опишите напиток или блюдо"
              rows={3}
              className="input min-h-24 resize-y py-3"
            />
          </Field>

          <div>
            <p className="mb-1.5 text-sm font-medium text-coffee-700">Фото</p>
            <div className="flex items-start gap-3">
              <ProductImage
                key={draft.imageUrl}
                imageUrl={draft.imageUrl || null}
                color={draft.color}
                name={draft.name}
                className="h-24 w-24 rounded-2xl"
              />
              <div className="min-w-0 flex-1">
                <input
                  type="url"
                  value={draft.imageUrl}
                  onChange={(e) =>
                    setDraft({ ...draft, imageUrl: e.target.value })
                  }
                  placeholder="https://… или /media/…"
                  aria-label="URL фотографии товара"
                  className="input"
                />
                <p className="mt-1.5 text-xs leading-relaxed text-coffee-500">
                  Укажите HTTPS-адрес или путь /media/ уже загруженного изображения.
                </p>
                {product ? (
                  <label className="focus-ring mt-2 inline-flex h-9 cursor-pointer items-center rounded-full border border-coffee-900/15 px-3 text-xs font-semibold text-coffee-700">
                    {mediaBusy ? "Загрузка…" : "Выбрать файл"}
                    <input
                      type="file"
                      accept="image/jpeg,image/png,image/webp"
                      disabled={mediaBusy}
                      className="sr-only"
                      onChange={(event) => {
                        const file = event.target.files?.[0];
                        if (file) void uploadImage(file);
                        event.currentTarget.value = "";
                      }}
                    />
                  </label>
                ) : (
                  <p className="mt-2 text-xs text-coffee-500">
                    Сначала сохраните товар, затем откройте редактирование и загрузите фото.
                  </p>
                )}
                {mediaError && (
                  <p className="mt-2 text-xs text-red-600">{mediaError}</p>
                )}
                {draft.imageUrl && (
                  <button
                    type="button"
                    onClick={() => void removeImage()}
                    className="focus-ring mt-2 rounded text-xs font-semibold text-red-600 hover:text-red-700 dark:text-red-400"
                  >
                    Убрать фото
                  </button>
                )}
              </div>
            </div>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <Field label="Категория">
              <>
                <select
                  value={draft.categoryId ?? ""}
                  onChange={(event) => {
                    const selected = categories.find(
                      (item) => item.id === event.target.value
                    );
                    setDraft({
                      ...draft,
                      categoryId: selected?.id ?? null,
                      category: selected?.name.ru ?? ""
                    });
                  }}
                  className="input"
                >
                  <option value="">Выберите категорию</option>
                  {categories.filter((item) => item.active).map((item) => (
                    <option key={item.id} value={item.id}>
                      {item.name.ru}
                    </option>
                  ))}
                </select>
                <button
                  type="button"
                  onClick={() => setShowNewCategory((value) => !value)}
                  className="mt-2 text-xs font-semibold text-accent"
                >
                  + Новая категория
                </button>
              </>
            </Field>
            <Field label="Цена, сом">
              <input
                type="number"
                min={0}
                value={draft.priceText}
                onChange={(e) =>
                  setDraft({ ...draft, priceText: e.target.value })
                }
                placeholder="350"
                className="input"
              />
            </Field>
          </div>

          {showNewCategory && (
            <div className="space-y-2 rounded-xl border border-coffee-900/10 p-3">
              <p className="text-sm font-semibold">Новая категория</p>
              {(["ru", "ky", "en"] as const).map((language) => (
                <input
                  key={language}
                  value={newCategory[language]}
                  onChange={(event) =>
                    setNewCategory({
                      ...newCategory,
                      [language]: event.target.value
                    })
                  }
                  placeholder={`Название ${language.toUpperCase()}`}
                  className="input"
                />
              ))}
              <button
                type="button"
                onClick={() => void createCategory()}
                className="h-9 rounded-full bg-accent px-4 text-xs font-semibold text-white"
              >
                Создать категорию
              </button>
              {categoryError && (
                <p className="text-xs text-red-600">{categoryError}</p>
              )}
            </div>
          )}

          <div>
            <p className="mb-1.5 text-sm font-medium text-coffee-700">
              Цвет заглушки
            </p>
            <div className="flex flex-wrap gap-2">
              {PRODUCT_COLORS.map((color) => (
                <button
                  key={color}
                  type="button"
                  onClick={() => setDraft({ ...draft, color })}
                  title={color}
                  style={{ backgroundColor: color }}
                  className={cn(
                    "focus-ring h-9 w-9 rounded-full transition",
                    draft.color === color &&
                      "ring-2 ring-coffee-900 ring-offset-2 dark:ring-cream-50 dark:ring-offset-[#1d181b]"
                  )}
                />
              ))}
            </div>
          </div>

          <ModifierEditor
            title="Размеры (итоговая цена)"
            options={draft.sizes}
            basePrice={price}
            useFinalPrice
            onChange={(sizes) => setDraft({ ...draft, sizes })}
          />

          <ModifierEditor
            title="Топпинги (приплата)"
            options={draft.toppings}
            onChange={(toppings) => setDraft({ ...draft, toppings })}
          />

          <div>
            <p className="mb-1.5 text-sm font-medium text-coffee-700">
              Доступность по филиалам
            </p>
            <div className="space-y-2">
              {branches.map((branch) => (
                <label
                  key={branch.id}
                  className="flex cursor-pointer items-center gap-2.5 text-sm text-coffee-700"
                >
                  <input
                    type="checkbox"
                    checked={draft.availableBranchIds.includes(branch.id)}
                    onChange={() => toggleBranch(branch.id)}
                    className="focus-ring h-4 w-4 rounded border-coffee-900/20 accent-[rgb(var(--accent))]"
                  />
                  {branch.name}
                </label>
              ))}
            </div>
          </div>

          <div className="flex items-center justify-between rounded-xl border border-coffee-900/10 px-4 py-3">
            <span className="text-sm font-medium text-coffee-700">
              Товар активен
            </span>
            <Toggle
              checked={draft.active}
              onChange={(active) => setDraft({ ...draft, active })}
              label="Товар активен"
            />
          </div>

          {/* Витрина: попадание товара в блоки главного экрана приложения */}
          <div className="rounded-xl border border-coffee-900/10 px-4 py-3">
            <p className="mb-1 text-sm font-medium text-coffee-700">
              Витрина приложения
            </p>
            <p className="mb-3 text-xs text-coffee-500">
              Определяет блоки на главном экране приложения
            </p>
            <div className="flex items-center justify-between py-1.5">
              <span className="text-sm text-coffee-700">Хит продаж</span>
              <Toggle
                checked={draft.isBestSeller}
                onChange={(isBestSeller) =>
                  setDraft({ ...draft, isBestSeller })
                }
                label="Хит продаж"
              />
            </div>
            <div className="flex items-center justify-between py-1.5">
              <span className="text-sm text-coffee-700">Новое в меню</span>
              <Toggle
                checked={draft.isNew}
                onChange={(isNew) => setDraft({ ...draft, isNew })}
                label="Новое в меню"
              />
            </div>
          </div>
        </div>

        <footer className="flex gap-2 border-t border-coffee-900/10 px-6 py-4">
          <button
            type="button"
            onClick={handleSave}
            disabled={!canSave}
            className="focus-ring flex h-11 flex-1 items-center justify-center rounded-full bg-accent text-sm font-semibold text-white transition hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-40"
          >
            {product ? "Сохранить" : "Добавить товар"}
          </button>
          <button
            type="button"
            onClick={onClose}
            className="focus-ring flex h-11 items-center justify-center rounded-full border border-coffee-900/15 px-5 text-sm font-medium text-coffee-700 transition hover:bg-coffee-900/5"
          >
            Отмена
          </button>
        </footer>
      </aside>
    </div>
  );
}

function MenuContent() {
  const { company, products, branches, updateProduct } = useCompanyStore();
  const [selectedCategory, setSelectedCategory] = useState("all");
  const [panel, setPanel] = useState<
    { mode: "edit"; productId: string } | { mode: "create" } | null
  >(null);
  const [categoryRecords, setCategoryRecords] = useState<Category[]>([]);

  useEffect(() => {
    void apiFetchCategories(company.id).then(setCategoryRecords);
  }, [company.id]);

  const shortBranchName = (name: string) =>
    name.replace(company.name, "").trim() || name;

  const panelProduct =
    panel?.mode === "edit"
      ? (products.find((p) => p.id === panel.productId) ?? null)
      : null;
  const categories = Array.from(
    new Set(products.map((product) => product.category))
  ).sort((a, b) => a.localeCompare(b, "ru"));
  const visibleProducts =
    selectedCategory === "all"
      ? products
      : products.filter((product) => product.category === selectedCategory);

  return (
    <div>
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl">Меню</h1>
          <p className="mt-1 text-sm text-coffee-500">
            {products.length}{" "}
            {pluralRu(products.length, "товар", "товара", "товаров")} ·{" "}
            {products.filter((p) => p.active).length} активных
          </p>
        </div>
        <button
          type="button"
          onClick={() => setPanel({ mode: "create" })}
          className="focus-ring flex h-11 items-center gap-2 rounded-full bg-accent px-5 text-sm font-semibold text-white transition hover:opacity-90"
        >
          <Plus className="h-4 w-4" />
          Добавить товар
        </button>
      </div>

      <div
        className="mt-5 flex gap-2 overflow-x-auto pb-1"
        aria-label="Фильтр меню по категориям"
      >
        {["all", ...categories].map((category) => {
          const active = selectedCategory === category;
          return (
            <button
              key={category}
              type="button"
              onClick={() => setSelectedCategory(category)}
              aria-pressed={active}
              className={cn(
                "focus-ring h-10 shrink-0 rounded-full border px-4 text-sm font-semibold transition",
                active
                  ? "border-accent bg-accent text-white"
                  : "border-coffee-900/10 bg-white text-coffee-700 hover:border-accent hover:text-accent dark:bg-white/5"
              )}
            >
              {category === "all" ? "Все" : category}
            </button>
          );
        })}
      </div>

      <div className="surface mt-6 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-coffee-900/10 text-left text-xs uppercase tracking-wide text-coffee-500">
                <th className="px-5 py-3 font-semibold">Товар</th>
                <th className="px-5 py-3 font-semibold">Категория</th>
                <th className="px-5 py-3 font-semibold">Цена</th>
                <th className="px-5 py-3 font-semibold">Модификаторы</th>
                <th className="px-5 py-3 font-semibold">Филиалы</th>
                <th className="px-5 py-3 text-right font-semibold">Активен</th>
                <th className="px-5 py-3 text-right font-semibold">Действия</th>
              </tr>
            </thead>
            <tbody>
              {visibleProducts.map((product) => {
                const everywhere =
                  branches.length > 0 &&
                  branches.every((b) =>
                    product.availableBranchIds.includes(b.id)
                  );
                return (
                  <tr
                    key={product.id}
                    className={cn(
                      "border-b border-coffee-900/5 transition last:border-0 hover:bg-accent/5",
                      !product.active && "opacity-50"
                    )}
                  >
                    <td className="px-5 py-3">
                      <span className="flex items-center gap-3">
                        <ProductImage
                          key={`${product.id}-${product.imageUrl ?? "fallback"}`}
                          imageUrl={product.imageUrl}
                          color={product.color}
                          name={product.name}
                          className="h-11 w-11 rounded-xl"
                        />
                        <span className="min-w-0">
                          <span className="block font-semibold text-coffee-900">
                            {product.name}
                          </span>
                          {(product.isBestSeller || product.isNew) && (
                            <span className="mt-0.5 flex flex-wrap gap-1">
                              {product.isBestSeller && (
                                <span className="rounded-full bg-candy-500/15 px-2 py-0.5 text-[10px] font-bold text-candy-700 dark:text-candy-300">
                                  Хит
                                </span>
                              )}
                              {product.isNew && (
                                <span className="rounded-full bg-mint-500/15 px-2 py-0.5 text-[10px] font-bold text-emerald-700 dark:text-mint-300">
                                  Новинка
                                </span>
                              )}
                            </span>
                          )}
                        </span>
                      </span>
                    </td>
                    <td className="px-5 py-3 text-coffee-700">
                      {product.category}
                    </td>
                    <td className="px-5 py-3 font-semibold text-coffee-900">
                      {formatCurrency(
                        product.sizes.length > 0
                          ? Math.min(
                              ...product.sizes.map(
                                (size) => product.price + size.priceDelta
                              )
                            )
                          : product.price,
                        company.currency
                      )}
                    </td>
                    <td className="px-5 py-3">
                      <span className="flex flex-wrap gap-1.5">
                        {product.sizes.length > 0 && (
                          <span className="rounded-full bg-cream-100 px-2.5 py-0.5 text-xs font-medium text-coffee-700 dark:bg-white/10">
                            {product.sizes.length}{" "}
                            {pluralRu(
                              product.sizes.length,
                              "размер",
                              "размера",
                              "размеров"
                            )}
                          </span>
                        )}
                        {product.toppings.length > 0 && (
                          <span className="rounded-full bg-cream-100 px-2.5 py-0.5 text-xs font-medium text-coffee-700 dark:bg-white/10">
                            {product.toppings.length}{" "}
                            {pluralRu(
                              product.toppings.length,
                              "топпинг",
                              "топпинга",
                              "топпингов"
                            )}
                          </span>
                        )}
                        {product.sizes.length === 0 &&
                          product.toppings.length === 0 && (
                            <span className="text-xs text-coffee-500">—</span>
                          )}
                      </span>
                    </td>
                    <td className="px-5 py-3">
                      <span className="flex flex-wrap gap-1.5">
                        {everywhere ? (
                          <span className="rounded-full bg-mint-100 px-2.5 py-0.5 text-xs font-medium text-emerald-700 dark:bg-mint-500/15 dark:text-mint-300">
                            Все филиалы
                          </span>
                        ) : product.availableBranchIds.length === 0 ? (
                          <span className="rounded-full bg-red-50 px-2.5 py-0.5 text-xs font-medium text-red-600 dark:bg-red-500/15 dark:text-red-400">
                            Нигде
                          </span>
                        ) : (
                          branches
                            .filter((b) =>
                              product.availableBranchIds.includes(b.id)
                            )
                            .map((b) => (
                              <span
                                key={b.id}
                                className="rounded-full bg-accent/10 px-2.5 py-0.5 text-xs font-medium text-accent"
                              >
                                {shortBranchName(b.name)}
                              </span>
                            ))
                        )}
                      </span>
                    </td>
                    <td className="px-5 py-3 text-right">
                      <Toggle
                        checked={product.active}
                        onChange={(active) =>
                          updateProduct(product.id, { active })
                        }
                        label={
                          product.active
                            ? "Выключить товар"
                            : "Включить товар"
                        }
                      />
                    </td>
                    <td className="px-5 py-3 text-right">
                      <button
                        type="button"
                        onClick={() =>
                          setPanel({ mode: "edit", productId: product.id })
                        }
                        className="focus-ring inline-flex h-9 items-center gap-1.5 rounded-full border border-coffee-900/15 px-3 text-xs font-semibold text-coffee-700 transition hover:border-accent hover:text-accent"
                      >
                        <Pencil className="h-3.5 w-3.5" />
                        Редактировать
                      </button>
                    </td>
                  </tr>
                );
              })}
              {visibleProducts.length === 0 && (
                <tr>
                  <td colSpan={7} className="px-5 py-10 text-center text-coffee-500">
                    В этой категории пока нет товаров
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>

      {panel && (
        <ProductPanel
          key={panel.mode === "edit" ? panel.productId : "create"}
          product={panelProduct}
          categories={categoryRecords}
          onCategoryCreated={(category) =>
            setCategoryRecords((current) => [...current, category])
          }
          onClose={() => setPanel(null)}
        />
      )}
    </div>
  );
}

export default function MenuPage() {
  return (
    <RoleGate allow={["owner", "manager"]}>
      <MenuContent />
    </RoleGate>
  );
}
