"use client";

// Сотрудники компании (только owner): роли, филиалы для бариста,
// приглашение новых. Себя удалить нельзя, свою роль менять нельзя.

import { useState, type FormEvent } from "react";
import { Trash2, UserPlus, X } from "lucide-react";
import { RoleGate } from "@/components/role-gate";
import { useCompanyStore } from "@/lib/company-store";
import { ROLE_LABELS } from "@/lib/labels";
import { useSession } from "@/lib/session";
import type { Role } from "@/lib/types";
import { pluralRu } from "@/lib/utils";

const ROLES: Role[] = ["owner", "manager", "barista"];
const uid = () => Math.random().toString(36).slice(2, 9);

function StaffContent() {
  const { company, branches, users, addUser, updateUser, removeUser } =
    useCompanyStore();
  const { user: me } = useSession();

  const [inviteOpen, setInviteOpen] = useState(false);
  const [inviteName, setInviteName] = useState("");
  const [inviteEmail, setInviteEmail] = useState("");
  const [inviteRole, setInviteRole] = useState<Role>("barista");
  const [inviteBranchId, setInviteBranchId] = useState(branches[0]?.id ?? "");
  const [inviteError, setInviteError] = useState<string | null>(null);

  const myId = me?.id;

  function handleInvite(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const name = inviteName.trim();
    const email = inviteEmail.trim().toLowerCase();
    if (!name) {
      setInviteError("Укажите имя сотрудника");
      return;
    }
    if (!/^[A-Za-z0-9@._-]+$/.test(email)) {
      setInviteError(
        "Email может содержать только латинские буквы, цифры и символы @ . - _"
      );
      return;
    }
    if (!/^[A-Za-z0-9._-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/.test(email)) {
      setInviteError("Укажите корректный email");
      return;
    }
    if (users.some((u) => u.email.toLowerCase() === email)) {
      setInviteError("Сотрудник с таким email уже есть");
      return;
    }
    addUser({
      id: `u-${uid()}`,
      email,
      name,
      role: inviteRole,
      companyId: company.id,
      branchId: inviteRole === "barista" ? inviteBranchId : undefined
    });
    setInviteName("");
    setInviteEmail("");
    setInviteRole("barista");
    setInviteBranchId(branches[0]?.id ?? "");
    setInviteError(null);
    setInviteOpen(false);
  }

  function handleRoleChange(userId: string, role: Role) {
    const target = users.find((u) => u.id === userId);
    updateUser(userId, {
      role,
      branchId:
        role === "barista"
          ? (target?.branchId ?? branches[0]?.id)
          : undefined
    });
  }

  return (
    <div>
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl">Сотрудники</h1>
          <p className="mt-1 text-sm text-coffee-500">
            {users.length}{" "}
            {pluralRu(users.length, "сотрудник", "сотрудника", "сотрудников")}{" "}
            в {company.name}
          </p>
        </div>
        <button
          type="button"
          onClick={() => setInviteOpen((v) => !v)}
          className="focus-ring flex h-11 items-center gap-2 rounded-full bg-accent px-5 text-sm font-semibold text-white transition hover:opacity-90"
        >
          {inviteOpen ? (
            <X className="h-4 w-4" />
          ) : (
            <UserPlus className="h-4 w-4" />
          )}
          {inviteOpen ? "Отмена" : "Пригласить сотрудника"}
        </button>
      </div>

      {inviteOpen && (
        <form
          onSubmit={handleInvite}
          className="surface mt-6 flex flex-wrap items-end gap-3 px-5 py-4"
          noValidate
        >
          <label className="min-w-48 flex-1">
            <span className="mb-1.5 block text-sm font-medium text-coffee-700">
              Имя
            </span>
            <input
              type="text"
              required
              value={inviteName}
              onChange={(e) => {
                setInviteName(e.target.value);
                setInviteError(null);
              }}
              placeholder="Алина"
              className="input"
            />
          </label>
          <label className="min-w-56 flex-1">
            <span className="mb-1.5 block text-sm font-medium text-coffee-700">
              Email
            </span>
            <input
              type="text"
              inputMode="email"
              autoCapitalize="none"
              autoCorrect="off"
              required
              value={inviteEmail}
              onChange={(e) => {
                setInviteEmail(e.target.value);
                setInviteError(null);
              }}
              placeholder="barista2@sweettime.kg"
              className="input"
            />
          </label>
          <label>
            <span className="mb-1.5 block text-sm font-medium text-coffee-700">
              Роль
            </span>
            <select
              value={inviteRole}
              onChange={(e) => setInviteRole(e.target.value as Role)}
              className="input w-40"
            >
              {ROLES.map((role) => (
                <option key={role} value={role}>
                  {ROLE_LABELS[role]}
                </option>
              ))}
            </select>
          </label>
          {inviteRole === "barista" && (
            <label>
              <span className="mb-1.5 block text-sm font-medium text-coffee-700">
                Филиал
              </span>
              <select
                value={inviteBranchId}
                onChange={(e) => setInviteBranchId(e.target.value)}
                className="input w-56"
              >
                {branches.map((branch) => (
                  <option key={branch.id} value={branch.id}>
                    {branch.name}
                  </option>
                ))}
              </select>
            </label>
          )}
          <button
            type="submit"
            className="focus-ring flex h-11 items-center rounded-full bg-accent px-6 text-sm font-semibold text-white transition hover:opacity-90"
          >
            Пригласить
          </button>
          {inviteError && (
            <p
              role="alert"
              className="w-full text-sm font-medium text-red-600 dark:text-red-400"
            >
              {inviteError}
            </p>
          )}
        </form>
      )}

      <div className="surface mt-6 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-coffee-900/10 text-left text-xs uppercase tracking-wide text-coffee-500">
                <th className="px-5 py-3 font-semibold">Имя</th>
                <th className="px-5 py-3 font-semibold">Email</th>
                <th className="px-5 py-3 font-semibold">Роль</th>
                <th className="px-5 py-3 font-semibold">Филиал</th>
                <th className="px-5 py-3 text-right font-semibold">Действия</th>
              </tr>
            </thead>
            <tbody>
              {users.map((user) => {
                const isMe = user.id === myId;
                return (
                  <tr
                    key={user.id}
                    className="border-b border-coffee-900/5 last:border-0"
                  >
                    <td className="px-5 py-3 font-semibold text-coffee-900">
                      <label className="sr-only" htmlFor={`staff-name-${user.id}`}>
                        Имя сотрудника {user.email}
                      </label>
                      <input
                        id={`staff-name-${user.id}`}
                        key={`${user.id}-${user.name}`}
                        defaultValue={user.name}
                        onBlur={(e) => {
                          const name = e.currentTarget.value.trim();
                          if (name && name !== user.name) {
                            updateUser(user.id, { name });
                          } else if (!name) {
                            e.currentTarget.value = user.name;
                          }
                        }}
                        className="input min-w-36 font-semibold"
                      />
                      {isMe && (
                        <span className="ml-2 rounded-full bg-accent/10 px-2 py-0.5 text-xs font-medium text-accent">
                          вы
                        </span>
                      )}
                    </td>
                    <td className="px-5 py-3 text-coffee-700">{user.email}</td>
                    <td className="px-5 py-3">
                      <select
                        value={user.role}
                        onChange={(e) =>
                          handleRoleChange(user.id, e.target.value as Role)
                        }
                        disabled={isMe}
                        title={
                          isMe ? "Нельзя изменить собственную роль" : "Роль"
                        }
                        className="input w-36 disabled:cursor-not-allowed disabled:opacity-60"
                      >
                        {ROLES.map((role) => (
                          <option key={role} value={role}>
                            {ROLE_LABELS[role]}
                          </option>
                        ))}
                      </select>
                    </td>
                    <td className="px-5 py-3">
                      {user.role === "barista" ? (
                        <select
                          value={user.branchId ?? ""}
                          onChange={(e) =>
                            updateUser(user.id, { branchId: e.target.value })
                          }
                          className="input w-56"
                        >
                          {!user.branchId && (
                            <option value="">Не назначен</option>
                          )}
                          {branches.map((branch) => (
                            <option key={branch.id} value={branch.id}>
                              {branch.name}
                            </option>
                          ))}
                        </select>
                      ) : (
                        <span className="text-coffee-500">—</span>
                      )}
                    </td>
                    <td className="px-5 py-3 text-right">
                      {isMe ? (
                        <span
                          className="text-xs text-coffee-500"
                          title="Нельзя удалить себя"
                        >
                          Нельзя удалить себя
                        </span>
                      ) : (
                        <button
                          type="button"
                          onClick={() => removeUser(user.id)}
                          title={`Удалить ${user.email}`}
                          className="focus-ring inline-flex h-9 w-9 items-center justify-center rounded-full text-coffee-500 transition hover:bg-red-50 hover:text-red-600 dark:hover:bg-red-500/10 dark:hover:text-red-400"
                        >
                          <Trash2 className="h-4 w-4" />
                        </button>
                      )}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}

export default function StaffPage() {
  return (
    <RoleGate allow={["owner"]}>
      <StaffContent />
    </RoleGate>
  );
}
