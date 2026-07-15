"use client";

import { useState } from "react";
import { FolderOpen, Pencil, Plus, RefreshCw, Sparkles } from "lucide-react";
import { AccentPicker } from "@/components/accent-picker";
import { LocalizedField } from "@/components/localized-field";
import { Toggle } from "@/components/toggle";
import {
  ContentDrawer,
  DeleteButton,
  MediaPicker,
  PublicationBadge
} from "@/components/news/content-shared";
import { describeApiError, type StoryCollectionWrite } from "@/lib/api";
import { useCompanyStore } from "@/lib/company-store";
import { useContentManager } from "@/lib/content-store";
import { emptyLocalized, hasAnyLocalizedText, localizedPublishError } from "@/lib/content-validation";
import type { ContentMedia, LocalizedText, NewsVisual, StoryCollection } from "@/lib/types";

interface CollectionDraft {
  name: LocalizedText;
  description: LocalizedText;
  accentColor: string;
  visual: NewsVisual;
  sortOrder: number;
  isPublished: boolean;
}

const EMPTY_MEDIA: ContentMedia = { type: "none", url: null, thumbnailUrl: null };

function CollectionEditor({
  collection,
  nextSortOrder,
  onClose
}: {
  collection: StoryCollection | null;
  nextSortOrder: number;
  onClose: () => void;
}) {
  const { company } = useCompanyStore();
  const { saveCollection, uploadCollectionCover, removeCollectionCover } = useContentManager();
  const [persisted, setPersisted] = useState<StoryCollection | null>(collection);
  const [draft, setDraft] = useState<CollectionDraft>(() => collection ? {
    name: { ...collection.name },
    description: { ...collection.description },
    accentColor: collection.accentColor,
    visual: collection.visual,
    sortOrder: collection.sortOrder,
    isPublished: collection.isPublished
  } : {
    name: emptyLocalized(),
    description: emptyLocalized(),
    accentColor: company.accentColor,
    visual: "sparkle",
    sortOrder: nextSortOrder,
    isPublished: false
  });
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [coverRemoved, setCoverRemoved] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const currentCover: ContentMedia = persisted?.coverImageUrl ? {
    type: "image",
    url: persisted.coverImageUrl,
    thumbnailUrl: persisted.coverThumbnailUrl
  } : EMPTY_MEDIA;

  function validate(): string | null {
    const nameError = localizedPublishError(draft.name);
    if (nameError) return `Название обязательно на трёх языках. ${nameError}`;
    if (draft.isPublished) {
      if (hasAnyLocalizedText(draft.description)) {
        const descriptionError = localizedPublishError(draft.description);
        if (descriptionError) return `Описание: ${descriptionError}`;
      }
    }
    return null;
  }

  async function handleSave() {
    const validationError = validate();
    if (validationError) {
      setError(validationError);
      return;
    }
    const desired: StoryCollectionWrite = { ...draft };
    setBusy(true);
    setError(null);
    try {
      const publishAfterUpload = !persisted && Boolean(selectedFile) && desired.isPublished;
      let saved = await saveCollection(
        persisted?.id ?? null,
        publishAfterUpload ? { ...desired, isPublished: false } : desired
      );
      setPersisted(saved);
      if (selectedFile) {
        saved = await uploadCollectionCover(saved.id, selectedFile);
        setPersisted(saved);
        setSelectedFile(null);
        setCoverRemoved(false);
      } else if (coverRemoved && saved.coverImageUrl) {
        saved = await removeCollectionCover(saved.id);
        setPersisted(saved);
        setCoverRemoved(false);
      }
      if (publishAfterUpload) {
        saved = await saveCollection(saved.id, desired);
        setPersisted(saved);
      }
      onClose();
    } catch (caught) {
      setError(describeApiError(caught));
      setBusy(false);
    }
  }

  return (
    <ContentDrawer title={collection ? "Редактировать подборку" : "Новая подборка"} busy={busy} error={error} onClose={onClose} onSave={() => void handleSave()} saveLabel={collection ? "Сохранить" : "Создать подборку"}>
      <MediaPicker
        current={currentCover}
        selectedFile={selectedFile}
        removed={coverRemoved}
        allowVideo={false}
        round
        onFileChange={(file) => { setSelectedFile(file); setCoverRemoved(false); }}
        onRemove={() => { if (selectedFile) setSelectedFile(null); setCoverRemoved(Boolean(currentCover.url)); }}
      />
      <LocalizedField label="Название" required requiredAll alwaysExpanded value={draft.name} onChange={(name) => setDraft({ ...draft, name })} maxLength={80} />
      <LocalizedField label="Описание" alwaysExpanded multiline value={draft.description} onChange={(description) => setDraft({ ...draft, description })} maxLength={500} />
      <div><p className="mb-1.5 text-sm font-medium text-coffee-700">Акцентный цвет</p><AccentPicker value={draft.accentColor} onChange={(accentColor) => setDraft({ ...draft, accentColor })} /></div>
      <label className="block"><span className="mb-1.5 block text-sm font-medium text-coffee-700">Порядок в `/news`</span><input type="number" value={draft.sortOrder} onChange={(event) => setDraft({ ...draft, sortOrder: Number(event.target.value) || 0 })} className="input" /></label>
      <div className="flex items-center justify-between rounded-2xl border border-coffee-900/10 p-4"><div><p className="text-sm font-medium text-coffee-700">Опубликовать</p><p className="text-xs text-coffee-500">Пустая подборка не появится публично, пока в ней нет опубликованных сторис.</p></div><Toggle checked={draft.isPublished} onChange={(isPublished) => setDraft({ ...draft, isPublished })} label="Опубликовать подборку" /></div>
    </ContentDrawer>
  );
}

export function CollectionsTab() {
  const { collections, reloadCollections, deleteCollection } = useContentManager();
  const [editor, setEditor] = useState<{ id: string | null } | null>(null);
  const editing = editor?.id ? collections.items.find((item) => item.id === editor.id) ?? null : null;
  const nextSortOrder = Math.max(0, ...collections.items.map((item) => item.sortOrder)) + 10;

  if (collections.status === "loading" && collections.items.length === 0) return <div className="surface mt-5 px-6 py-14 text-center text-sm text-coffee-500">Загружаем подборки…</div>;
  if (collections.status === "error" && collections.items.length === 0) return <div className="surface mt-5 px-6 py-10 text-center"><p role="alert" className="text-sm text-red-600">{collections.error}</p><button type="button" onClick={() => void reloadCollections()} className="focus-ring mt-4 inline-flex h-10 items-center gap-2 rounded-full bg-accent px-4 text-sm font-semibold text-white"><RefreshCw className="h-4 w-4" />Повторить</button></div>;

  return (
    <div className="mt-5">
      <div className="flex flex-wrap items-center justify-between gap-3"><div><p className="text-sm font-semibold text-coffee-900">{collections.items.length} подборок</p><p className="mt-1 text-xs text-coffee-500">Подборки живут на странице новостей и рассчитаны на 40+ сторис без загрузки всех медиа в этот список.</p></div><button type="button" onClick={() => setEditor({ id: null })} className="focus-ring flex h-10 items-center gap-2 rounded-full bg-accent px-4 text-sm font-semibold text-white"><Plus className="h-4 w-4" />Новая подборка</button></div>
      {collections.items.length === 0 ? <div className="surface mt-5 flex flex-col items-center gap-2 px-6 py-14 text-center"><FolderOpen className="h-8 w-8 text-coffee-500/50" /><p className="text-sm text-coffee-500">Подборок ещё нет.</p></div> : (
        <div className="mt-5 grid gap-4 lg:grid-cols-2 xl:grid-cols-3">
          {collections.items.map((collection) => (
            <article key={collection.id} className="surface flex items-center gap-4 p-4">
              <div className="flex h-20 w-20 shrink-0 items-center justify-center overflow-hidden rounded-full" style={{ backgroundColor: `${collection.accentColor}22` }}>
                {collection.coverImageUrl ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img src={collection.coverThumbnailUrl ?? collection.coverImageUrl} alt="" loading="lazy" decoding="async" className="h-full w-full object-cover" />
                ) : <Sparkles className="h-7 w-7" style={{ color: collection.accentColor }} />}
              </div>
              <div className="min-w-0 flex-1"><div className="flex items-start justify-between gap-2"><div className="min-w-0"><h3 className="truncate text-base">{collection.name.ru || "Без названия"}</h3><p className="mt-1 text-xs text-coffee-500">{collection.storyCount} сторис · порядок {collection.sortOrder}</p></div><PublicationBadge published={collection.isPublished} /></div><div className="mt-4 flex items-center justify-end gap-2"><button type="button" onClick={() => setEditor({ id: collection.id })} className="focus-ring flex h-9 items-center gap-2 rounded-full border border-coffee-900/15 px-3 text-sm font-medium text-coffee-700 hover:border-accent hover:text-accent"><Pencil className="h-4 w-4" />Изменить</button><DeleteButton label="Удалить подборку" busy={false} onDelete={() => deleteCollection(collection.id)} /></div></div>
            </article>
          ))}
        </div>
      )}
      {editor && <CollectionEditor key={editor.id ?? "new"} collection={editing} nextSortOrder={nextSortOrder} onClose={() => setEditor(null)} />}
    </div>
  );
}
