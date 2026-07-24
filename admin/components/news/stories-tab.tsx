"use client";

import { useMemo, useState } from "react";
import { Home, Pencil, Pin, Plus, RefreshCw, Sparkles } from "lucide-react";
import { AccentPicker } from "@/components/accent-picker";
import { LocalizedField } from "@/components/localized-field";
import { Toggle } from "@/components/toggle";
import {
  ContentDrawer,
  DeleteButton,
  MediaPicker,
  PublicationBadge,
  PublicationTimingPicker,
  type PublicationMode
} from "@/components/news/content-shared";
import { describeApiError, type ContentStoryWrite } from "@/lib/api";
import { useCompanyStore } from "@/lib/company-store";
import { useContentManager } from "@/lib/content-store";
import {
  emptyLocalized,
  formatDateTime,
  fromDateTimeLocal,
  hasAnyLocalizedText,
  localizedPublishError,
  toDateTimeLocal
} from "@/lib/content-validation";
import type { ContentMedia, ContentStory, LocalizedText, NewsVisual } from "@/lib/types";

const EMPTY_MEDIA: ContentMedia = { type: "none", url: null, thumbnailUrl: null };
const CTA_ROUTES = ["", "/catalog", "/news", "/qr", "/cart", "/profile", "/loyalty"];

type ExpiryPreset = "never" | "24h" | "3d" | "7d" | "custom";

interface StoryDraft {
  collectionId: string;
  title: LocalizedText;
  body: LocalizedText;
  badge: LocalizedText;
  accentColor: string;
  visual: NewsVisual;
  isPublished: boolean;
  showOnHome: boolean;
  isPinned: boolean;
  sortOrder: number;
  publicationMode: PublicationMode;
  publishedAt: string;
  expiresAt: string;
  expiryPreset: ExpiryPreset;
  ctaEnabled: boolean;
  ctaLabel: LocalizedText;
  ctaRoute: string;
}

function expiryPresetFor(expiresAt: string | null): ExpiryPreset {
  return expiresAt ? "custom" : "never";
}

function draftFromStory(story: ContentStory): StoryDraft {
  return {
    collectionId: story.collectionId ?? "",
    title: { ...story.title },
    body: { ...story.body },
    badge: { ...story.badge },
    accentColor: story.accentColor,
    visual: story.visual,
    isPublished: story.isPublished,
    showOnHome: story.showOnHome,
    isPinned: story.isPinned,
    sortOrder: story.sortOrder,
    publicationMode:
      Date.parse(story.publishedAt) > Date.now() ? "scheduled" : "now",
    publishedAt: toDateTimeLocal(story.publishedAt),
    expiresAt: story.expiresAt ? toDateTimeLocal(story.expiresAt) : "",
    expiryPreset: expiryPresetFor(story.expiresAt),
    ctaEnabled: Boolean(story.ctaLabel || story.ctaRoute),
    ctaLabel: story.ctaLabel ? { ...story.ctaLabel } : emptyLocalized(),
    ctaRoute: story.ctaRoute ?? ""
  };
}

function newDraft(accentColor: string, sortOrder: number): StoryDraft {
  return {
    collectionId: "",
    title: emptyLocalized(),
    body: emptyLocalized(),
    badge: emptyLocalized(),
    accentColor,
    visual: "sparkle",
    isPublished: false,
    showOnHome: true,
    isPinned: false,
    sortOrder,
    publicationMode: "now",
    publishedAt: toDateTimeLocal(new Date().toISOString()),
    expiresAt: "",
    expiryPreset: "never",
    ctaEnabled: false,
    ctaLabel: emptyLocalized(),
    ctaRoute: ""
  };
}

function applyExpiryPreset(draft: StoryDraft, preset: ExpiryPreset): StoryDraft {
  if (preset === "never") return { ...draft, expiryPreset: preset, expiresAt: "" };
  if (preset === "custom") return { ...draft, expiryPreset: preset };
  const base =
    draft.publicationMode === "scheduled"
      ? fromDateTimeLocal(draft.publishedAt)
      : new Date().toISOString();
  const date = base ? new Date(base) : new Date();
  const days = preset === "24h" ? 1 : preset === "3d" ? 3 : 7;
  date.setUTCDate(date.getUTCDate() + days);
  return {
    ...draft,
    expiryPreset: preset,
    expiresAt: toDateTimeLocal(date.toISOString())
  };
}

function StoryEditor({
  story,
  nextSortOrder,
  activeHomeCount,
  onClose
}: {
  story: ContentStory | null;
  nextSortOrder: number;
  activeHomeCount: number;
  onClose: () => void;
}) {
  const { company } = useCompanyStore();
  const {
    collections,
    saveStory,
    uploadStoryMedia,
    removeStoryMedia
  } = useContentManager();
  const [draft, setDraft] = useState<StoryDraft>(() =>
    story ? draftFromStory(story) : newDraft(company.accentColor, nextSortOrder)
  );
  const [persisted, setPersisted] = useState<ContentStory | null>(story);
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [mediaRemoved, setMediaRemoved] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const currentMedia = persisted?.media ?? EMPTY_MEDIA;
  const hasResultingMedia = Boolean(selectedFile || (!mediaRemoved && currentMedia.url));

  function resolvedPublishedAt(): string | null {
    if (draft.publicationMode === "scheduled") {
      return fromDateTimeLocal(draft.publishedAt);
    }
    const original = story?.publishedAt;
    if (
      story?.isPublished &&
      original &&
      Date.parse(original) <= Date.now()
    ) {
      return original;
    }
    return new Date().toISOString();
  }

  function validate(): string | null {
    const publishedAt = resolvedPublishedAt();
    const expiresAt = draft.expiresAt ? fromDateTimeLocal(draft.expiresAt) : null;
    if (!publishedAt) return "Укажите корректную дату публикации.";
    if (
      draft.publicationMode === "scheduled" &&
      Date.parse(publishedAt) <= Date.now()
    ) {
      return "Для публикации по расписанию выберите будущее время.";
    }
    if (draft.expiresAt && !expiresAt) return "Укажите корректную дату окончания.";
    if (expiresAt && Date.parse(expiresAt) <= Date.parse(publishedAt)) {
      return "Окончание показа должно быть позже даты публикации.";
    }
    const hasText =
      hasAnyLocalizedText(draft.title) ||
      hasAnyLocalizedText(draft.body) ||
      hasAnyLocalizedText(draft.badge);
    if (!hasText && !hasResultingMedia) return "Добавьте текст, изображение или MP4.";
    if (draft.isPublished) {
      for (const [label, value] of [
        ["заголовок", draft.title],
        ["текст", draft.body],
        ["бейдж", draft.badge]
      ] as Array<[string, LocalizedText]>) {
        if (hasAnyLocalizedText(value)) {
          const localizedError = localizedPublishError(value);
          if (localizedError) return `${label}: ${localizedError}`;
        }
      }
      if (draft.ctaEnabled) {
        const ctaError = localizedPublishError(draft.ctaLabel);
        if (ctaError) return `кнопка: ${ctaError}`;
      }
      const now = Date.now();
      const candidateActiveOnHome =
        draft.showOnHome &&
        Date.parse(publishedAt) <= now &&
        (!expiresAt || Date.parse(expiresAt) > now);
      const originalActiveOnHome = Boolean(
        story?.isPublished &&
          story.showOnHome &&
          Date.parse(story.publishedAt) <= now &&
          (!story.expiresAt || Date.parse(story.expiresAt) > now)
      );
      const otherActiveHomeStories =
        activeHomeCount - (originalActiveOnHome ? 1 : 0);
      if (candidateActiveOnHome && otherActiveHomeStories >= 30) {
        return "На главной уже 30 активных сторис. Снимите другую с главной или дождитесь её окончания.";
      }
    }
    if (draft.ctaEnabled && !CTA_ROUTES.includes(draft.ctaRoute)) {
      return "Выберите разрешённый раздел для кнопки.";
    }
    return null;
  }

  async function handleSave() {
    const validationError = validate();
    if (validationError) {
      setError(validationError);
      return;
    }
    const publishedAt = resolvedPublishedAt() as string;
    const desired: ContentStoryWrite = {
      collectionId: draft.collectionId || null,
      title: draft.title,
      body: draft.body,
      badge: draft.badge,
      accentColor: draft.accentColor,
      visual: draft.visual,
      isPublished: draft.isPublished,
      showOnHome: draft.showOnHome,
      isPinned: draft.isPinned,
      sortOrder: draft.sortOrder,
      publishedAt,
      expiresAt: draft.expiresAt ? fromDateTimeLocal(draft.expiresAt) : null,
      ctaLabel: draft.ctaEnabled ? draft.ctaLabel : null,
      ctaRoute: draft.ctaEnabled ? draft.ctaRoute : null
    };

    setBusy(true);
    setError(null);
    try {
      const needsPublishAfterUpload = !persisted && Boolean(selectedFile) && desired.isPublished;
      let saved = await saveStory(
        persisted?.id ?? null,
        needsPublishAfterUpload ? { ...desired, isPublished: false } : desired
      );
      setPersisted(saved);
      if (selectedFile) {
        saved = await uploadStoryMedia(saved.id, selectedFile);
        setPersisted(saved);
        setSelectedFile(null);
        setMediaRemoved(false);
      } else if (mediaRemoved && saved.media.url) {
        saved = await removeStoryMedia(saved.id);
        setPersisted(saved);
        setMediaRemoved(false);
      }
      if (needsPublishAfterUpload) {
        saved = await saveStory(saved.id, desired);
        setPersisted(saved);
      }
      onClose();
    } catch (caught) {
      setError(describeApiError(caught));
      setBusy(false);
    }
  }

  return (
    <ContentDrawer
      title={story ? "Редактировать сторис" : "Новая сторис"}
      busy={busy}
      error={error}
      onClose={onClose}
      onSave={() => void handleSave()}
      saveLabel={story ? "Сохранить" : "Создать сторис"}
    >
      <MediaPicker
        current={currentMedia}
        selectedFile={selectedFile}
        removed={mediaRemoved}
        allowVideo
        onFileChange={(file) => {
          setSelectedFile(file);
          setMediaRemoved(false);
        }}
        onRemove={() => {
          if (selectedFile) setSelectedFile(null);
          setMediaRemoved(Boolean(currentMedia.url));
        }}
      />

      <LocalizedField label="Заголовок" value={draft.title} onChange={(title) => setDraft({ ...draft, title })} alwaysExpanded maxLength={80} />
      <LocalizedField label="Текст" value={draft.body} onChange={(body) => setDraft({ ...draft, body })} alwaysExpanded multiline maxLength={1000} />
      <LocalizedField label="Бейдж" value={draft.badge} onChange={(badge) => setDraft({ ...draft, badge })} alwaysExpanded maxLength={24} />

      <label className="block">
        <span className="mb-1.5 block text-sm font-medium text-coffee-700">Подборка</span>
        <select value={draft.collectionId} onChange={(event) => setDraft({ ...draft, collectionId: event.target.value })} className="input">
          <option value="">Без подборки</option>
          {collections.items.map((collection) => (
            <option key={collection.id} value={collection.id}>{collection.name.ru || `Подборка ${collection.id}`}</option>
          ))}
        </select>
        {collections.status === "error" && <p className="mt-1 text-xs text-red-600">Подборки недоступны: {collections.error}</p>}
      </label>

      <div>
        <p className="mb-1.5 text-sm font-medium text-coffee-700">Акцентный цвет</p>
        <AccentPicker value={draft.accentColor} onChange={(accentColor) => setDraft({ ...draft, accentColor })} />
      </div>

      <PublicationTimingPicker
        mode={draft.publicationMode}
        value={draft.publishedAt}
        onModeChange={(publicationMode) =>
          setDraft((current) => {
            const next = {
              ...current,
              publicationMode,
              isPublished:
                publicationMode === "scheduled"
                  ? true
                  : current.isPublished
            };
            return ["24h", "3d", "7d"].includes(next.expiryPreset)
              ? applyExpiryPreset(next, next.expiryPreset)
              : next;
          })
        }
        onValueChange={(publishedAt) =>
          setDraft((current) => {
            const next = { ...current, publishedAt };
            return ["24h", "3d", "7d"].includes(next.expiryPreset)
              ? applyExpiryPreset(next, next.expiryPreset)
              : next;
          })
        }
      />

      <label className="block">
        <span className="mb-1.5 block text-sm font-medium text-coffee-700">Порядок</span>
        <input type="number" value={draft.sortOrder} onChange={(event) => setDraft({ ...draft, sortOrder: Number(event.target.value) || 0 })} className="input" />
      </label>

      <fieldset>
        <legend className="mb-2 text-sm font-medium text-coffee-700">Срок показа</legend>
        <div className="flex flex-wrap gap-2">
          {(["never", "24h", "3d", "7d", "custom"] as ExpiryPreset[]).map((preset) => {
            const labels: Record<ExpiryPreset, string> = { never: "Никогда", "24h": "24 часа", "3d": "3 дня", "7d": "7 дней", custom: "Своя дата" };
            return (
              <button key={preset} type="button" aria-pressed={draft.expiryPreset === preset} onClick={() => setDraft(applyExpiryPreset(draft, preset))} className={draft.expiryPreset === preset ? "focus-ring rounded-full bg-accent px-3 py-2 text-xs font-semibold text-white" : "focus-ring rounded-full border border-coffee-900/15 px-3 py-2 text-xs font-semibold text-coffee-700"}>{labels[preset]}</button>
            );
          })}
        </div>
        {draft.expiryPreset !== "never" && (
          <input type="datetime-local" value={draft.expiresAt} onChange={(event) => setDraft({ ...draft, expiresAt: event.target.value, expiryPreset: "custom" })} className="input mt-3" aria-label="Дата окончания показа" />
        )}
      </fieldset>

      <div className="space-y-2 rounded-2xl border border-coffee-900/10 p-4">
        {[
          { label: "Опубликовать", key: "isPublished" as const },
          { label: "Показывать на главной", key: "showOnHome" as const },
          { label: "Закрепить первой", key: "isPinned" as const }
        ].map(({ label, key }) => (
          <div key={key} className="flex items-center justify-between gap-3">
            <span className="text-sm font-medium text-coffee-700">{label}</span>
            <Toggle checked={draft[key]} onChange={(value) => setDraft({ ...draft, [key]: value })} label={label} />
          </div>
        ))}
      </div>

      <div className="rounded-2xl border border-coffee-900/10 p-4">
        <div className="flex items-center justify-between gap-3">
          <div>
            <p className="text-sm font-medium text-coffee-700">Кнопка перехода</p>
            <p className="text-xs text-coffee-500">Только безопасные разделы приложения</p>
          </div>
          <Toggle checked={draft.ctaEnabled} onChange={(ctaEnabled) => setDraft({ ...draft, ctaEnabled })} label="Добавить кнопку перехода" />
        </div>
        {draft.ctaEnabled && (
          <div className="mt-4 space-y-4">
            <LocalizedField label="Текст кнопки" value={draft.ctaLabel} onChange={(ctaLabel) => setDraft({ ...draft, ctaLabel })} alwaysExpanded requiredAll maxLength={40} />
            <label className="block">
              <span className="mb-1.5 block text-sm font-medium text-coffee-700">Раздел</span>
              <select value={draft.ctaRoute} onChange={(event) => setDraft({ ...draft, ctaRoute: event.target.value })} className="input">
                <option value="">Выберите раздел</option>
                {CTA_ROUTES.filter(Boolean).map((route) => <option key={route} value={route}>{route}</option>)}
              </select>
            </label>
          </div>
        )}
      </div>
    </ContentDrawer>
  );
}

export function StoriesTab() {
  const { stories, collections, reloadStories, deleteStory } = useContentManager();
  const [editor, setEditor] = useState<{ id: string | null } | null>(null);
  const [collectionFilter, setCollectionFilter] = useState("all");
  const now = Date.now();
  const activeHomeCount = stories.items.filter((story) =>
    story.isPublished && story.showOnHome && Date.parse(story.publishedAt) <= now && (!story.expiresAt || Date.parse(story.expiresAt) > now)
  ).length;
  const nextSortOrder = Math.max(0, ...stories.items.map((story) => story.sortOrder)) + 10;
  const editingStory = editor?.id ? stories.items.find((story) => story.id === editor.id) ?? null : null;
  const collectionNames = useMemo(() => new Map(collections.items.map((item) => [item.id, item.name.ru])), [collections.items]);
  const visibleStories = useMemo(
    () =>
      collectionFilter === "all"
        ? stories.items
        : stories.items.filter((story) =>
            collectionFilter === "none"
              ? story.collectionId === null
              : story.collectionId === collectionFilter
          ),
    [stories.items, collectionFilter]
  );

  if (stories.status === "loading" && stories.items.length === 0) {
    return <div className="surface mt-5 px-6 py-14 text-center text-sm text-coffee-500">Загружаем сторис…</div>;
  }
  if (stories.status === "error" && stories.items.length === 0) {
    return <div className="surface mt-5 px-6 py-10 text-center"><p role="alert" className="text-sm text-red-600">{stories.error}</p><button type="button" onClick={() => void reloadStories()} className="focus-ring mt-4 inline-flex h-10 items-center gap-2 rounded-full bg-accent px-4 text-sm font-semibold text-white"><RefreshCw className="h-4 w-4" />Повторить</button></div>;
  }

  return (
    <div className="mt-5">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <p className="text-sm font-semibold text-coffee-900">Home stories: {activeHomeCount}/30</p>
          <p className="mt-1 text-xs text-coffee-500">На главной показываются максимум 30 активных сторис. Закреплённые идут первыми.</p>
        </div>
        <div className="flex flex-wrap items-end gap-2">
          <label className="block"><span className="mb-1 block text-xs font-medium text-coffee-500">Фильтр подборки</span><select value={collectionFilter} onChange={(event) => setCollectionFilter(event.target.value)} className="input h-10 min-w-48 py-2"><option value="all">Все сторис</option><option value="none">Без подборки</option>{collections.items.map((collection) => <option key={collection.id} value={collection.id}>{collection.name.ru || collection.id}</option>)}</select></label>
          <button type="button" onClick={() => setEditor({ id: null })} className="focus-ring flex h-10 items-center gap-2 rounded-full bg-accent px-4 text-sm font-semibold text-white"><Plus className="h-4 w-4" />Новая сторис</button>
        </div>
      </div>

      {stories.items.length === 0 ? (
        <div className="surface mt-5 flex flex-col items-center gap-2 px-6 py-14 text-center"><Sparkles className="h-8 w-8 text-coffee-500/50" /><p className="text-sm text-coffee-500">Сторис ещё нет. Создайте первую как черновик.</p></div>
      ) : (
        <div className="mt-5 grid gap-4 lg:grid-cols-2 xl:grid-cols-3">
          {visibleStories.map((story) => (
            <article key={story.id} className="surface overflow-hidden">
              <div className="flex h-36 items-center justify-center bg-coffee-900/5" style={{ backgroundColor: story.media.url ? undefined : `${story.accentColor}22` }}>
                {story.media.type === "image" && story.media.url ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img src={story.media.thumbnailUrl ?? story.media.url} alt="" loading="lazy" decoding="async" className="h-full w-full object-cover" />
                ) : story.media.type === "video" && story.media.url ? (
                  <div className="text-center text-sm font-semibold text-coffee-700">MP4<br /><span className="text-xs font-normal text-coffee-500">Видео не запускается в списке</span></div>
                ) : <Sparkles className="h-8 w-8" style={{ color: story.accentColor }} />}
              </div>
              <div className="p-4">
                <div className="flex items-start justify-between gap-2"><div className="min-w-0"><h3 className="truncate text-base">{story.title.ru || "Сторис без заголовка"}</h3><p className="mt-1 truncate text-xs text-coffee-500">{story.collectionId ? collectionNames.get(story.collectionId) || "Неизвестная подборка" : "Без подборки"}</p></div><PublicationBadge published={story.isPublished} publishedAt={story.publishedAt} expiresAt={story.expiresAt} /></div>
                <div className="mt-3 flex flex-wrap gap-2 text-xs text-coffee-500">
                  {story.showOnHome && <span className="inline-flex items-center gap-1"><Home className="h-3.5 w-3.5" />Главная</span>}
                  {story.isPinned && <span className="inline-flex items-center gap-1"><Pin className="h-3.5 w-3.5" />Закреплена</span>}
                  <span>{formatDateTime(story.publishedAt)}</span>
                </div>
                <div className="mt-4 flex items-center justify-end gap-2"><button type="button" onClick={() => setEditor({ id: story.id })} className="focus-ring flex h-9 items-center gap-2 rounded-full border border-coffee-900/15 px-3 text-sm font-medium text-coffee-700 hover:border-accent hover:text-accent"><Pencil className="h-4 w-4" />Изменить</button><DeleteButton label="Удалить сторис" busy={false} onDelete={() => deleteStory(story.id)} /></div>
              </div>
            </article>
          ))}
        </div>
      )}
      {editor && <StoryEditor key={editor.id ?? "new"} story={editingStory} nextSortOrder={nextSortOrder} activeHomeCount={activeHomeCount} onClose={() => setEditor(null)} />}
    </div>
  );
}
