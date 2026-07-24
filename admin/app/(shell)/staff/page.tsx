"use client";

import { useCallback, useEffect, useMemo, useState, type FormEvent } from "react";
import {
  Check,
  Clipboard,
  Clock3,
  Mail,
  RefreshCw,
  RotateCw,
  Save,
  ShieldCheck,
  Trash2,
  UserPlus,
  UsersRound
} from "lucide-react";
import { RoleGate } from "@/components/role-gate";
import {
  apiCreateStaffInvitation,
  apiFetchStaff,
  apiFetchStaffInvitations,
  apiPatchStaffMember,
  apiResendStaffInvitation,
  apiRevokeStaffInvitation,
  describeApiError,
  type StaffMemberPatch
} from "@/lib/api";
import { useCompanyStore } from "@/lib/company-store";
import { ROLE_LABELS } from "@/lib/labels";
import { useSession } from "@/lib/session";
import type {
  Branch,
  StaffAssignableRole,
  StaffInvitation,
  StaffMember
} from "@/lib/types";
import { cn, formatDateTime, pluralRu } from "@/lib/utils";

const INVITABLE_ROLES: StaffAssignableRole[] = ["manager", "barista"];
const EMAIL_PATTERN =
  /^[a-z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)+$/i;

function branchName(branches: Branch[], branchId?: string): string {
  if (!branchId) return "Не назначен";
  return branches.find((branch) => branch.id === branchId)?.name ?? branchId;
}

function deliveryPresentation(status: string): {
  label: string;
  description: string;
  className: string;
} {
  const normalized = status.trim().toLowerCase();
  if (normalized.includes("sent")) {
    return {
      label: "Письмо отправлено",
      description: "Приглашение доставляется на указанную почту.",
      className: "bg-emerald-500/10 text-emerald-700 dark:text-emerald-300"
    };
  }
  if (normalized.includes("manual")) {
    return {
      label: "Отправьте ссылку вручную",
      description:
        "Почтовая отправка не настроена. Скопируйте безопасную ссылку и передайте сотруднику.",
      className: "bg-amber-500/10 text-amber-700 dark:text-amber-300"
    };
  }
  if (normalized.includes("fail") || normalized.includes("error")) {
    return {
      label: "Письмо не отправлено",
      description:
        "Почтовый сервис не принял письмо. Можно повторить или передать ссылку вручную.",
      className: "bg-red-500/10 text-red-700 dark:text-red-300"
    };
  }
  return {
    label: "Ожидает отправки",
    description: "Сервер ещё не подтвердил доставку приглашения.",
    className: "bg-coffee-500/10 text-coffee-700"
  };
}

function StaffRow({
  member,
  branches,
  currentUserId,
  saving,
  onSave
}: {
  member: StaffMember;
  branches: Branch[];
  currentUserId: string;
  saving: boolean;
  onSave: (member: StaffMember, patch: StaffMemberPatch) => Promise<void>;
}) {
  const [name, setName] = useState(member.name);
  const [role, setRole] = useState<StaffAssignableRole>(
    member.role === "barista" ? "barista" : "manager"
  );
  const [selectedBranchId, setSelectedBranchId] = useState(
    member.branchId ?? ""
  );
  const [isActive, setIsActive] = useState(member.isActive);

  useEffect(() => {
    setName(member.name);
    setRole(member.role === "barista" ? "barista" : "manager");
    setSelectedBranchId(member.branchId ?? "");
    setIsActive(member.isActive);
  }, [member]);

  const isOwner = member.role === "owner";
  const isCurrentUser = member.id === currentUserId;
  const normalizedName = name.trim();
  const nextBranchId = role === "barista" ? selectedBranchId : "";
  const isDirty =
    normalizedName !== member.name ||
    (!isOwner && role !== member.role) ||
    (!isOwner && nextBranchId !== (member.branchId ?? "")) ||
    (!isOwner && isActive !== member.isActive);
  const canSave =
    Array.from(normalizedName).length >= 2 &&
    (isOwner || role !== "barista" || selectedBranchId.length > 0);

  async function save() {
    if (!canSave || !isDirty || saving) return;
    const patch: StaffMemberPatch = { name: normalizedName };
    if (!isOwner) {
      patch.role = role;
      patch.branchId = role === "barista" ? selectedBranchId : null;
      patch.isActive = isActive;
    }
    await onSave(member, patch);
  }

  return (
    <tr className="border-b border-coffee-900/5 align-top last:border-0">
      <td className="min-w-56 px-5 py-4">
        <label className="sr-only" htmlFor={`staff-name-${member.id}`}>
          Имя сотрудника {member.email}
        </label>
        <input
          id={`staff-name-${member.id}`}
          value={name}
          onChange={(event) => setName(event.target.value)}
          maxLength={120}
          disabled={saving}
          className="input font-semibold"
        />
        <p className="mt-1.5 break-all text-xs text-coffee-500">
          {member.email}
          {isCurrentUser && (
            <span className="ml-2 rounded-full bg-accent/10 px-2 py-0.5 font-semibold text-accent">
              вы
            </span>
          )}
        </p>
      </td>

      <td className="min-w-44 px-5 py-4">
        {isOwner ? (
          <div className="flex h-10 items-center gap-2 rounded-xl bg-accent/10 px-3 text-sm font-semibold text-accent">
            <ShieldCheck className="h-4 w-4" />
            Владелец
          </div>
        ) : (
          <select
            value={role}
            onChange={(event) => {
              const nextRole = event.target.value as StaffAssignableRole;
              setRole(nextRole);
              if (
                nextRole === "barista" &&
                !selectedBranchId &&
                branches[0]
              ) {
                setSelectedBranchId(branches[0].id);
              }
            }}
            disabled={saving}
            className="input"
            aria-label={`Роль ${member.name}`}
          >
            {INVITABLE_ROLES.map((value) => (
              <option key={value} value={value}>
                {ROLE_LABELS[value]}
              </option>
            ))}
          </select>
        )}
      </td>

      <td className="min-w-52 px-5 py-4">
        {!isOwner && role === "barista" ? (
          <>
            <select
              value={selectedBranchId}
              onChange={(event) => setSelectedBranchId(event.target.value)}
              disabled={saving || branches.length === 0}
              className="input"
              aria-label={`Филиал ${member.name}`}
            >
              <option value="">Выберите филиал</option>
              {branches.map((branch) => (
                <option key={branch.id} value={branch.id}>
                  {branch.name}
                </option>
              ))}
            </select>
            {!selectedBranchId && (
              <p className="mt-1 text-xs font-medium text-red-600">
                Для бариста филиал обязателен
              </p>
            )}
          </>
        ) : (
          <span className="inline-flex h-10 items-center text-sm text-coffee-500">
            Все филиалы
          </span>
        )}
      </td>

      <td className="min-w-40 px-5 py-4">
        {isOwner ? (
          <span className="inline-flex h-10 items-center gap-2 text-sm font-medium text-emerald-700 dark:text-emerald-300">
            <span className="h-2.5 w-2.5 rounded-full bg-emerald-500" />
            Защищён
          </span>
        ) : (
          <label className="inline-flex h-10 cursor-pointer items-center gap-2.5 text-sm font-medium text-coffee-700">
            <input
              type="checkbox"
              checked={isActive}
              onChange={(event) => setIsActive(event.target.checked)}
              disabled={saving}
              className="h-4 w-4 accent-[rgb(var(--accent))]"
            />
            {isActive ? "Активен" : "Отключён"}
          </label>
        )}
      </td>

      <td className="min-w-44 px-5 py-4">
        <p className="text-sm text-coffee-700">
          {formatDateTime(member.createdAt)}
        </p>
        <p className="mt-1 text-xs text-coffee-500">
          Обновлён {formatDateTime(member.updatedAt)}
        </p>
      </td>

      <td className="px-5 py-4 text-right">
        <button
          type="button"
          onClick={() => void save()}
          disabled={!isDirty || !canSave || saving}
          className="focus-ring inline-flex h-10 items-center gap-2 rounded-full bg-accent px-4 text-sm font-semibold text-white transition hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-40"
        >
          {saving ? (
            <RefreshCw className="h-4 w-4 animate-spin" />
          ) : (
            <Save className="h-4 w-4" />
          )}
          Сохранить
        </button>
      </td>
    </tr>
  );
}

function StaffContent() {
  const { company, branches } = useCompanyStore();
  const { user, companyId } = useSession();
  const [staff, setStaff] = useState<StaffMember[]>([]);
  const [invitations, setInvitations] = useState<StaffInvitation[]>([]);
  const [inviteLinks, setInviteLinks] = useState<Record<string, string>>({});
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);
  const [busyKey, setBusyKey] = useState<string | null>(null);

  const [email, setEmail] = useState("");
  const [role, setRole] = useState<StaffAssignableRole>("barista");
  const [inviteBranchId, setInviteBranchId] = useState(branches[0]?.id ?? "");
  const [inviteError, setInviteError] = useState<string | null>(null);

  const load = useCallback(async () => {
    if (!companyId) return;
    setLoading(true);
    setLoadError(null);
    try {
      const [nextStaff, nextInvitations] = await Promise.all([
        apiFetchStaff(companyId),
        apiFetchStaffInvitations(companyId)
      ]);
      setStaff(nextStaff);
      setInvitations(nextInvitations);
    } catch (error) {
      setLoadError(describeApiError(error));
    } finally {
      setLoading(false);
    }
  }, [companyId]);

  useEffect(() => {
    void load();
  }, [load]);

  useEffect(() => {
    if (!inviteBranchId && branches[0]) {
      setInviteBranchId(branches[0].id);
    }
  }, [branches, inviteBranchId]);

  const orderedStaff = useMemo(
    () =>
      [...staff].sort((left, right) => {
        if (left.role === "owner" && right.role !== "owner") return -1;
        if (right.role === "owner" && left.role !== "owner") return 1;
        if (left.isActive !== right.isActive) return left.isActive ? -1 : 1;
        return left.name.localeCompare(right.name, "ru");
      }),
    [staff]
  );

  const pendingInvitations = useMemo(
    () =>
      invitations
        .filter((invitation) => invitation.status.toLowerCase() === "pending")
        .sort(
          (left, right) =>
            Date.parse(right.createdAt) - Date.parse(left.createdAt)
        ),
    [invitations]
  );

  function clearMessages() {
    setActionError(null);
    setSuccessMessage(null);
  }

  function replaceInvitation(next: StaffInvitation, previousId?: string) {
    setInvitations((current) => [
      next,
      ...current.filter(
        (item) => item.id !== next.id && item.id !== previousId
      )
    ]);
  }

  async function handleInvite(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!companyId || busyKey) return;
    clearMessages();
    setInviteError(null);

    const normalizedEmail = email.trim().toLowerCase();
    if (!EMAIL_PATTERN.test(normalizedEmail)) {
      setInviteError(
        "Введите корректный рабочий email, например name+staff@example.com"
      );
      return;
    }
    if (role === "barista" && !inviteBranchId) {
      setInviteError("Выберите филиал для бариста");
      return;
    }

    setBusyKey("invite:create");
    try {
      const result = await apiCreateStaffInvitation(companyId, {
        email: normalizedEmail,
        role,
        ...(role === "barista" ? { branchId: inviteBranchId } : {})
      });
      replaceInvitation(result.invitation);
      if (result.inviteUrl) {
        setInviteLinks((current) => ({
          ...current,
          [result.invitation.id]: result.inviteUrl
        }));
      }
      const delivery = deliveryPresentation(
        result.invitation.deliveryStatus
      );
      setSuccessMessage(
        result.invitation.deliveryStatus.toLowerCase().includes("sent")
          ? `Приглашение отправлено на ${result.invitation.email}`
          : `${delivery.label}. Ссылка готова для копирования.`
      );
      setEmail("");
      setRole("barista");
      setInviteBranchId(branches[0]?.id ?? "");
    } catch (error) {
      setInviteError(describeApiError(error));
    } finally {
      setBusyKey(null);
    }
  }

  async function handleStaffSave(
    member: StaffMember,
    patch: StaffMemberPatch
  ) {
    if (!companyId || busyKey) return;
    clearMessages();
    setBusyKey(`staff:${member.id}`);
    try {
      const saved = await apiPatchStaffMember(companyId, member.id, patch);
      setStaff((current) =>
        current.map((item) => (item.id === saved.id ? saved : item))
      );
      setSuccessMessage(`Данные ${saved.name} сохранены`);
    } catch (error) {
      setActionError(describeApiError(error));
    } finally {
      setBusyKey(null);
    }
  }

  async function handleResend(invitation: StaffInvitation) {
    if (!companyId || busyKey) return;
    clearMessages();
    setBusyKey(`invite:resend:${invitation.id}`);
    try {
      const result = await apiResendStaffInvitation(
        companyId,
        invitation.id
      );
      replaceInvitation(result.invitation, invitation.id);
      setInviteLinks((current) => {
        const next = { ...current };
        delete next[invitation.id];
        if (result.inviteUrl) next[result.invitation.id] = result.inviteUrl;
        return next;
      });
      const sent = result.invitation.deliveryStatus
        .toLowerCase()
        .includes("sent");
      setSuccessMessage(
        sent
          ? `Новое письмо отправлено на ${result.invitation.email}`
          : "Новая безопасная ссылка создана. Скопируйте её и отправьте сотруднику."
      );
    } catch (error) {
      setActionError(describeApiError(error));
    } finally {
      setBusyKey(null);
    }
  }

  async function handleRevoke(invitation: StaffInvitation) {
    if (!companyId || busyKey) return;
    if (
      !window.confirm(
        `Отозвать приглашение для ${invitation.email}? Ссылка перестанет работать.`
      )
    ) {
      return;
    }
    clearMessages();
    setBusyKey(`invite:revoke:${invitation.id}`);
    try {
      await apiRevokeStaffInvitation(companyId, invitation.id);
      setInvitations((current) =>
        current.filter((item) => item.id !== invitation.id)
      );
      setInviteLinks((current) => {
        const next = { ...current };
        delete next[invitation.id];
        return next;
      });
      setSuccessMessage(`Приглашение для ${invitation.email} отозвано`);
    } catch (error) {
      setActionError(describeApiError(error));
    } finally {
      setBusyKey(null);
    }
  }

  async function copyInvite(invitation: StaffInvitation) {
    const inviteUrl = inviteLinks[invitation.id];
    if (!inviteUrl) return;
    clearMessages();
    try {
      await navigator.clipboard.writeText(inviteUrl);
      setSuccessMessage(
        `Ссылка для ${invitation.email} скопирована. Передайте её только этому сотруднику.`
      );
    } catch {
      window.prompt("Скопируйте ссылку приглашения", inviteUrl);
    }
  }

  if (loading) {
    return (
      <div>
        <h1 className="text-2xl">Сотрудники</h1>
        <div className="surface mt-6 flex min-h-48 items-center justify-center">
          <p className="flex items-center gap-2 text-sm text-coffee-500">
            <RefreshCw className="h-4 w-4 animate-spin" />
            Загружаем сотрудников…
          </p>
        </div>
      </div>
    );
  }

  if (loadError) {
    return (
      <div>
        <h1 className="text-2xl">Сотрудники</h1>
        <div className="surface mt-6 max-w-2xl px-6 py-8 text-center">
          <p role="alert" className="text-sm font-medium text-red-600">
            {loadError}
          </p>
          <button
            type="button"
            onClick={() => void load()}
            className="focus-ring mt-4 inline-flex h-10 items-center gap-2 rounded-full bg-accent px-5 text-sm font-semibold text-white"
          >
            <RefreshCw className="h-4 w-4" />
            Повторить
          </button>
        </div>
      </div>
    );
  }

  return (
    <div>
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <h1 className="text-2xl">Сотрудники</h1>
          <p className="mt-1 text-sm text-coffee-500">
            Доступы {company.name}: {staff.length}{" "}
            {pluralRu(staff.length, "сотрудник", "сотрудника", "сотрудников")}
          </p>
        </div>
        <button
          type="button"
          onClick={() => void load()}
          disabled={busyKey !== null}
          className="focus-ring inline-flex h-10 items-center gap-2 rounded-full border border-coffee-900/15 px-4 text-sm font-medium text-coffee-700 transition hover:border-accent hover:text-accent disabled:opacity-50"
        >
          <RefreshCw className="h-4 w-4" />
          Обновить
        </button>
      </div>

      <section className="mt-6 grid gap-3 lg:grid-cols-3">
        <div className="surface px-5 py-4">
          <p className="flex items-center gap-2 font-semibold text-coffee-900">
            <ShieldCheck className="h-4 w-4 text-accent" />
            Владелец
          </p>
          <p className="mt-1 text-sm leading-relaxed text-coffee-500">
            Все разделы, настройки и управление сотрудниками. Эту роль нельзя
            выдать обычным приглашением.
          </p>
        </div>
        <div className="surface px-5 py-4">
          <p className="flex items-center gap-2 font-semibold text-coffee-900">
            <UsersRound className="h-4 w-4 text-accent" />
            Менеджер
          </p>
          <p className="mt-1 text-sm leading-relaxed text-coffee-500">
            Заказы всех филиалов, меню, новости, акции и операционное
            управление — без доступа к сотрудникам и настройкам владельца.
          </p>
        </div>
        <div className="surface px-5 py-4">
          <p className="flex items-center gap-2 font-semibold text-coffee-900">
            <UsersRound className="h-4 w-4 text-accent" />
            Бариста
          </p>
          <p className="mt-1 text-sm leading-relaxed text-coffee-500">
            Только очередь назначенного филиала и смена статуса его заказов.
          </p>
        </div>
      </section>

      {(actionError || successMessage) && (
        <div
          role={actionError ? "alert" : "status"}
          className={cn(
            "mt-4 flex items-start gap-2 rounded-xl px-4 py-3 text-sm font-medium",
            actionError
              ? "bg-red-500/10 text-red-700 dark:text-red-300"
              : "bg-emerald-500/10 text-emerald-700 dark:text-emerald-300"
          )}
        >
          {actionError ? (
            <Mail className="mt-0.5 h-4 w-4 shrink-0" />
          ) : (
            <Check className="mt-0.5 h-4 w-4 shrink-0" />
          )}
          {actionError ?? successMessage}
        </div>
      )}

      <section className="surface mt-6 px-5 py-5">
        <div className="flex items-start gap-3">
          <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-accent/10 text-accent">
            <UserPlus className="h-5 w-5" />
          </span>
          <div>
            <h2 className="text-lg">Пригласить сотрудника</h2>
            <p className="mt-0.5 text-sm text-coffee-500">
              Сотрудник получит одноразовую ссылку и сам установит имя и пароль.
              Пароль владельцу не показывается.
            </p>
          </div>
        </div>

        <form
          onSubmit={handleInvite}
          className="mt-5 grid items-end gap-3 lg:grid-cols-[minmax(240px,1fr)_180px_minmax(220px,1fr)_auto]"
          noValidate
        >
          <label>
            <span className="mb-1.5 block text-sm font-medium text-coffee-700">
              Email
            </span>
            <input
              type="email"
              inputMode="email"
              autoCapitalize="none"
              autoCorrect="off"
              autoComplete="off"
              value={email}
              onChange={(event) => {
                setEmail(event.target.value);
                setInviteError(null);
              }}
              placeholder="employee@example.com"
              className="input"
            />
          </label>

          <label>
            <span className="mb-1.5 block text-sm font-medium text-coffee-700">
              Роль
            </span>
            <select
              value={role}
              onChange={(event) => {
                setRole(event.target.value as StaffAssignableRole);
                setInviteError(null);
              }}
              className="input"
            >
              {INVITABLE_ROLES.map((value) => (
                <option key={value} value={value}>
                  {ROLE_LABELS[value]}
                </option>
              ))}
            </select>
          </label>

          <label>
            <span className="mb-1.5 block text-sm font-medium text-coffee-700">
              Филиал {role === "manager" && "(не требуется)"}
            </span>
            <select
              value={role === "barista" ? inviteBranchId : ""}
              onChange={(event) => {
                setInviteBranchId(event.target.value);
                setInviteError(null);
              }}
              disabled={role === "manager" || branches.length === 0}
              className="input disabled:cursor-not-allowed disabled:opacity-50"
            >
              <option value="">
                {branches.length === 0
                  ? "Сначала создайте филиал"
                  : "Выберите филиал"}
              </option>
              {branches.map((branch) => (
                <option key={branch.id} value={branch.id}>
                  {branch.name}
                </option>
              ))}
            </select>
          </label>

          <button
            type="submit"
            disabled={
              busyKey !== null ||
              !email.trim() ||
              (role === "barista" && !inviteBranchId)
            }
            className="focus-ring inline-flex h-11 items-center justify-center gap-2 rounded-full bg-accent px-5 text-sm font-semibold text-white transition hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-50"
          >
            {busyKey === "invite:create" ? (
              <RefreshCw className="h-4 w-4 animate-spin" />
            ) : (
              <Mail className="h-4 w-4" />
            )}
            Пригласить
          </button>

          {inviteError && (
            <p
              role="alert"
              className="text-sm font-medium text-red-600 lg:col-span-4"
            >
              {inviteError}
            </p>
          )}
        </form>
      </section>

      <section className="mt-8">
        <div className="flex items-end justify-between gap-4">
          <div>
            <h2 className="text-xl">Ожидают регистрации</h2>
            <p className="mt-1 text-sm text-coffee-500">
              Каждая ссылка одноразовая и действует до указанного времени.
            </p>
          </div>
          <span className="rounded-full bg-accent/10 px-3 py-1 text-sm font-semibold text-accent">
            {pendingInvitations.length}
          </span>
        </div>

        {pendingInvitations.length === 0 ? (
          <div className="surface mt-4 flex min-h-32 items-center justify-center px-5 py-8 text-center">
            <p className="text-sm text-coffee-500">
              Активных приглашений пока нет.
            </p>
          </div>
        ) : (
          <div className="mt-4 grid gap-3 xl:grid-cols-2">
            {pendingInvitations.map((invitation) => {
              const delivery = deliveryPresentation(
                invitation.deliveryStatus
              );
              const inviteUrl = inviteLinks[invitation.id];
              const invitationBusy =
                busyKey === `invite:resend:${invitation.id}` ||
                busyKey === `invite:revoke:${invitation.id}`;
              return (
                <article
                  key={invitation.id}
                  className="surface px-5 py-5"
                >
                  <div className="flex flex-wrap items-start justify-between gap-3">
                    <div className="min-w-0">
                      <p className="break-all font-semibold text-coffee-900">
                        {invitation.email}
                      </p>
                      <p className="mt-1 text-sm text-coffee-500">
                        {ROLE_LABELS[invitation.role]}
                        {invitation.role === "barista" &&
                          ` · ${branchName(branches, invitation.branchId)}`}
                      </p>
                    </div>
                    <span
                      className={cn(
                        "rounded-full px-3 py-1 text-xs font-semibold",
                        delivery.className
                      )}
                    >
                      {delivery.label}
                    </span>
                  </div>

                  <p className="mt-3 text-sm leading-relaxed text-coffee-500">
                    {delivery.description}
                  </p>
                  <p className="mt-3 flex items-center gap-1.5 text-xs text-coffee-500">
                    <Clock3 className="h-3.5 w-3.5" />
                    Действует до {formatDateTime(invitation.expiresAt)}
                  </p>

                  <div className="mt-4 flex flex-wrap gap-2">
                    {inviteUrl && (
                      <button
                        type="button"
                        onClick={() => void copyInvite(invitation)}
                        disabled={invitationBusy}
                        className="focus-ring inline-flex h-9 items-center gap-2 rounded-full bg-accent px-4 text-sm font-semibold text-white disabled:opacity-50"
                      >
                        <Clipboard className="h-4 w-4" />
                        Скопировать ссылку
                      </button>
                    )}
                    <button
                      type="button"
                      onClick={() => void handleResend(invitation)}
                      disabled={invitationBusy || busyKey !== null}
                      className="focus-ring inline-flex h-9 items-center gap-2 rounded-full border border-coffee-900/15 px-4 text-sm font-medium text-coffee-700 transition hover:border-accent hover:text-accent disabled:opacity-50"
                    >
                      {busyKey === `invite:resend:${invitation.id}` ? (
                        <RefreshCw className="h-4 w-4 animate-spin" />
                      ) : (
                        <RotateCw className="h-4 w-4" />
                      )}
                      {inviteUrl ? "Отправить заново" : "Создать новую ссылку"}
                    </button>
                    <button
                      type="button"
                      onClick={() => void handleRevoke(invitation)}
                      disabled={invitationBusy || busyKey !== null}
                      className="focus-ring inline-flex h-9 items-center gap-2 rounded-full border border-red-500/30 px-4 text-sm font-medium text-red-600 transition hover:bg-red-500/10 disabled:opacity-50"
                    >
                      <Trash2 className="h-4 w-4" />
                      Отозвать
                    </button>
                  </div>
                </article>
              );
            })}
          </div>
        )}
      </section>

      <section className="mt-8">
        <div>
          <h2 className="text-xl">Команда</h2>
          <p className="mt-1 text-sm text-coffee-500">
            Email подтверждён приглашением. Для смены email создайте новое
            приглашение.
          </p>
        </div>

        <div className="surface mt-4 overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full text-left text-sm">
              <thead>
                <tr className="border-b border-coffee-900/10 text-xs uppercase tracking-wide text-coffee-500">
                  <th className="px-5 py-3 font-semibold">Сотрудник</th>
                  <th className="px-5 py-3 font-semibold">Роль</th>
                  <th className="px-5 py-3 font-semibold">Филиал</th>
                  <th className="px-5 py-3 font-semibold">Доступ</th>
                  <th className="px-5 py-3 font-semibold">Создан</th>
                  <th className="px-5 py-3 text-right font-semibold">
                    Действие
                  </th>
                </tr>
              </thead>
              <tbody>
                {orderedStaff.map((member) => (
                  <StaffRow
                    key={member.id}
                    member={member}
                    branches={branches}
                    currentUserId={user?.id ?? ""}
                    saving={busyKey === `staff:${member.id}`}
                    onSave={handleStaffSave}
                  />
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </section>
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
