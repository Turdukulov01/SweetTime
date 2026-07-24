"use client";

import { useEffect, useId, useRef, useState, type ReactNode } from "react";
import {
  AlertTriangle,
  CalendarClock,
  ImagePlus,
  LoaderCircle,
  Send,
  Trash2,
  Upload,
  X
} from "lucide-react";
import {
  mediaTypeForFile,
  toDateTimeLocal,
  validateMediaFile
} from "@/lib/content-validation";
import { describeApiError } from "@/lib/api";
import type { ContentMedia } from "@/lib/types";
import { cn } from "@/lib/utils";

export function ContentDrawer({
  title,
  busy,
  error,
  onClose,
  onSave,
  saveLabel = "Сохранить",
  children
}: {
  title: string;
  busy: boolean;
  error: string | null;
  onClose: () => void;
  onSave: () => void;
  saveLabel?: string;
  children: ReactNode;
}) {
  return (
    <div className="fixed inset-0 z-50">
      <button
        type="button"
        aria-label="Закрыть редактор"
        disabled={busy}
        onClick={onClose}
        className="absolute inset-0 h-full w-full bg-coffee-900/30 dark:bg-black/60"
      />
      <aside
        role="dialog"
        aria-modal="true"
        aria-label={title}
        className="absolute right-0 top-0 flex h-full w-full max-w-2xl flex-col bg-cream-50 shadow-soft dark:bg-[#1d181b]"
      >
        <header className="flex items-center justify-between border-b border-coffee-900/10 px-6 py-4">
          <h2 className="text-lg">{title}</h2>
          <button
            type="button"
            onClick={onClose}
            disabled={busy}
            title="Закрыть"
            className="focus-ring flex h-9 w-9 items-center justify-center rounded-full text-coffee-500 transition hover:bg-coffee-900/5 disabled:opacity-40"
          >
            <X className="h-5 w-5" />
          </button>
        </header>
        <div className="flex-1 space-y-5 overflow-y-auto px-6 py-5">{children}</div>
        <footer className="border-t border-coffee-900/10 px-6 py-4">
          {error && (
            <p role="alert" className="mb-3 flex items-start gap-2 rounded-xl bg-red-50 px-3 py-2 text-sm font-medium text-red-700 dark:bg-red-500/10 dark:text-red-300">
              <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0" />
              {error}
            </p>
          )}
          <div className="flex gap-2">
            <button
              type="button"
              onClick={onSave}
              disabled={busy}
              className="focus-ring flex h-11 flex-1 items-center justify-center gap-2 rounded-full bg-accent px-5 text-sm font-semibold text-white transition hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-50"
            >
              {busy && <LoaderCircle className="h-4 w-4 animate-spin" />}
              {busy ? "Сохраняем на сервере…" : saveLabel}
            </button>
            <button
              type="button"
              onClick={onClose}
              disabled={busy}
              className="focus-ring h-11 rounded-full border border-coffee-900/15 px-5 text-sm font-medium text-coffee-700 transition hover:bg-coffee-900/5 disabled:opacity-40"
            >
              Отмена
            </button>
          </div>
        </footer>
      </aside>
    </div>
  );
}

export function MediaPicker({
  current,
  selectedFile,
  removed,
  allowVideo,
  round = false,
  onFileChange,
  onRemove
}: {
  current: ContentMedia;
  selectedFile: File | null;
  removed: boolean;
  allowVideo: boolean;
  round?: boolean;
  onFileChange: (file: File | null) => void;
  onRemove: () => void;
}) {
  const inputId = useId();
  const inputRef = useRef<HTMLInputElement>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [fileError, setFileError] = useState<string | null>(null);

  useEffect(() => {
    if (!selectedFile) {
      setPreviewUrl(null);
      return;
    }
    const url = URL.createObjectURL(selectedFile);
    setPreviewUrl(url);
    return () => URL.revokeObjectURL(url);
  }, [selectedFile]);

  const selectedType = selectedFile ? mediaTypeForFile(selectedFile) : null;
  const visibleType = selectedType ?? (removed ? "none" : current.type);
  const visibleUrl = previewUrl ?? (removed ? null : current.url);
  const hasMedia = Boolean(visibleUrl && visibleType !== "none");

  function selectFile(file: File | null) {
    if (!file) return;
    const validationError = validateMediaFile(file, allowVideo);
    if (validationError) {
      setFileError(validationError);
      if (inputRef.current) inputRef.current.value = "";
      return;
    }
    setFileError(null);
    onFileChange(file);
  }

  return (
    <div>
      <div
        className={cn(
          "relative flex min-h-44 items-center justify-center overflow-hidden border border-dashed border-coffee-900/20 bg-coffee-900/5",
          round ? "mx-auto h-44 w-44 rounded-full" : "rounded-2xl"
        )}
      >
        {hasMedia && visibleType === "image" && (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={visibleUrl ?? ""} alt="Предпросмотр медиа" className="h-full w-full object-cover" />
        )}
        {hasMedia && visibleType === "video" && (
          <video src={visibleUrl ?? ""} controls preload="metadata" className="max-h-72 w-full bg-black" />
        )}
        {!hasMedia && (
          <span className="flex flex-col items-center gap-2 px-5 text-center text-sm text-coffee-500">
            <ImagePlus className="h-7 w-7 opacity-60" />
            Медиа ещё не выбрано
          </span>
        )}
      </div>
      <input
        ref={inputRef}
        id={inputId}
        type="file"
        accept={allowVideo ? "image/jpeg,image/png,image/webp,video/mp4,.mp4" : "image/jpeg,image/png,image/webp"}
        onChange={(event) => selectFile(event.target.files?.[0] ?? null)}
        className="sr-only"
      />
      <div className="mt-3 flex flex-wrap items-center gap-2">
        <label
          htmlFor={inputId}
          className="focus-ring flex h-10 cursor-pointer items-center gap-2 rounded-full border border-coffee-900/15 px-4 text-sm font-medium text-coffee-700 transition hover:border-accent hover:text-accent"
        >
          <Upload className="h-4 w-4" />
          {hasMedia ? "Заменить" : "Выбрать файл"}
        </label>
        {(hasMedia || selectedFile || (!removed && current.url)) && (
          <button
            type="button"
            onClick={() => {
              setFileError(null);
              if (inputRef.current) inputRef.current.value = "";
              onRemove();
            }}
            className="focus-ring flex h-10 items-center gap-2 rounded-full px-4 text-sm font-medium text-red-600 transition hover:bg-red-50 dark:text-red-400 dark:hover:bg-red-500/10"
          >
            <Trash2 className="h-4 w-4" />
            Удалить
          </button>
        )}
      </div>
      <p className="mt-2 text-xs leading-relaxed text-coffee-500">
        {allowVideo
          ? "Изображение: JPEG, PNG или WebP до 10 МиБ. Видео: готовый H.264/AAC MP4 до 50 МиБ — сервер не перекодирует видео."
          : "Обложка: JPEG, PNG или WebP до 10 МиБ. В приложении она показывается круглой."}
      </p>
      {fileError && <p role="alert" className="mt-1 text-xs font-medium text-red-600 dark:text-red-400">{fileError}</p>}
    </div>
  );
}

export function PublicationBadge({
  published,
  publishedAt,
  expiresAt
}: {
  published: boolean;
  publishedAt?: string;
  expiresAt?: string | null;
}) {
  const now = Date.now();
  const scheduled = published && publishedAt !== undefined && Date.parse(publishedAt) > now;
  const expired = published && expiresAt !== undefined && expiresAt !== null && Date.parse(expiresAt) <= now;
  const label = !published ? "Черновик" : scheduled ? "Запланировано" : expired ? "Истекло" : "Опубликовано";
  return (
    <span className={cn(
      "inline-flex rounded-full px-2.5 py-1 text-xs font-semibold",
      published && !scheduled && !expired
        ? "bg-mint-100 text-emerald-700 dark:bg-mint-500/15 dark:text-mint-300"
        : scheduled
          ? "bg-cream-100 text-coffee-700 dark:bg-cream-200/15"
          : "bg-coffee-900/5 text-coffee-500 dark:bg-white/10"
    )}>
      {label}
    </span>
  );
}

export type PublicationMode = "now" | "scheduled";

export function PublicationTimingPicker({
  mode,
  value,
  onModeChange,
  onValueChange
}: {
  mode: PublicationMode;
  value: string;
  onModeChange: (mode: PublicationMode) => void;
  onValueChange: (value: string) => void;
}) {
  const [zoneLabel, setZoneLabel] = useState("локальное время компьютера");

  useEffect(() => {
    const zone = Intl.DateTimeFormat().resolvedOptions().timeZone;
    const offsetMinutes = -new Date().getTimezoneOffset();
    const offsetSign = offsetMinutes >= 0 ? "+" : "-";
    const offsetHours = String(
      Math.floor(Math.abs(offsetMinutes) / 60)
    ).padStart(2, "0");
    const offsetRemainder = String(Math.abs(offsetMinutes) % 60).padStart(
      2,
      "0"
    );
    setZoneLabel(
      zone
        ? `${zone}, UTC${offsetSign}${offsetHours}:${offsetRemainder}`
        : `UTC${offsetSign}${offsetHours}:${offsetRemainder}`
    );
  }, []);

  function selectMode(next: PublicationMode) {
    onModeChange(next);
    const parsedValue = Date.parse(value);
    if (
      next === "scheduled" &&
      (!value || Number.isNaN(parsedValue) || parsedValue <= Date.now())
    ) {
      onValueChange(
        toDateTimeLocal(new Date(Date.now() + 60 * 60 * 1000).toISOString())
      );
    }
  }

  return (
    <fieldset className="rounded-2xl border border-coffee-900/10 p-4">
      <legend className="px-1 text-sm font-semibold text-coffee-700">
        Когда публикация появится в приложении
      </legend>
      <div className="mt-2 grid gap-2 sm:grid-cols-2">
        <button
          type="button"
          aria-pressed={mode === "now"}
          onClick={() => selectMode("now")}
          className={cn(
            "focus-ring flex min-h-12 items-center gap-3 rounded-xl border px-4 py-3 text-left text-sm font-semibold transition",
            mode === "now"
              ? "border-accent bg-accent/10 text-accent"
              : "border-coffee-900/15 text-coffee-700 hover:border-accent/60"
          )}
        >
          <Send className="h-4 w-4 shrink-0" />
          Сразу после сохранения
        </button>
        <button
          type="button"
          aria-pressed={mode === "scheduled"}
          onClick={() => selectMode("scheduled")}
          className={cn(
            "focus-ring flex min-h-12 items-center gap-3 rounded-xl border px-4 py-3 text-left text-sm font-semibold transition",
            mode === "scheduled"
              ? "border-accent bg-accent/10 text-accent"
              : "border-coffee-900/15 text-coffee-700 hover:border-accent/60"
          )}
        >
          <CalendarClock className="h-4 w-4 shrink-0" />
          В выбранную дату и время
        </button>
      </div>
      {mode === "scheduled" && (
        <label className="mt-4 block">
          <span className="mb-1.5 block text-sm font-medium text-coffee-700">
            Дата и время публикации
          </span>
          <input
            type="datetime-local"
            value={value}
            step={60}
            onChange={(event) => onValueChange(event.target.value)}
            className="input"
          />
        </label>
      )}
      <p className="mt-3 text-xs leading-relaxed text-coffee-500">
        Используется время этого компьютера: {zoneLabel}. Сервер сохранит его в
        UTC и автоматически откроет публикацию в указанную минуту.
      </p>
    </fieldset>
  );
}

export function DeleteButton({ label, busy, onDelete }: { label: string; busy: boolean; onDelete: () => Promise<void> }) {
  const [confirm, setConfirm] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [pending, setPending] = useState(false);
  if (!confirm) {
    return (
      <button type="button" title={label} disabled={busy} onClick={() => setConfirm(true)} className="focus-ring flex h-9 w-9 items-center justify-center rounded-full text-coffee-500 transition hover:bg-red-50 hover:text-red-600 disabled:opacity-40 dark:hover:bg-red-500/10">
        <Trash2 className="h-4 w-4" />
      </button>
    );
  }
  return (
    <span className="flex flex-wrap items-center justify-end gap-2">
      {error && <span className="text-xs text-red-600">{error}</span>}
      <span className="text-xs text-coffee-500">Удалить?</span>
      <button
        type="button"
        disabled={pending}
        onClick={async () => {
          setPending(true);
          setError(null);
          try {
            await onDelete();
          } catch (caught) {
            setPending(false);
            setError(describeApiError(caught));
          }
        }}
        className="focus-ring rounded-full bg-red-600 px-3 py-1 text-xs font-semibold text-white disabled:opacity-50"
      >
        {pending ? "Удаляем…" : "Да"}
      </button>
      <button type="button" disabled={pending} onClick={() => setConfirm(false)} className="focus-ring rounded-full border border-coffee-900/15 px-3 py-1 text-xs font-medium text-coffee-700">Нет</button>
    </span>
  );
}
