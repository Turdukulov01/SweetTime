"use client";

// Филиалы компании: карточки с тумблером «открыт/закрыт» и инлайн-редактированием.
// Изменения клиентские — через updateBranch из company-store.

import { useState, type FormEvent } from "react";
import { Clock, MapPin, PackageX, Pencil, Phone, Plus, X } from "lucide-react";
import { RoleGate } from "@/components/role-gate";
import { Toggle } from "@/components/toggle";
import { useCompanyStore } from "@/lib/company-store";
import type { Branch } from "@/lib/types";
import { cn, pluralRu } from "@/lib/utils";

interface BranchDraft {
  name: string;
  address: string;
  hours: string;
  phone: string;
}

const EMPTY_BRANCH: BranchDraft = {
  name: "",
  address: "",
  hours: "",
  phone: ""
};

const uid = () => Math.random().toString(36).slice(2, 9);

function BranchCard({
  branch,
  unavailableProducts
}: {
  branch: Branch;
  unavailableProducts: string[];
}) {
  const { updateBranch } = useCompanyStore();
  const [editing, setEditing] = useState(false);
  const [showUnavailable, setShowUnavailable] = useState(false);
  const [draft, setDraft] = useState<BranchDraft>({
    name: branch.name,
    address: branch.address,
    hours: branch.hours,
    phone: branch.phone
  });

  function startEdit() {
    setDraft({
      name: branch.name,
      address: branch.address,
      hours: branch.hours,
      phone: branch.phone
    });
    setEditing(true);
  }

  function save() {
    if (!draft.name.trim()) return;
    updateBranch(branch.id, {
      name: draft.name.trim(),
      address: draft.address.trim(),
      hours: draft.hours.trim(),
      phone: draft.phone.trim()
    });
    setEditing(false);
  }

  return (
    <article
      className={cn("surface flex flex-col px-5 py-5", !branch.isOpen && "opacity-70")}
    >
      <div className="flex items-start justify-between gap-3">
        {editing ? (
          <input
            value={draft.name}
            onChange={(e) => setDraft({ ...draft, name: e.target.value })}
            className="input font-semibold"
            placeholder="Название филиала"
          />
        ) : (
          <h2 className="text-base">{branch.name}</h2>
        )}
        <div className="flex shrink-0 items-center gap-2 pt-0.5">
          <span
            className={cn(
              "text-xs font-semibold",
              branch.isOpen
                ? "text-emerald-700 dark:text-mint-300"
                : "text-red-600 dark:text-red-400"
            )}
          >
            {branch.isOpen ? "Открыт" : "Закрыт"}
          </span>
          <Toggle
            checked={branch.isOpen}
            onChange={(isOpen) => updateBranch(branch.id, { isOpen })}
            label={branch.isOpen ? "Закрыть филиал" : "Открыть филиал"}
          />
        </div>
      </div>

      <div className="mt-4 flex-1 space-y-2.5 text-sm text-coffee-700">
        <div className="flex items-center gap-2.5">
          <MapPin className="h-4 w-4 shrink-0 text-coffee-500" />
          {editing ? (
            <input
              value={draft.address}
              onChange={(e) => setDraft({ ...draft, address: e.target.value })}
              className="input"
              placeholder="Адрес"
            />
          ) : (
            <span>{branch.address}</span>
          )}
        </div>
        <div className="flex items-center gap-2.5">
          <Clock className="h-4 w-4 shrink-0 text-coffee-500" />
          {editing ? (
            <input
              value={draft.hours}
              onChange={(e) => setDraft({ ...draft, hours: e.target.value })}
              className="input"
              placeholder="09:00–22:00"
            />
          ) : (
            <span>{branch.hours}</span>
          )}
        </div>
        <div className="flex items-center gap-2.5">
          <Phone className="h-4 w-4 shrink-0 text-coffee-500" />
          {editing ? (
            <input
              value={draft.phone}
              onChange={(e) => setDraft({ ...draft, phone: e.target.value })}
              className="input"
              placeholder="+996 ..."
            />
          ) : (
            <span>{branch.phone}</span>
          )}
        </div>
        <div className="flex items-center gap-2.5">
          <PackageX className="h-4 w-4 shrink-0 text-coffee-500" />
          {unavailableProducts.length > 0 ? (
            <button
              type="button"
              onClick={() => setShowUnavailable(true)}
              className="focus-ring rounded text-left underline decoration-dotted underline-offset-4 transition hover:text-accent"
            >
              Недоступно {unavailableProducts.length}{" "}
              {pluralRu(
                unavailableProducts.length,
                "товар",
                "товара",
                "товаров"
              )}
            </button>
          ) : (
            <span className="text-emerald-700 dark:text-mint-300">
              Все товары доступны
            </span>
          )}
        </div>
      </div>

      {showUnavailable && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4"
          role="dialog"
          aria-modal="true"
          aria-label={`Недоступные товары — ${branch.name}`}
          onClick={() => setShowUnavailable(false)}
        >
          <div
            className="surface w-full max-w-md overflow-hidden p-0"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="flex items-center justify-between border-b border-coffee-900/10 px-5 py-4">
              <h3 className="flex items-center gap-2 text-base font-semibold text-coffee-900">
                <PackageX className="h-4 w-4 text-accent" />
                Недоступно в «{branch.name}»
              </h3>
              <button
                type="button"
                onClick={() => setShowUnavailable(false)}
                aria-label="Закрыть"
                className="focus-ring rounded-full p-1 text-coffee-500 transition hover:bg-coffee-900/5"
              >
                <X className="h-5 w-5" />
              </button>
            </div>
            <ul className="max-h-[64vh] overflow-y-auto px-5 py-3">
              {unavailableProducts.map((name, index) => (
                <li
                  key={`${name}-${index}`}
                  className="flex items-center gap-2 border-b border-coffee-900/5 py-2 text-sm text-coffee-700 last:border-0 dark:text-coffee-200"
                >
                  <span className="h-1.5 w-1.5 shrink-0 rounded-full bg-accent/60" />
                  {name}
                </li>
              ))}
            </ul>
          </div>
        </div>
      )}

      <div className="mt-5 flex gap-2">
        {editing ? (
          <>
            <button
              type="button"
              onClick={save}
              disabled={!draft.name.trim()}
              className="focus-ring flex h-10 flex-1 items-center justify-center rounded-full bg-accent text-sm font-semibold text-white transition hover:opacity-90 disabled:opacity-40"
            >
              Сохранить
            </button>
            <button
              type="button"
              onClick={() => setEditing(false)}
              className="focus-ring flex h-10 items-center justify-center rounded-full border border-coffee-900/15 px-4 text-sm font-medium text-coffee-700 transition hover:bg-coffee-900/5"
            >
              Отмена
            </button>
          </>
        ) : (
          <button
            type="button"
            onClick={startEdit}
            className="focus-ring flex h-10 items-center gap-2 rounded-full border border-coffee-900/15 px-4 text-sm font-medium text-coffee-700 transition hover:border-accent hover:text-accent"
          >
            <Pencil className="h-4 w-4" />
            Редактировать
          </button>
        )}
      </div>
    </article>
  );
}

function BranchesContent() {
  const { company, branches, products, addBranch } = useCompanyStore();
  const [createOpen, setCreateOpen] = useState(false);
  const [draft, setDraft] = useState<BranchDraft>(EMPTY_BRANCH);
  const [createError, setCreateError] = useState<string | null>(null);

  function closeCreate() {
    setCreateOpen(false);
    setDraft(EMPTY_BRANCH);
    setCreateError(null);
  }

  function createBranch(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const normalized = {
      name: draft.name.trim(),
      address: draft.address.trim(),
      hours: draft.hours.trim(),
      phone: draft.phone.trim()
    };
    if (Object.values(normalized).some((value) => !value)) {
      setCreateError("Заполните название, адрес, часы работы и телефон");
      return;
    }
    addBranch({
      id: `${company.id}-b-${uid()}`,
      companyId: company.id,
      ...normalized,
      isOpen: true
    });
    closeCreate();
  }

  return (
    <div>
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl">Филиалы</h1>
          <p className="mt-1 text-sm text-coffee-500">
            {branches.length}{" "}
            {pluralRu(branches.length, "филиал", "филиала", "филиалов")} ·{" "}
            {branches.filter((b) => b.isOpen).length} сейчас открыто
          </p>
        </div>
        <button
          type="button"
          onClick={() => (createOpen ? closeCreate() : setCreateOpen(true))}
          className="focus-ring flex h-11 items-center gap-2 rounded-full bg-accent px-5 text-sm font-semibold text-white transition hover:opacity-90"
        >
          {createOpen ? <X className="h-4 w-4" /> : <Plus className="h-4 w-4" />}
          {createOpen ? "Отмена" : "Добавить филиал"}
        </button>
      </div>

      {createOpen && (
        <form
          onSubmit={createBranch}
          className="surface mt-6 grid grid-cols-1 gap-4 px-5 py-5 md:grid-cols-2"
          noValidate
        >
          {(
            [
              ["name", "Название", "SweetTime · Новый филиал"],
              ["address", "Адрес", "ул. Киевская, 100"],
              ["hours", "Часы работы", "09:00–22:00"],
              ["phone", "Телефон", "+996 555 000 000"]
            ] as const
          ).map(([field, label, placeholder]) => (
            <label key={field}>
              <span className="mb-1.5 block text-sm font-medium text-coffee-700">
                {label}
              </span>
              <input
                required
                value={draft[field]}
                onChange={(e) => {
                  setDraft((prev) => ({ ...prev, [field]: e.target.value }));
                  setCreateError(null);
                }}
                placeholder={placeholder}
                className="input"
              />
            </label>
          ))}
          {createError && (
            <p role="alert" className="text-sm font-medium text-red-600 dark:text-red-400 md:col-span-2">
              {createError}
            </p>
          )}
          <div className="flex gap-2 md:col-span-2">
            <button
              type="submit"
              className="focus-ring flex h-11 items-center rounded-full bg-accent px-6 text-sm font-semibold text-white transition hover:opacity-90"
            >
              Создать филиал
            </button>
            <button
              type="button"
              onClick={closeCreate}
              className="focus-ring flex h-11 items-center rounded-full border border-coffee-900/15 px-5 text-sm font-medium text-coffee-700 transition hover:bg-coffee-900/5"
            >
              Отмена
            </button>
          </div>
        </form>
      )}

      <div className="mt-6 grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-3">
        {branches.map((branch) => (
          <BranchCard
            key={branch.id}
            branch={branch}
            unavailableProducts={products
              .filter((p) => !p.availableBranchIds.includes(branch.id))
              .map((p) => p.name)}
          />
        ))}
      </div>
    </div>
  );
}

export default function BranchesPage() {
  return (
    <RoleGate allow={["owner", "manager"]}>
      <BranchesContent />
    </RoleGate>
  );
}
