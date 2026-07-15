import type { LocalizedText } from "@/lib/types";

export const emptyLocalized = (): LocalizedText => ({ ru: "", ky: "", en: "" });

export function hasAnyLocalizedText(value: LocalizedText): boolean {
  return [value.ru, value.ky, value.en].some((text) => Boolean(text?.trim()));
}

export function missingLocales(value: LocalizedText): string[] {
  const labels: Array<[keyof LocalizedText, string]> = [
    ["ru", "RU"],
    ["ky", "KY"],
    ["en", "EN"]
  ];
  return labels.filter(([key]) => !value[key]?.trim()).map(([, label]) => label);
}

export function localizedPublishError(value: LocalizedText): string | null {
  const missing = missingLocales(value);
  return missing.length ? `Для публикации заполните: ${missing.join(", ")}` : null;
}

export function toDateTimeLocal(iso: string): string {
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return "";
  const shifted = new Date(date.getTime() - date.getTimezoneOffset() * 60_000);
  return shifted.toISOString().slice(0, 16);
}

export function fromDateTimeLocal(value: string): string | null {
  if (!value) return null;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
}

export function formatDateTime(iso: string): string {
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return "Некорректная дата";
  return new Intl.DateTimeFormat("ru-RU", {
    dateStyle: "medium",
    timeStyle: "short"
  }).format(date);
}

export function validateMediaFile(
  file: File,
  allowVideo: boolean
): string | null {
  const imageTypes = ["image/jpeg", "image/png", "image/webp"];
  const lowerName = file.name.toLowerCase();
  const isImage = imageTypes.includes(file.type);
  const isVideo =
    allowVideo && file.type === "video/mp4" && lowerName.endsWith(".mp4");
  if (!isImage && !isVideo) {
    return allowVideo
      ? "Допустимы JPEG, PNG, WebP или MP4."
      : "Для обложки допустимы только JPEG, PNG или WebP.";
  }
  const limit = isVideo ? 50 * 1024 * 1024 : 10 * 1024 * 1024;
  if (file.size > limit) {
    return isVideo ? "MP4 должен быть не больше 50 МиБ." : "Изображение должно быть не больше 10 МиБ.";
  }
  return null;
}

export function mediaTypeForFile(file: File): "image" | "video" {
  return file.type === "video/mp4" ? "video" : "image";
}
