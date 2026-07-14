"use client";

// Меню компании: таблица товаров + боковая панель деталей/редактирования.
// Все изменения — клиентские, через мутации company-store.

import { useState, type ReactNode } from "react";
import { Minus, Plus, X } from "lucide-react";
import { RoleGate } from "@/components/role-gate";
import { Toggle } from "@/components/toggle";
import { useCompanyStore } from "@/lib/company-store";
import type { ModifierOption, Product } from "@/lib/types";
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
  category: string;
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
    category: product.category,
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
  onChange
}: {
  title: string;
  options: ModifierOption[];
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
              <span className="text-xs text-coffee-500">+</span>
              <input
                type="number"
                min={0}
                value={String(option.priceDelta)}
                onChange={(e) => {
                  const next = [...options];
                  next[index] = {
                    ...option,
                    priceDelta: Math.max(0, Math.round(Number(e.target.value)) || 0)
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
  onClose
}: {
  /** null — режим «новый товар» */
  product: Product | null;
  onClose: () => void;
}) {
  const { company, branches, products, addProduct, updateProduct } =
    useCompanyStore();
  const [draft, setDraft] = useState<ProductDraft>(() =>
    product
      ? draftFromProduct(product)
      : {
          name: "",
          category: "",
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

  const price = Math.max(0, Math.round(Number(draft.priceText)) || 0);
  const canSave = draft.name.trim().length > 0 && price > 0;
  const categories = Array.from(new Set(products.map((p) => p.category)));

  function toggleBranch(branchId: string) {
    setDraft((prev) => ({
      ...prev,
      availableBranchIds: prev.availableBranchIds.includes(branchId)
        ? prev.availableBranchIds.filter((id) => id !== branchId)
        : [...prev.availableBranchIds, branchId]
    }));
  }

  function handleSave() {
    if (!canSave) return;
    const payload = {
      name: draft.name.trim(),
      category: draft.category.trim() || "Прочее",
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
            {product ? "Товар" : "Новый товар"}
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

          <div className="grid grid-cols-2 gap-3">
            <Field label="Категория">
              <>
                <input
                  value={draft.category}
                  onChange={(e) =>
                    setDraft({ ...draft, category: e.target.value })
                  }
                  list="menu-categories"
                  placeholder="Кофе"
                  className="input"
                />
                <datalist id="menu-categories">
                  {categories.map((c) => (
                    <option key={c} value={c} />
                  ))}
                </datalist>
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
            title="Размеры (приплата к базовой цене)"
            options={draft.sizes}
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
                    onClick={() =>
                      setPanel({ mode: "edit", productId: product.id })
                    }
                    className={cn(
                      "cursor-pointer border-b border-coffee-900/5 transition last:border-0 hover:bg-accent/5",
                      !product.active && "opacity-50"
                    )}
                  >
                    <td className="px-5 py-3">
                      <span className="flex items-center gap-3">
                        <span
                          className="h-9 w-9 shrink-0 rounded-xl"
                          style={{ backgroundColor: product.color }}
                          aria-hidden="true"
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
                      {formatCurrency(product.price, company.currency)}
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
                  </tr>
                );
              })}
              {visibleProducts.length === 0 && (
                <tr>
                  <td colSpan={6} className="px-5 py-10 text-center text-coffee-500">
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
