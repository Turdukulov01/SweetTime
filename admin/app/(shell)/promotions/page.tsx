"use client";

// Сезонные акции витрины приложения: список карточек + боковая панель CRUD.
// Все изменения идут через company-store (оптимистично + API). Роли: владелец и менеджер.

import { useState, type ReactNode } from "react";
import {
  ChevronDown,
  ChevronUp,
  Pencil,
  Plus,
  Tag,
  Trash2,
  X
} from "lucide-react";
import { AccentPicker } from "@/components/accent-picker";
import { LocalizedField } from "@/components/localized-field";
import { RoleGate } from "@/components/role-gate";
import { Toggle } from "@/components/toggle";
import { useCompanyStore } from "@/lib/company-store";
import {
  apiDeletePromotionImage,
  apiPutPromotionImage
} from "@/lib/api";
import type { LocalizedText, Promotion } from "@/lib/types";
import { cn } from "@/lib/utils";

const uid = () => Math.random().toString(36).slice(2, 9);
const emptyLocalized = (): LocalizedText => ({ ru: "" });

interface PromoDraft {
  title: LocalizedText;
  description: LocalizedText;
  code: string;
  accentColor: string;
  active: boolean;
  sortOrder: number;
}

function draftFromPromo(p: Promotion): PromoDraft {
  return {
    title: { ...p.title },
    description: { ...p.description },
    code: p.code ?? "",
    accentColor: p.accentColor,
    active: p.active,
    sortOrder: p.sortOrder
  };
}

// ---------------------------------------------------------------------------
// Боковая панель создания/редактирования
// ---------------------------------------------------------------------------

function PromoPanel({
  promo,
  nextSortOrder,
  onClose
}: {
  /** null — режим «новая акция» */
  promo: Promotion | null;
  nextSortOrder: number;
  onClose: () => void;
}) {
  const { company, addPromotion, updatePromotion } = useCompanyStore();
  const [draft, setDraft] = useState<PromoDraft>(() =>
    promo
      ? draftFromPromo(promo)
      : {
          title: emptyLocalized(),
          description: emptyLocalized(),
          code: "",
          accentColor: company.accentColor,
          active: true,
          sortOrder: nextSortOrder
        }
  );
  const [selectedImage, setSelectedImage] = useState<File | null>(null);
  const [removeImage, setRemoveImage] = useState(false);
  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);

  const canSave =
    draft.title.ru.trim().length > 0 ||
    selectedImage !== null ||
    (!!promo?.imageUrl && !removeImage);

  async function handleSave() {
    if (!canSave) return;
    setSaving(true);
    setSaveError(null);
    const code = draft.code.trim();
    const payload = {
      title: draft.title,
      description: draft.description,
      code: code ? code.toUpperCase() : null,
      accentColor: draft.accentColor,
      active: draft.active,
      sortOrder: draft.sortOrder
    };
    try {
      let saved: Promotion;
      if (promo) {
        saved = await updatePromotion(promo.id, payload);
      } else {
        saved = await addPromotion({
          id: `${company.id}-promo-${uid()}`,
          companyId: company.id,
          imageUrl: null,
          thumbnailUrl: null,
          ...payload
        });
      }
      if (selectedImage) {
        await apiPutPromotionImage(company.id, saved.id, selectedImage);
        await updatePromotion(saved.id, {});
      } else if (removeImage && saved.imageUrl) {
        await apiDeletePromotionImage(company.id, saved.id);
        await updatePromotion(saved.id, {});
      }
      onClose();
    } catch {
      setSaveError("Не удалось сохранить акцию или её изображение.");
    } finally {
      setSaving(false);
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
          <h2 className="text-lg">{promo ? "Акция" : "Новая акция"}</h2>
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
          <div>
            <p className="mb-1.5 text-sm font-medium text-coffee-700">Изображение</p>
            {!removeImage && promo?.imageUrl && !selectedImage && (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={promo.imageUrl} alt="" className="mb-2 h-32 w-full rounded-xl object-cover" />
            )}
            <label className="focus-ring inline-flex h-9 cursor-pointer items-center rounded-full border border-coffee-900/15 px-3 text-xs font-semibold text-coffee-700">
              {selectedImage ? selectedImage.name : "Выбрать фото"}
              <input
                type="file"
                accept="image/jpeg,image/png,image/webp"
                className="sr-only"
                disabled={saving}
                onChange={(event) => {
                  setSelectedImage(event.target.files?.[0] ?? null);
                  setRemoveImage(false);
                  event.currentTarget.value = "";
                }}
              />
            </label>
            {(selectedImage || (!removeImage && promo?.imageUrl)) && (
              <button
                type="button"
                className="ml-2 text-xs font-semibold text-red-600"
                onClick={() => {
                  setSelectedImage(null);
                  setRemoveImage(true);
                }}
              >Убрать</button>
            )}
            <p className="mt-1.5 text-xs text-coffee-500">
              Можно опубликовать только фото. Если добавить текст, он будет показан поверх изображения.
            </p>
          </div>
          <LocalizedField
            label="Заголовок"
            value={draft.title}
            onChange={(title) => setDraft({ ...draft, title })}
            placeholder="Утренний дуэт"
          />
          {saveError && <p className="text-sm text-red-600">{saveError}</p>}
          <LocalizedField
            label="Описание"
            multiline
            value={draft.description}
            onChange={(description) => setDraft({ ...draft, description })}
            placeholder="Любой кофе и моти-кап за 520 сом"
          />

          <label className="block">
            <span className="mb-1.5 block text-sm font-medium text-coffee-700">
              Промокод
            </span>
            <input
              value={draft.code}
              onChange={(e) => setDraft({ ...draft, code: e.target.value })}
              placeholder="DUO"
              className="input font-mono uppercase"
            />
          </label>

          <div>
            <p className="mb-1.5 text-sm font-medium text-coffee-700">
              Акцентный цвет
            </p>
            <AccentPicker
              value={draft.accentColor}
              onChange={(accentColor) => setDraft({ ...draft, accentColor })}
            />
          </div>

          <label className="block">
            <span className="mb-1.5 block text-sm font-medium text-coffee-700">
              Порядок показа
            </span>
            <input
              type="number"
              value={draft.sortOrder}
              onChange={(e) =>
                setDraft({
                  ...draft,
                  sortOrder: Math.round(Number(e.target.value)) || 0
                })
              }
              className="input w-28"
            />
          </label>

          <div className="flex items-center justify-between rounded-xl border border-coffee-900/10 px-4 py-3">
            <span className="text-sm font-medium text-coffee-700">Активна</span>
            <Toggle
              checked={draft.active}
              onChange={(active) => setDraft({ ...draft, active })}
              label={draft.active ? "Выключить акцию" : "Включить акцию"}
            />
          </div>
        </div>

        <footer className="flex gap-2 border-t border-coffee-900/10 px-6 py-4">
          <button
            type="button"
            onClick={handleSave}
            disabled={!canSave}
            className="focus-ring flex h-11 flex-1 items-center justify-center rounded-full bg-accent text-sm font-semibold text-white transition hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-40"
          >
            {promo ? "Сохранить" : "Добавить акцию"}
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

// ---------------------------------------------------------------------------
// Карточка акции в списке
// ---------------------------------------------------------------------------

function PromoCard({
  promo,
  isFirst,
  isLast,
  onEdit,
  onMove,
  onDelete
}: {
  promo: Promotion;
  isFirst: boolean;
  isLast: boolean;
  onEdit: () => void;
  onMove: (dir: -1 | 1) => void;
  onDelete: () => void;
}) {
  const [confirming, setConfirming] = useState(false);

  return (
    <article className="surface flex flex-col px-5 py-4">
      <div
        className="mb-3 h-1.5 w-14 rounded-full"
        style={{ backgroundColor: promo.accentColor }}
      />
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0">
          <h2 className="truncate text-base font-semibold text-coffee-900">
            {promo.title.ru}
          </h2>
          {promo.code && (
            <span
              className="mt-1 inline-block rounded-full px-2.5 py-0.5 font-mono text-[11px] font-bold"
              style={{
                backgroundColor: `${promo.accentColor}22`,
                color: promo.accentColor
              }}
            >
              {promo.code}
            </span>
          )}
        </div>

        <div className="flex shrink-0 items-center gap-1.5">
          <span className="text-xs font-semibold text-coffee-500">
            #{promo.sortOrder}
          </span>
          <div className="flex flex-col">
            <button
              type="button"
              onClick={() => onMove(-1)}
              disabled={isFirst}
              title="Поднять"
              className="focus-ring flex h-5 w-6 items-center justify-center rounded-md text-coffee-500 transition hover:bg-coffee-900/5 disabled:opacity-30"
            >
              <ChevronUp className="h-4 w-4" />
            </button>
            <button
              type="button"
              onClick={() => onMove(1)}
              disabled={isLast}
              title="Опустить"
              className="focus-ring flex h-5 w-6 items-center justify-center rounded-md text-coffee-500 transition hover:bg-coffee-900/5 disabled:opacity-30"
            >
              <ChevronDown className="h-4 w-4" />
            </button>
          </div>
        </div>
      </div>

      {promo.description.ru.trim() && (
        <p className="mt-2 line-clamp-2 text-sm text-coffee-700">
          {promo.description.ru}
        </p>
      )}

      <div className="mt-4 flex items-center justify-between gap-2">
        <span
          className={cn(
            "rounded-full px-2.5 py-0.5 text-xs font-semibold",
            promo.active
              ? "bg-mint-100 text-emerald-700 dark:bg-mint-500/15 dark:text-mint-300"
              : "bg-cream-100 text-coffee-500 dark:bg-white/10"
          )}
        >
          {promo.active ? "Активна" : "Выключена"}
        </span>

        {confirming ? (
          <span className="flex items-center gap-2">
            <span className="text-xs font-medium text-coffee-500">Удалить?</span>
            <button
              type="button"
              onClick={onDelete}
              className="focus-ring rounded-full bg-red-600 px-3 py-1 text-xs font-semibold text-white transition hover:opacity-90"
            >
              Да
            </button>
            <button
              type="button"
              onClick={() => setConfirming(false)}
              className="focus-ring rounded-full border border-coffee-900/15 px-3 py-1 text-xs font-medium text-coffee-700 transition hover:bg-coffee-900/5"
            >
              Нет
            </button>
          </span>
        ) : (
          <span className="flex items-center gap-1.5">
            <button
              type="button"
              onClick={onEdit}
              className="focus-ring flex h-9 items-center gap-1.5 rounded-full border border-coffee-900/15 px-3.5 text-sm font-medium text-coffee-700 transition hover:border-accent hover:text-accent"
            >
              <Pencil className="h-4 w-4" />
              Изменить
            </button>
            <button
              type="button"
              onClick={() => setConfirming(true)}
              title="Удалить"
              className="focus-ring flex h-9 w-9 items-center justify-center rounded-full text-coffee-500 transition hover:bg-red-50 hover:text-red-600 dark:hover:bg-red-500/10 dark:hover:text-red-400"
            >
              <Trash2 className="h-4 w-4" />
            </button>
          </span>
        )}
      </div>
    </article>
  );
}

// ---------------------------------------------------------------------------
// Страница
// ---------------------------------------------------------------------------

function PromotionsContent() {
  const { promotions, updatePromotion, removePromotion } = useCompanyStore();
  const [panel, setPanel] = useState<
    { mode: "edit"; id: string } | { mode: "create" } | null
  >(null);

  const sorted = [...promotions].sort((a, b) => a.sortOrder - b.sortOrder);
  const nextSortOrder =
    (sorted.length ? Math.max(...sorted.map((p) => p.sortOrder)) : 0) + 10;
  const activeCount = promotions.filter((p) => p.active).length;

  const panelPromo =
    panel?.mode === "edit"
      ? (promotions.find((p) => p.id === panel.id) ?? null)
      : null;

  function move(index: number, dir: -1 | 1) {
    const current = sorted[index];
    const target = sorted[index + dir];
    if (!current || !target) return;
    void updatePromotion(current.id, { sortOrder: target.sortOrder }).catch(
      () => undefined
    );
    void updatePromotion(target.id, { sortOrder: current.sortOrder }).catch(
      () => undefined
    );
  }

  return (
    <div>
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl">Сезонные акции</h1>
          <p className="mt-1 text-sm text-coffee-500">
            Блок «Сезонные акции» на главном экране · {promotions.length} всего ·{" "}
            {activeCount} активно
          </p>
        </div>
        <button
          type="button"
          onClick={() => setPanel({ mode: "create" })}
          className="focus-ring flex h-11 items-center gap-2 rounded-full bg-accent px-5 text-sm font-semibold text-white transition hover:opacity-90"
        >
          <Plus className="h-4 w-4" />
          Добавить акцию
        </button>
      </div>

      {sorted.length === 0 ? (
        <div className="surface mt-6 flex flex-col items-center gap-3 px-6 py-16 text-center">
          <Tag className="h-8 w-8 text-coffee-500/60" />
          <p className="text-sm text-coffee-500">
            Пока нет ни одной акции. Пустой блок скрывается в приложении
            автоматически.
          </p>
        </div>
      ) : (
        <div className="mt-6 grid grid-cols-1 gap-4 lg:grid-cols-2 xl:grid-cols-3">
          {sorted.map((promo, index) => (
            <PromoCard
              key={promo.id}
              promo={promo}
              isFirst={index === 0}
              isLast={index === sorted.length - 1}
              onEdit={() => setPanel({ mode: "edit", id: promo.id })}
              onMove={(dir) => move(index, dir)}
              onDelete={() => removePromotion(promo.id)}
            />
          ))}
        </div>
      )}

      {panel && (
        <PromoPanel
          key={panel.mode === "edit" ? panel.id : "create"}
          promo={panelPromo}
          nextSortOrder={nextSortOrder}
          onClose={() => setPanel(null)}
        />
      )}
    </div>
  );
}

export default function PromotionsPage(): ReactNode {
  return (
    <RoleGate allow={["owner", "manager"]}>
      <PromotionsContent />
    </RoleGate>
  );
}
