"use client";

import { cn } from "@/lib/utils";

export function Toggle({
  checked,
  onChange,
  label,
  disabled
}: {
  checked: boolean;
  onChange: (next: boolean) => void;
  label: string;
  disabled?: boolean;
}) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      aria-label={label}
      title={label}
      disabled={disabled}
      onClick={(event) => {
        event.stopPropagation();
        onChange(!checked);
      }}
      className={cn(
        "focus-ring relative inline-flex h-6 w-11 shrink-0 items-center rounded-full transition",
        checked ? "bg-accent" : "bg-coffee-900/15",
        disabled && "cursor-not-allowed opacity-50"
      )}
    >
      <span
        className={cn(
          "inline-block h-5 w-5 rounded-full bg-white shadow transition-transform",
          checked ? "translate-x-[22px]" : "translate-x-0.5"
        )}
      />
    </button>
  );
}
