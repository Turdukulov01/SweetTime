"use client";

// Меню компании: таблица товаров + боковая панель создания/редактирования.
// Мутации company-store подтверждаются боевым product API и откатываются при ошибке.

import { useEffect, useState, type ReactNode } from "react";
import { ImageIcon, Minus, Pencil, Plus, X } from "lucide-react";
import { RoleGate } from "@/components/role-gate";
import { LocalizedField } from "@/components/localized-field";
import { Toggle } from "@/components/toggle";
import { useCompanyStore } from "@/lib/company-store";
import {
  apiCreateCategory,
  apiCreateTopping,
  apiDeleteProductImage,
  apiFetchCategories,
  apiFetchToppings,
  apiPutProductImage
} from "@/lib/api";
import type {
  Category,
  LocalizedText,
  ModifierOption,
  Product,
  ToppingCatalogItem
} from "@/lib/types";
import { normalizeProductPricing } from "@/lib/product-pricing";
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
  name: LocalizedText;
  description: LocalizedText;
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
    name: product.nameLocalized ?? { ru: product.name },
    description: product.descriptionLocalized ?? { ru: product.description },
    imageUrl: product.imageUrl ?? "",
    category: product.category,
    categoryId: product.categoryId ?? null,
    color: product.color,
    priceText: String(product.price),
    sizes: product.sizes.map((s) => ({
      ...s,
      priceDelta: product.price + s.priceDelta
    })),
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
  showPlus = true,
  onChange
}: {
  title: string;
  options: ModifierOption[];
  showPlus?: boolean;
  onChange: (next: ModifierOption[]) => void;
}) {
  return (
    <div>
      <p className="mb-1.5 text-sm font-medium text-coffee-700">{title}</p>
      <div className="space-y-2">
        {options.map((option, index) => (
          <div key={option.id} className="flex items-start gap-2">
            <div className="min-w-0 flex-1">
              <LocalizedField
                label="Название варианта"
                required
                value={option.localizedName ?? { ru: option.label }}
                onChange={(name) => {
                const next = [...options];
                next[index] = {
                  ...option,
                    label: name.ru,
                    localizedName: name
                };
                onChange(next);
              }}
                placeholder="Название"
              />
            </div>
            <div className="flex items-center gap-1">
              {showPlus && <span className="text-xs text-coffee-500">+</span>}
              <input
                type="number"
                min={0}
                value={String(option.priceDelta)}
                onChange={(e) => {
                  const next = [...options];
                  const entered = Math.max(
                    0,
                    Math.round(Number(e.target.value)) || 0
                  );
                  next[index] = {
                    ...option,
                    priceDelta: entered
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
  toppingCatalog,
  onCategoryCreated,
  onToppingCreated,
  onClose
}: {
  /** null — режим «новый товар» */
  product: Product | null;
  categories: Category[];
  toppingCatalog: ToppingCatalogItem[];
  onCategoryCreated: (category: Category) => void;
  onToppingCreated: (topping: ToppingCatalogItem) => void;
  onClose: () => void;
}) {
  const { company, branches, addProduct, updateProduct } =
    useCompanyStore();
  const [draft, setDraft] = useState<ProductDraft>(() =>
    product
      ? draftFromProduct(product)
      : {
          name: { ru: "" },
          description: { ru: "" },
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
  const [newTopping, setNewTopping] = useState({
    ru: "",
    ky: "",
    en: "",
    price: ""
  });
  const [showNewCategory, setShowNewCategory] = useState(false);
  const [showNewTopping, setShowNewTopping] = useState(false);
  const [categoryError, setCategoryError] = useState<string | null>(null);
  const [toppingError, setToppingError] = useState<string | null>(null);
  const [mediaBusy, setMediaBusy] = useState(false);
  const [mediaError, setMediaError] = useState<string | null>(null);
  const [selectedImage, setSelectedImage] = useState<{
    file: File;
    previewUrl: string;
  } | null>(null);
  const [imageRemoved, setImageRemoved] = useState(false);
  const [persistedProduct, setPersistedProduct] = useState<Product | null>(product);

  useEffect(
    () => () => {
      if (selectedImage) URL.revokeObjectURL(selectedImage.previewUrl);
    },
    [selectedImage]
  );

  const normalizedPricing = normalizeProductPricing(
    draft.priceText,
    draft.sizes
  );
  const price = normalizedPricing.basePrice;
  const hasPrice = normalizedPricing.hasPrice;
  const canSave =
    draft.name.ru.trim().length > 0 && hasPrice && draft.categoryId !== null;

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

  function chooseImage(file: File) {
    setSelectedImage({ file, previewUrl: URL.createObjectURL(file) });
    setImageRemoved(false);
    setMediaError(null);
  }

  function removeImage() {
    setSelectedImage(null);
    setImageRemoved(true);
    setMediaError(null);
  }

  function templateSelected(item: ToppingCatalogItem) {
    const normalized = item.name.ru.trim().toLocaleLowerCase("ru");
    return draft.toppings.some(
      (topping) =>
        topping.id === item.id ||
        (topping.label.trim().toLocaleLowerCase("ru") === normalized &&
          topping.priceDelta === item.price)
    );
  }

  function toggleTemplate(item: ToppingCatalogItem) {
    if (templateSelected(item)) {
      const normalized = item.name.ru.trim().toLocaleLowerCase("ru");
      setDraft((current) => ({
        ...current,
        toppings: current.toppings.filter(
          (topping) =>
            !(
              topping.id === item.id ||
              (topping.label.trim().toLocaleLowerCase("ru") === normalized &&
                topping.priceDelta === item.price)
            )
        )
      }));
      return;
    }
    setDraft((current) => ({
      ...current,
      toppings: [
        ...current.toppings,
        {
          id: item.id,
          label: item.name.ru,
          localizedName: item.name,
          priceDelta: item.price
        }
      ]
    }));
  }

  async function createTopping() {
    const priceValue = Math.max(0, Math.round(Number(newTopping.price)) || 0);
    if (
      !newTopping.ru.trim() ||
      !newTopping.ky.trim() ||
      !newTopping.en.trim()
    ) {
      setToppingError("Заполните название на RU, KG и EN.");
      return;
    }
    setToppingError(null);
    try {
      const created = await apiCreateTopping(
        company.id,
        {
          ru: newTopping.ru.trim(),
          ky: newTopping.ky.trim(),
          en: newTopping.en.trim()
        },
        priceValue,
        toppingCatalog.length
      );
      onToppingCreated(created);
      setDraft((current) => ({
        ...current,
        toppings: [
          ...current.toppings,
          {
            id: created.id,
            label: created.name.ru,
            localizedName: created.name,
            priceDelta: created.price
          }
        ]
      }));
      setNewTopping({ ru: "", ky: "", en: "", price: "" });
      setShowNewTopping(false);
    } catch {
      setToppingError("Не удалось создать топпинг.");
    }
  }

  async function handleSave() {
    if (!canSave) return;
    setMediaBusy(true);
    setMediaError(null);
    const normalizedSizes = normalizedPricing.sizes.filter((size) =>
      size.label.trim()
    );
    const payload = {
      name: draft.name.ru.trim(),
      nameLocalized: draft.name,
      description: draft.description.ru.trim(),
      descriptionLocalized: draft.description,
      imageUrl: persistedProduct?.imageUrl ?? null,
      category: draft.category.trim() || "Прочее",
      categoryId: draft.categoryId,
      color: draft.color,
      price,
      sizes: normalizedSizes,
      toppings: draft.toppings.filter((t) => t.label.trim()),
      availableBranchIds: draft.availableBranchIds,
      active: draft.active,
      isBestSeller: draft.isBestSeller,
      isNew: draft.isNew
    };
    try {
      let saved = persistedProduct
        ? await updateProduct(persistedProduct.id, payload)
        : await addProduct({
            id: `${company.id}-p-${uid()}`,
            companyId: company.id,
            ...payload
          });
      setPersistedProduct(saved);

      if (selectedImage) {
        const withImage = await apiPutProductImage(
          company.id,
          saved.id,
          selectedImage.file
        );
        saved = await updateProduct(saved.id, { imageUrl: withImage.imageUrl });
        setPersistedProduct(saved);
      } else if (imageRemoved && saved.imageUrl) {
        await apiDeleteProductImage(company.id, saved.id);
        saved = await updateProduct(saved.id, { imageUrl: null });
        setPersistedProduct(saved);
      }
      onClose();
    } catch {
      setMediaError(
        persistedProduct
          ? "Не удалось сохранить товар или фотографию. Повторите попытку."
          : "Товар мог сохраниться, но фотография не загрузилась. Повторите сохранение."
      );
    } finally {
      setMediaBusy(false);
    }
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
          <LocalizedField
            label="Название"
            required
            value={draft.name}
            onChange={(name) => setDraft({ ...draft, name })}
            placeholder="Например, Клубничный латте"
          />

          <LocalizedField
            label="Описание"
            multiline
            value={draft.description}
            onChange={(description) => setDraft({ ...draft, description })}
            placeholder="Кратко опишите напиток или блюдо"
          />

          <div>
            <p className="mb-1.5 text-sm font-medium text-coffee-700">Фото</p>
            <div className="flex items-start gap-3">
              <ProductImage
                key={selectedImage?.previewUrl ?? `${draft.imageUrl}-${imageRemoved}`}
                imageUrl={
                  selectedImage?.previewUrl ??
                  (imageRemoved ? null : draft.imageUrl || null)
                }
                color={draft.color}
                name={draft.name.ru}
                className="h-24 w-24 rounded-2xl"
              />
              <div className="min-w-0 flex-1">
                <label className="focus-ring inline-flex h-9 cursor-pointer items-center rounded-full border border-coffee-900/15 px-3 text-xs font-semibold text-coffee-700">
                  {selectedImage ? "Выбрать другое фото" : "Открыть проводник"}
                  <input
                    type="file"
                    accept="image/jpeg,image/png,image/webp"
                    disabled={mediaBusy}
                    className="sr-only"
                    onChange={(event) => {
                      const file = event.target.files?.[0];
                      if (file) chooseImage(file);
                      event.currentTarget.value = "";
                    }}
                  />
                </label>
                <p className="mt-1.5 text-xs leading-relaxed text-coffee-500">
                  JPEG, PNG или WebP. Файл загрузится только после сохранения товара.
                </p>
                {mediaError && (
                  <p className="mt-2 text-xs text-red-600">{mediaError}</p>
                )}
                {(selectedImage || (!imageRemoved && draft.imageUrl)) && (
                  <button
                    type="button"
                    onClick={removeImage}
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
            <Field label="Базовая цена, сом (необязательно)">
              <>
                <input
                  type="number"
                  min={0}
                  value={draft.priceText}
                  onChange={(e) =>
                    setDraft({ ...draft, priceText: e.target.value })
                  }
                  placeholder="Рассчитается из размеров"
                  className="input"
                />
                <span className="mt-1 block text-xs text-coffee-500">
                  Если оставить пустой, возьмём минимальную цену размера.
                </span>
              </>
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
            showPlus={false}
            onChange={(sizes) => setDraft({ ...draft, sizes })}
          />

          <div className="rounded-2xl border border-coffee-900/10 p-4">
            <div className="flex items-start justify-between gap-3">
              <div>
                <p className="text-sm font-medium text-coffee-700">
                  Готовые топпинги
                </p>
                <p className="mt-1 text-xs text-coffee-500">
                  Создайте один раз и отмечайте нужные для каждого товара.
                </p>
              </div>
              <button
                type="button"
                onClick={() => setShowNewTopping((value) => !value)}
                className="shrink-0 text-xs font-semibold text-accent"
              >
                + Новый
              </button>
            </div>

            {toppingCatalog.filter((item) => item.active).length > 0 ? (
              <div className="mt-3 grid gap-2 sm:grid-cols-2">
                {toppingCatalog
                  .filter((item) => item.active)
                  .map((item) => (
                    <label
                      key={item.id}
                      className="flex cursor-pointer items-center gap-2 rounded-xl border border-coffee-900/10 px-3 py-2 text-sm"
                    >
                      <input
                        type="checkbox"
                        checked={templateSelected(item)}
                        onChange={() => toggleTemplate(item)}
                        className="h-4 w-4 accent-[rgb(var(--accent))]"
                      />
                      <span className="min-w-0 flex-1 truncate">
                        {item.name.ru}
                      </span>
                      <span className="text-xs text-coffee-500">
                        +{item.price} сом
                      </span>
                    </label>
                  ))}
              </div>
            ) : (
              <p className="mt-3 text-xs text-coffee-500">
                Справочник пока пуст.
              </p>
            )}

            {showNewTopping && (
              <div className="mt-3 space-y-2 rounded-xl bg-coffee-900/[0.03] p-3">
                {(["ru", "ky", "en"] as const).map((language) => (
                  <input
                    key={language}
                    value={newTopping[language]}
                    onChange={(event) =>
                      setNewTopping({
                        ...newTopping,
                        [language]: event.target.value
                      })
                    }
                    placeholder={`Название ${language.toUpperCase()}`}
                    className="input"
                  />
                ))}
                <input
                  type="number"
                  min={0}
                  value={newTopping.price}
                  onChange={(event) =>
                    setNewTopping({ ...newTopping, price: event.target.value })
                  }
                  placeholder="Доплата, сом"
                  className="input"
                />
                <button
                  type="button"
                  onClick={() => void createTopping()}
                  className="h-9 rounded-full bg-accent px-4 text-xs font-semibold text-white"
                >
                  Создать и выбрать
                </button>
                {toppingError && (
                  <p className="text-xs text-red-600">{toppingError}</p>
                )}
              </div>
            )}
          </div>

          <ModifierEditor
            title="Ручные топпинги (доплата)"
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
  const [toppingRecords, setToppingRecords] = useState<ToppingCatalogItem[]>([]);

  useEffect(() => {
    void apiFetchCategories(company.id).then(setCategoryRecords);
    void apiFetchToppings(company.id).then(setToppingRecords);
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
          toppingCatalog={toppingRecords}
          onCategoryCreated={(category) =>
            setCategoryRecords((current) => [...current, category])
          }
          onToppingCreated={(topping) =>
            setToppingRecords((current) => [...current, topping])
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
