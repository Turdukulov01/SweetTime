"use client";

// Новости-сторис витрины приложения: список карточек-превью + боковая панель
// CRUD. Все изменения идут через company-store (оптимистично + API PATCH/POST/
// DELETE). Роли: владелец и менеджер.

import { useState, type ReactNode } from "react";
import {
  ChevronDown,
  ChevronUp,
  Gift,
  Newspaper,
  Pencil,
  Plus,
  QrCode,
  Sparkles,
  Store,
  Trash2,
  X,
  type LucideIcon
} from "lucide-react";
import { AccentPicker } from "@/components/accent-picker";
import { LocalizedField } from "@/components/localized-field";
import { RoleGate } from "@/components/role-gate";
import { Toggle } from "@/components/toggle";
import { useCompanyStore } from "@/lib/company-store";
import type { LocalizedText, NewsStory, NewsVisual } from "@/lib/types";
import { cn } from "@/lib/utils";

const NEWS_VISUALS: { key: NewsVisual; label: string; icon: LucideIcon }[] = [
  { key: "sparkle", label: "Акция", icon: Sparkles },
  { key: "storefront", label: "Филиал", icon: Store },
  { key: "qr", label: "QR-заказ", icon: QrCode },
  { key: "loyalty", label: "Лояльность", icon: Gift }
];

const visualIcon = (visual: NewsVisual): LucideIcon =>
  NEWS_VISUALS.find((v) => v.key === visual)?.icon ?? Sparkles;

const uid = () => Math.random().toString(36).slice(2, 9);
const emptyLocalized = (): LocalizedText => ({ ru: "" });

interface NewsDraft {
  title: LocalizedText;
  body: LocalizedText;
  badge: LocalizedText;
  accentColor: string;
  visual: NewsVisual;
  isPublished: boolean;
  sortOrder: number;
  ctaLabel: string;
  ctaRoute: string;
}

function draftFromNews(n: NewsStory): NewsDraft {
  return {
    title: { ...n.title },
    body: { ...n.body },
    badge: { ...n.badge },
    accentColor: n.accentColor,
    visual: n.visual,
    isPublished: n.isPublished,
    sortOrder: n.sortOrder,
    ctaLabel: n.ctaLabel?.ru ?? "",
    ctaRoute: n.ctaRoute ?? ""
  };
}

// ---------------------------------------------------------------------------
// Боковая панель создания/редактирования
// ---------------------------------------------------------------------------

function NewsPanel({
  story,
  nextSortOrder,
  onClose
}: {
  /** null — режим «новая новость» */
  story: NewsStory | null;
  nextSortOrder: number;
  onClose: () => void;
}) {
  const { company, addNews, updateNews } = useCompanyStore();
  const [draft, setDraft] = useState<NewsDraft>(() =>
    story
      ? draftFromNews(story)
      : {
          title: emptyLocalized(),
          body: emptyLocalized(),
          badge: emptyLocalized(),
          accentColor: company.accentColor,
          visual: "sparkle",
          isPublished: true,
          sortOrder: nextSortOrder,
          ctaLabel: "",
          ctaRoute: ""
        }
  );

  const canSave = draft.title.ru.trim().length > 0;

  function handleSave() {
    if (!canSave) return;
    const ctaLabel = draft.ctaLabel.trim();
    const ctaRoute = draft.ctaRoute.trim();
    const payload = {
      title: draft.title,
      body: draft.body,
      badge: draft.badge,
      accentColor: draft.accentColor,
      visual: draft.visual,
      isPublished: draft.isPublished,
      sortOrder: draft.sortOrder,
      expiresAt: story?.expiresAt ?? null,
      imageUrl: story?.imageUrl ?? null,
      ctaLabel: ctaLabel ? { ru: ctaLabel } : null,
      ctaRoute: ctaRoute || null
    };
    if (story) {
      updateNews(story.id, payload);
    } else {
      addNews({
        id: `${company.id}-news-${uid()}`,
        companyId: company.id,
        publishedAt: new Date().toISOString(),
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
          <h2 className="text-lg">{story ? "Новость" : "Новая новость"}</h2>
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
            label="Заголовок"
            required
            value={draft.title}
            onChange={(title) => setDraft({ ...draft, title })}
            placeholder="Новый вкус недели"
          />
          <LocalizedField
            label="Текст"
            multiline
            value={draft.body}
            onChange={(body) => setDraft({ ...draft, body })}
            placeholder="Коротко расскажите о новости"
          />
          <LocalizedField
            label="Бейдж"
            value={draft.badge}
            onChange={(badge) => setDraft({ ...draft, badge })}
            placeholder="Новинка"
          />

          <div>
            <p className="mb-1.5 text-sm font-medium text-coffee-700">Визуал</p>
            <div className="grid grid-cols-4 gap-2">
              {NEWS_VISUALS.map(({ key, label, icon: Icon }) => {
                const active = draft.visual === key;
                return (
                  <button
                    key={key}
                    type="button"
                    onClick={() => setDraft({ ...draft, visual: key })}
                    aria-pressed={active}
                    className={cn(
                      "focus-ring flex flex-col items-center gap-1 rounded-xl border px-2 py-2.5 text-[11px] font-medium transition",
                      active
                        ? "border-accent bg-accent/10 text-accent"
                        : "border-coffee-900/15 text-coffee-500 hover:border-accent hover:text-accent"
                    )}
                  >
                    <Icon className="h-5 w-5" />
                    {label}
                  </button>
                );
              })}
            </div>
          </div>

          <div>
            <p className="mb-1.5 text-sm font-medium text-coffee-700">
              Акцентный цвет
            </p>
            <AccentPicker
              value={draft.accentColor}
              onChange={(accentColor) => setDraft({ ...draft, accentColor })}
            />
          </div>

          <div className="grid grid-cols-2 gap-3">
            <label className="block">
              <span className="mb-1.5 block text-sm font-medium text-coffee-700">
                Кнопка (текст)
              </span>
              <input
                value={draft.ctaLabel}
                onChange={(e) =>
                  setDraft({ ...draft, ctaLabel: e.target.value })
                }
                placeholder="Заказать"
                className="input"
              />
            </label>
            <label className="block">
              <span className="mb-1.5 block text-sm font-medium text-coffee-700">
                Кнопка (роут)
              </span>
              <input
                value={draft.ctaRoute}
                onChange={(e) =>
                  setDraft({ ...draft, ctaRoute: e.target.value })
                }
                placeholder="/catalog"
                className="input font-mono"
              />
            </label>
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
            <span className="text-sm font-medium text-coffee-700">
              Опубликовано
            </span>
            <Toggle
              checked={draft.isPublished}
              onChange={(isPublished) => setDraft({ ...draft, isPublished })}
              label={draft.isPublished ? "Снять с публикации" : "Опубликовать"}
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
            {story ? "Сохранить" : "Добавить новость"}
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
// Карточка-превью сторис в списке
// ---------------------------------------------------------------------------

function NewsCard({
  story,
  isFirst,
  isLast,
  onEdit,
  onMove,
  onDelete
}: {
  story: NewsStory;
  isFirst: boolean;
  isLast: boolean;
  onEdit: () => void;
  onMove: (dir: -1 | 1) => void;
  onDelete: () => void;
}) {
  const [confirming, setConfirming] = useState(false);
  const Icon = visualIcon(story.visual);

  return (
    <article className="surface flex flex-col px-5 py-4">
      <div className="flex items-start justify-between gap-3">
        <div className="flex min-w-0 items-center gap-3">
          <span
            className="flex h-11 w-11 shrink-0 items-center justify-center rounded-2xl text-white"
            style={{ backgroundColor: story.accentColor }}
          >
            <Icon className="h-5 w-5" />
          </span>
          <div className="min-w-0">
            {story.badge.ru.trim() && (
              <span
                className="inline-block rounded-full px-2.5 py-0.5 text-[11px] font-semibold"
                style={{
                  backgroundColor: `${story.accentColor}22`,
                  color: story.accentColor
                }}
              >
                {story.badge.ru}
              </span>
            )}
            <h2 className="mt-1 truncate text-base font-semibold text-coffee-900">
              {story.title.ru}
            </h2>
          </div>
        </div>

        {/* Порядок и стрелки */}
        <div className="flex shrink-0 items-center gap-1.5">
          <span className="text-xs font-semibold text-coffee-500">
            #{story.sortOrder}
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

      {story.body.ru.trim() && (
        <p className="mt-3 line-clamp-2 text-sm text-coffee-700">
          {story.body.ru}
        </p>
      )}

      <div className="mt-4 flex items-center justify-between gap-2">
        <span
          className={cn(
            "rounded-full px-2.5 py-0.5 text-xs font-semibold",
            story.isPublished
              ? "bg-mint-100 text-emerald-700 dark:bg-mint-500/15 dark:text-mint-300"
              : "bg-cream-100 text-coffee-500 dark:bg-white/10"
          )}
        >
          {story.isPublished ? "Опубликовано" : "Черновик"}
        </span>

        {confirming ? (
          <span className="flex items-center gap-2">
            <span className="text-xs font-medium text-coffee-500">
              Удалить?
            </span>
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

function NewsContent() {
  const { news, updateNews, removeNews } = useCompanyStore();
  const [panel, setPanel] = useState<
    { mode: "edit"; id: string } | { mode: "create" } | null
  >(null);

  const sorted = [...news].sort((a, b) => a.sortOrder - b.sortOrder);
  const nextSortOrder =
    (sorted.length ? Math.max(...sorted.map((n) => n.sortOrder)) : 0) + 10;
  const publishedCount = news.filter((n) => n.isPublished).length;

  const panelStory =
    panel?.mode === "edit"
      ? (news.find((n) => n.id === panel.id) ?? null)
      : null;

  function move(index: number, dir: -1 | 1) {
    const current = sorted[index];
    const target = sorted[index + dir];
    if (!current || !target) return;
    updateNews(current.id, { sortOrder: target.sortOrder });
    updateNews(target.id, { sortOrder: current.sortOrder });
  }

  return (
    <div>
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl">Новости</h1>
          <p className="mt-1 text-sm text-coffee-500">
            Сторис на главном экране приложения · {news.length} всего ·{" "}
            {publishedCount} опубликовано
          </p>
        </div>
        <button
          type="button"
          onClick={() => setPanel({ mode: "create" })}
          className="focus-ring flex h-11 items-center gap-2 rounded-full bg-accent px-5 text-sm font-semibold text-white transition hover:opacity-90"
        >
          <Plus className="h-4 w-4" />
          Добавить новость
        </button>
      </div>

      {sorted.length === 0 ? (
        <div className="surface mt-6 flex flex-col items-center gap-3 px-6 py-16 text-center">
          <Newspaper className="h-8 w-8 text-coffee-500/60" />
          <p className="text-sm text-coffee-500">
            Пока нет ни одной новости. Добавьте первую сторис для витрины
            приложения.
          </p>
        </div>
      ) : (
        <div className="mt-6 grid grid-cols-1 gap-4 lg:grid-cols-2 xl:grid-cols-3">
          {sorted.map((story, index) => (
            <NewsCard
              key={story.id}
              story={story}
              isFirst={index === 0}
              isLast={index === sorted.length - 1}
              onEdit={() => setPanel({ mode: "edit", id: story.id })}
              onMove={(dir) => move(index, dir)}
              onDelete={() => removeNews(story.id)}
            />
          ))}
        </div>
      )}

      {panel && (
        <NewsPanel
          key={panel.mode === "edit" ? panel.id : "create"}
          story={panelStory}
          nextSortOrder={nextSortOrder}
          onClose={() => setPanel(null)}
        />
      )}
    </div>
  );
}

export default function NewsPage(): ReactNode {
  return (
    <RoleGate allow={["owner", "manager"]}>
      <NewsContent />
    </RoleGate>
  );
}
