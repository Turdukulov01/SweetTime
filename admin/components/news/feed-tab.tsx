"use client";

import { useState } from "react";
import { CalendarClock, FileText, Pencil, Plus, RefreshCw } from "lucide-react";
import { LocalizedField } from "@/components/localized-field";
import { Toggle } from "@/components/toggle";
import {
  ContentDrawer,
  DeleteButton,
  MediaPicker,
  PublicationBadge
} from "@/components/news/content-shared";
import { describeApiError, type NewsPostWrite } from "@/lib/api";
import { useContentManager } from "@/lib/content-store";
import {
  emptyLocalized,
  formatDateTime,
  fromDateTimeLocal,
  localizedPublishError,
  toDateTimeLocal
} from "@/lib/content-validation";
import type { ContentMedia, LocalizedText, NewsPost } from "@/lib/types";

interface PostDraft {
  title: LocalizedText;
  summary: LocalizedText;
  body: LocalizedText;
  isPublished: boolean;
  publishedAt: string;
}

const EMPTY_MEDIA: ContentMedia = { type: "none", url: null, thumbnailUrl: null };

function PostEditor({ post, onClose }: { post: NewsPost | null; onClose: () => void }) {
  const { savePost, uploadPostMedia, removePostMedia } = useContentManager();
  const [persisted, setPersisted] = useState<NewsPost | null>(post);
  const [draft, setDraft] = useState<PostDraft>(() => post ? {
    title: { ...post.title },
    summary: { ...post.summary },
    body: { ...post.body },
    isPublished: post.isPublished,
    publishedAt: toDateTimeLocal(post.publishedAt)
  } : {
    title: emptyLocalized(),
    summary: emptyLocalized(),
    body: emptyLocalized(),
    isPublished: false,
    publishedAt: toDateTimeLocal(new Date().toISOString())
  });
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [mediaRemoved, setMediaRemoved] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const currentMedia = persisted?.media ?? EMPTY_MEDIA;

  function validate(): string | null {
    const titleError = localizedPublishError(draft.title);
    if (titleError) return `Заголовок обязателен на трёх языках. ${titleError}`;
    if (!fromDateTimeLocal(draft.publishedAt)) return "Укажите корректную дату публикации.";
    if (draft.isPublished) {
      const summaryError = localizedPublishError(draft.summary);
      if (summaryError) return `Анонс: ${summaryError}`;
      const bodyError = localizedPublishError(draft.body);
      if (bodyError) return `Полный текст: ${bodyError}`;
    }
    return null;
  }

  async function handleSave() {
    const validationError = validate();
    if (validationError) {
      setError(validationError);
      return;
    }
    const desired: NewsPostWrite = {
      title: draft.title,
      summary: draft.summary,
      body: draft.body,
      isPublished: draft.isPublished,
      publishedAt: fromDateTimeLocal(draft.publishedAt) as string
    };
    setBusy(true);
    setError(null);
    try {
      const publishAfterUpload = !persisted && Boolean(selectedFile) && desired.isPublished;
      let saved = await savePost(
        persisted?.id ?? null,
        publishAfterUpload ? { ...desired, isPublished: false } : desired
      );
      setPersisted(saved);
      if (selectedFile) {
        saved = await uploadPostMedia(saved.id, selectedFile);
        setPersisted(saved);
        setSelectedFile(null);
        setMediaRemoved(false);
      } else if (mediaRemoved && saved.media.url) {
        saved = await removePostMedia(saved.id);
        setPersisted(saved);
        setMediaRemoved(false);
      }
      if (publishAfterUpload) {
        saved = await savePost(saved.id, desired);
        setPersisted(saved);
      }
      onClose();
    } catch (caught) {
      setError(describeApiError(caught));
      setBusy(false);
    }
  }

  return (
    <ContentDrawer title={post ? "Редактировать публикацию" : "Новая публикация"} busy={busy} error={error} onClose={onClose} onSave={() => void handleSave()} saveLabel={post ? "Сохранить" : "Создать публикацию"}>
      <MediaPicker
        current={currentMedia}
        selectedFile={selectedFile}
        removed={mediaRemoved}
        allowVideo
        onFileChange={(file) => { setSelectedFile(file); setMediaRemoved(false); }}
        onRemove={() => { if (selectedFile) setSelectedFile(null); setMediaRemoved(Boolean(currentMedia.url)); }}
      />
      <LocalizedField label="Заголовок" required requiredAll alwaysExpanded value={draft.title} onChange={(title) => setDraft({ ...draft, title })} maxLength={120} />
      <LocalizedField label="Краткий анонс" required={draft.isPublished} requiredAll={draft.isPublished} alwaysExpanded multiline value={draft.summary} onChange={(summary) => setDraft({ ...draft, summary })} maxLength={280} />
      <LocalizedField label="Полный текст" required={draft.isPublished} requiredAll={draft.isPublished} alwaysExpanded multiline value={draft.body} onChange={(body) => setDraft({ ...draft, body })} maxLength={20000} />
      <label className="block"><span className="mb-1.5 block text-sm font-medium text-coffee-700">Дата публикации</span><input type="datetime-local" value={draft.publishedAt} onChange={(event) => setDraft({ ...draft, publishedAt: event.target.value })} className="input" /><span className="mt-1.5 flex items-center gap-1 text-xs text-coffee-500"><CalendarClock className="h-3.5 w-3.5" />Для новой публикации подставляется автоматически; при необходимости дату можно изменить.</span></label>
      <div className="flex items-center justify-between rounded-2xl border border-coffee-900/10 p-4"><div><p className="text-sm font-medium text-coffee-700">Опубликовать</p><p className="text-xs text-coffee-500">Будущая дата оставит запись запланированной до указанного времени.</p></div><Toggle checked={draft.isPublished} onChange={(isPublished) => setDraft({ ...draft, isPublished })} label="Опубликовать запись" /></div>
    </ContentDrawer>
  );
}

export function FeedTab() {
  const { posts, reloadPosts, deletePost } = useContentManager();
  const [editor, setEditor] = useState<{ id: string | null } | null>(null);
  const editing = editor?.id ? posts.items.find((item) => item.id === editor.id) ?? null : null;
  if (posts.status === "loading" && posts.items.length === 0) return <div className="surface mt-5 px-6 py-14 text-center text-sm text-coffee-500">Загружаем ленту…</div>;
  if (posts.status === "error" && posts.items.length === 0) return <div className="surface mt-5 px-6 py-10 text-center"><p role="alert" className="text-sm text-red-600">{posts.error}</p><button type="button" onClick={() => void reloadPosts()} className="focus-ring mt-4 inline-flex h-10 items-center gap-2 rounded-full bg-accent px-4 text-sm font-semibold text-white"><RefreshCw className="h-4 w-4" />Повторить</button></div>;

  return (
    <div className="mt-5">
      <div className="flex flex-wrap items-center justify-between gap-3"><div><p className="text-sm font-semibold text-coffee-900">{posts.items.length} публикаций</p><p className="mt-1 text-xs text-coffee-500">Постоянная новостная лента: полный текст открывается в приложении отдельно.</p></div><button type="button" onClick={() => setEditor({ id: null })} className="focus-ring flex h-10 items-center gap-2 rounded-full bg-accent px-4 text-sm font-semibold text-white"><Plus className="h-4 w-4" />Новая публикация</button></div>
      {posts.items.length === 0 ? <div className="surface mt-5 flex flex-col items-center gap-2 px-6 py-14 text-center"><FileText className="h-8 w-8 text-coffee-500/50" /><p className="text-sm text-coffee-500">Лента пока пуста.</p></div> : (
        <div className="mt-5 space-y-3">
          {posts.items.map((post) => (
            <article key={post.id} className="surface flex flex-col gap-4 p-4 sm:flex-row sm:items-center">
              <div className="flex h-24 w-full shrink-0 items-center justify-center overflow-hidden rounded-xl bg-coffee-900/5 sm:w-36">
                {post.media.type === "image" && post.media.url ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img src={post.media.thumbnailUrl ?? post.media.url} alt="" loading="lazy" decoding="async" className="h-full w-full object-cover" />
                ) : post.media.type === "video" && post.media.url ? <span className="text-center text-xs font-semibold text-coffee-500">MP4<br />Без автозапуска</span> : <FileText className="h-7 w-7 text-coffee-500/50" />}
              </div>
              <div className="min-w-0 flex-1"><div className="flex flex-wrap items-start justify-between gap-2"><div className="min-w-0"><h3 className="truncate text-base">{post.title.ru}</h3><p className="mt-1 line-clamp-2 text-sm text-coffee-500">{post.summary.ru || "Анонс не заполнен"}</p></div><PublicationBadge published={post.isPublished} publishedAt={post.publishedAt} /></div><p className="mt-2 text-xs text-coffee-500">{formatDateTime(post.publishedAt)}</p></div>
              <div className="flex shrink-0 items-center justify-end gap-2"><button type="button" onClick={() => setEditor({ id: post.id })} className="focus-ring flex h-9 items-center gap-2 rounded-full border border-coffee-900/15 px-3 text-sm font-medium text-coffee-700 hover:border-accent hover:text-accent"><Pencil className="h-4 w-4" />Изменить</button><DeleteButton label="Удалить публикацию" busy={false} onDelete={() => deletePost(post.id)} /></div>
            </article>
          ))}
        </div>
      )}
      {editor && <PostEditor key={editor.id ?? "new"} post={editing} onClose={() => setEditor(null)} />}
    </div>
  );
}
