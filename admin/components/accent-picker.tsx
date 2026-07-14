"use client";

// Выбор акцентного цвета: пресеты + ручной ввод hex (#RRGGBB).
// Меняет значение только при валидном hex; черновик синхронизируется извне.

import { useEffect, useState } from "react";
import { Check } from "lucide-react";
import { cn } from "@/lib/utils";

const DEFAULT_PRESETS = [
  "#FF8FBD",
  "#8FDCC4",
  "#FFC96B",
  "#A9D88E",
  "#7C5CFF",
  "#FF8A3D",
  "#2D9CDB"
];

const HEX_RE = /^#?([0-9a-fA-F]{6})$/;

export function AccentPicker({
  value,
  onChange,
  presets = DEFAULT_PRESETS
}: {
  value: string;
  onChange: (hex: string) => void;
  presets?: string[];
}) {
  const [hexDraft, setHexDraft] = useState(value);
  useEffect(() => {
    setHexDraft(value);
  }, [value]);

  function applyHex(raw: string) {
    setHexDraft(raw);
    const match = HEX_RE.exec(raw.trim());
    if (match) onChange(`#${match[1].toUpperCase()}`);
  }

  return (
    <div>
      <div className="flex flex-wrap items-center gap-2">
        {presets.map((color) => (
          <button
            key={color}
            type="button"
            onClick={() => onChange(color)}
            title={color}
            style={{ backgroundColor: color }}
            className={cn(
              "focus-ring flex h-9 w-9 items-center justify-center rounded-full transition",
              value.toUpperCase() === color.toUpperCase() &&
                "ring-2 ring-coffee-900 ring-offset-2 dark:ring-cream-50 dark:ring-offset-[#1d181b]"
            )}
          >
            {value.toUpperCase() === color.toUpperCase() && (
              <Check className="h-4 w-4 text-white" />
            )}
          </button>
        ))}
      </div>
      <div className="mt-2.5 flex items-center gap-2">
        <span
          className="h-9 w-9 shrink-0 rounded-full border border-coffee-900/10"
          style={{ backgroundColor: value }}
          aria-hidden="true"
        />
        <input
          value={hexDraft}
          onChange={(e) => applyHex(e.target.value)}
          placeholder="#FF8FBD"
          className="input w-36 font-mono"
          aria-label="Свой цвет hex"
        />
      </div>
    </div>
  );
}
