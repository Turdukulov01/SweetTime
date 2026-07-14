"use client";

// Поле локализованного текста витрины: русский обязателен и всегда виден,
// кыргызский и английский — в сворачиваемом блоке (опционально).

import { useState } from "react";
import { Languages } from "lucide-react";
import type { LocalizedText } from "@/lib/types";
import { cn } from "@/lib/utils";

export function LocalizedField({
  label,
  value,
  onChange,
  multiline = false,
  placeholder,
  required = false
}: {
  label: string;
  value: LocalizedText;
  onChange: (next: LocalizedText) => void;
  multiline?: boolean;
  placeholder?: string;
  required?: boolean;
}) {
  const [open, setOpen] = useState(
    Boolean(value.ky?.trim() || value.en?.trim())
  );

  const controlClass = cn("input", multiline && "min-h-[76px] resize-y py-2.5");

  const control = (
    lang: "ru" | "ky" | "en",
    ph: string,
    autoFocus = false
  ) => {
    const commonProps = {
      value: value[lang] ?? "",
      placeholder: ph,
      className: controlClass,
      onChange: (
        e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>
      ) => onChange({ ...value, [lang]: e.target.value })
    };
    return multiline ? (
      <textarea {...commonProps} />
    ) : (
      <input {...commonProps} autoFocus={autoFocus} />
    );
  };

  return (
    <div>
      <div className="mb-1.5 flex items-center justify-between gap-2">
        <span className="text-sm font-medium text-coffee-700">
          {label}
          {required && <span className="text-candy-500"> *</span>}
        </span>
        <button
          type="button"
          onClick={() => setOpen((o) => !o)}
          aria-pressed={open}
          className={cn(
            "focus-ring flex items-center gap-1 rounded-full border px-2.5 py-1 text-[11px] font-semibold transition",
            open
              ? "border-accent bg-accent/10 text-accent"
              : "border-coffee-900/15 text-coffee-500 hover:border-accent hover:text-accent"
          )}
        >
          <Languages className="h-3 w-3" />
          KY / EN
        </button>
      </div>

      {control("ru", placeholder ?? "На русском")}

      {open && (
        <div className="mt-2 space-y-2 rounded-xl border border-dashed border-coffee-900/15 p-3">
          <label className="block">
            <span className="mb-1 block text-xs font-medium text-coffee-500">
              Кыргызча
            </span>
            {control("ky", "Кыргызча (необязательно)")}
          </label>
          <label className="block">
            <span className="mb-1 block text-xs font-medium text-coffee-500">
              English
            </span>
            {control("en", "English (optional)")}
          </label>
        </div>
      )}
    </div>
  );
}
