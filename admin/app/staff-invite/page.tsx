"use client";

import { useEffect, useRef, useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import {
  Building2,
  CheckCircle2,
  Eye,
  EyeOff,
  KeyRound,
  RefreshCw,
  ShieldCheck,
  TriangleAlert,
  UserRound
} from "lucide-react";
import {
  ApiError,
  apiAcceptStaffInvitation,
  apiPreviewStaffInvitation,
  describeApiError
} from "@/lib/api";
import { writeStoredSession } from "@/lib/auth-storage";
import { ROLE_LABELS } from "@/lib/labels";
import type { StaffInvitationPreview } from "@/lib/types";
import { formatDateTime } from "@/lib/utils";

type LoadState = "loading" | "ready" | "error";

function inviteErrorMessage(error: unknown): string {
  if (error instanceof ApiError) {
    if (error.status === 404) {
      return "Приглашение не найдено или уже было отозвано.";
    }
    if (error.status === 409) {
      return "Это приглашение уже использовано. Войдите со своей почтой и паролем.";
    }
    if (error.status === 410) {
      return "Срок действия приглашения истёк. Попросите владельца отправить новое.";
    }
  }
  return describeApiError(error);
}

export default function StaffInvitePage() {
  const router = useRouter();
  const tokenRef = useRef("");
  const [token, setToken] = useState("");
  const [preview, setPreview] = useState<StaffInvitationPreview | null>(null);
  const [loadState, setLoadState] = useState<LoadState>("loading");
  const [loadError, setLoadError] = useState("");
  const [name, setName] = useState("");
  const [password, setPassword] = useState("");
  const [passwordConfirm, setPasswordConfirm] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    let rawToken = tokenRef.current;
    if (!rawToken) {
      const hash = window.location.hash.startsWith("#")
        ? window.location.hash.slice(1)
        : window.location.hash;
      rawToken = new URLSearchParams(hash).get("token")?.trim() ?? "";
      tokenRef.current = rawToken;

      // Fragment не отправляется серверу, а после чтения убирается ещё и из
      // адресной строки/истории браузера. Сам bearer-токен остаётся только в памяти.
      if (rawToken) {
        window.history.replaceState(
          null,
          "",
          `${window.location.pathname}${window.location.search}`
        );
      }
    }

    if (!rawToken) {
      setLoadError(
        "В ссылке нет токена приглашения. Откройте исходную ссылку из письма или сообщения владельца."
      );
      setLoadState("error");
      return;
    }

    setToken(rawToken);
    setLoadState("loading");
    apiPreviewStaffInvitation(rawToken)
      .then((result) => {
        setPreview(result);
        setLoadState("ready");
      })
      .catch((error: unknown) => {
        setLoadError(inviteErrorMessage(error));
        setLoadState("error");
      });
  }, []);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!preview || !token || submitting) return;
    setFormError(null);

    const normalizedName = name.trim();
    if (normalizedName.length < 2) {
      setFormError("Укажите имя, которое увидит владелец и команда.");
      return;
    }

    const passwordLength = Array.from(password).length;
    const passwordBytes = new TextEncoder().encode(password).length;
    if (passwordLength < 12) {
      setFormError("Пароль должен содержать не менее 12 символов.");
      return;
    }
    if (passwordBytes > 72) {
      setFormError("Пароль слишком длинный: максимум 72 байта.");
      return;
    }
    if (!Array.from(password).some((character) => /\p{L}/u.test(character))) {
      setFormError("Добавьте в пароль хотя бы одну букву.");
      return;
    }
    if (!Array.from(password).some((character) => /\p{N}/u.test(character))) {
      setFormError("Добавьте в пароль хотя бы одну цифру.");
      return;
    }
    if (/[\r\n\t\u0000]/u.test(password)) {
      setFormError("Пароль содержит недопустимый управляющий символ.");
      return;
    }
    if (password !== passwordConfirm) {
      setFormError("Пароли не совпадают.");
      return;
    }

    setSubmitting(true);
    try {
      const session = await apiAcceptStaffInvitation({
        token,
        name: normalizedName,
        password
      });
      writeStoredSession(session);
      router.replace("/");
    } catch (error) {
      setFormError(inviteErrorMessage(error));
      setSubmitting(false);
    }
  }

  return (
    <main className="flex min-h-screen items-center justify-center px-4 py-10">
      <div className="w-full max-w-lg">
        <div className="mb-6 text-center">
          <span className="mx-auto flex h-14 w-14 items-center justify-center rounded-2xl bg-candy-500 text-white shadow-soft">
            <ShieldCheck className="h-7 w-7" />
          </span>
          <h1 className="mt-4 text-3xl">Приглашение в команду</h1>
          <p className="mt-1 text-sm text-coffee-500">
            Создайте личный пароль. Владелец компании его не увидит.
          </p>
        </div>

        {loadState === "loading" && (
          <div className="surface flex min-h-56 items-center justify-center px-6 py-8">
            <p className="flex items-center gap-2 text-sm text-coffee-500">
              <RefreshCw className="h-4 w-4 animate-spin" />
              Проверяем безопасную ссылку…
            </p>
          </div>
        )}

        {loadState === "error" && (
          <div className="surface px-6 py-8 text-center">
            <span className="mx-auto flex h-12 w-12 items-center justify-center rounded-full bg-red-500/10 text-red-600">
              <TriangleAlert className="h-5 w-5" />
            </span>
            <h2 className="mt-4 text-xl">Ссылка не работает</h2>
            <p role="alert" className="mt-2 text-sm leading-relaxed text-coffee-500">
              {loadError}
            </p>
            <button
              type="button"
              onClick={() => router.replace("/login")}
              className="focus-ring mt-5 inline-flex h-10 items-center rounded-full border border-coffee-900/15 px-5 text-sm font-medium text-coffee-700 transition hover:border-candy-500 hover:text-candy-500"
            >
              Перейти ко входу
            </button>
          </div>
        )}

        {loadState === "ready" && preview && (
          <div className="surface overflow-hidden">
            <div className="border-b border-coffee-900/10 bg-candy-500/5 px-6 py-5">
              <p className="flex items-center gap-2 font-semibold text-coffee-900">
                <Building2 className="h-5 w-5 text-candy-500" />
                {preview.companyName}
              </p>
              <div className="mt-3 grid gap-2 text-sm text-coffee-500 sm:grid-cols-2">
                <p>
                  Роль:{" "}
                  <span className="font-semibold text-coffee-900">
                    {ROLE_LABELS[preview.role]}
                  </span>
                </p>
                {preview.branchName && (
                  <p>
                    Филиал:{" "}
                    <span className="font-semibold text-coffee-900">
                      {preview.branchName}
                    </span>
                  </p>
                )}
                <p className="sm:col-span-2">
                  Ссылка действует до {formatDateTime(preview.expiresAt)}
                </p>
              </div>
            </div>

            <form
              onSubmit={handleSubmit}
              className="space-y-4 px-6 py-6"
              noValidate
            >
              <div>
                <label className="mb-1.5 block text-sm font-medium text-coffee-700">
                  Рабочая почта
                </label>
                <div className="flex h-11 items-center gap-2 rounded-xl border border-coffee-900/10 bg-coffee-900/5 px-3.5 text-sm text-coffee-700">
                  <CheckCircle2 className="h-4 w-4 shrink-0 text-emerald-600" />
                  <span className="min-w-0 truncate">{preview.email}</span>
                </div>
                <p className="mt-1.5 text-xs text-coffee-500">
                  Почта закреплена приглашением и не может быть заменена в этой
                  форме.
                </p>
              </div>

              <div>
                <label
                  htmlFor="invite-name"
                  className="mb-1.5 block text-sm font-medium text-coffee-700"
                >
                  Ваше имя
                </label>
                <div className="relative">
                  <UserRound className="pointer-events-none absolute left-3.5 top-3.5 h-4 w-4 text-coffee-500" />
                  <input
                    id="invite-name"
                    type="text"
                    autoComplete="name"
                    value={name}
                    onChange={(event) => {
                      setName(event.target.value);
                      setFormError(null);
                    }}
                    maxLength={120}
                    placeholder="Например, Алина"
                    className="input pl-10"
                  />
                </div>
              </div>

              <div>
                <label
                  htmlFor="invite-password"
                  className="mb-1.5 block text-sm font-medium text-coffee-700"
                >
                  Новый пароль
                </label>
                <div className="relative">
                  <KeyRound className="pointer-events-none absolute left-3.5 top-3.5 h-4 w-4 text-coffee-500" />
                  <input
                    id="invite-password"
                    type={showPassword ? "text" : "password"}
                    autoComplete="new-password"
                    value={password}
                    onChange={(event) => {
                      setPassword(event.target.value);
                      setFormError(null);
                    }}
                    placeholder="Минимум 12 символов"
                    className="input px-10"
                  />
                  <button
                    type="button"
                    onClick={() => setShowPassword((value) => !value)}
                    aria-label={
                      showPassword ? "Скрыть пароль" : "Показать пароль"
                    }
                    className="focus-ring absolute right-2 top-2 flex h-7 w-7 items-center justify-center rounded-lg text-coffee-500 hover:text-candy-500"
                  >
                    {showPassword ? (
                      <EyeOff className="h-4 w-4" />
                    ) : (
                      <Eye className="h-4 w-4" />
                    )}
                  </button>
                </div>
              </div>

              <div>
                <label
                  htmlFor="invite-password-confirm"
                  className="mb-1.5 block text-sm font-medium text-coffee-700"
                >
                  Повторите пароль
                </label>
                <input
                  id="invite-password-confirm"
                  type={showPassword ? "text" : "password"}
                  autoComplete="new-password"
                  value={passwordConfirm}
                  onChange={(event) => {
                    setPasswordConfirm(event.target.value);
                    setFormError(null);
                  }}
                  placeholder="Ещё раз тот же пароль"
                  className="input"
                />
              </div>

              {formError && (
                <p role="alert" className="text-sm font-medium text-red-600">
                  {formError}
                </p>
              )}

              <button
                type="submit"
                disabled={
                  submitting ||
                  !name.trim() ||
                  !password ||
                  !passwordConfirm
                }
                className="focus-ring flex h-11 w-full items-center justify-center gap-2 rounded-full bg-candy-500 text-sm font-semibold text-white transition hover:bg-candy-700 disabled:cursor-not-allowed disabled:opacity-50"
              >
                {submitting ? (
                  <RefreshCw className="h-4 w-4 animate-spin" />
                ) : (
                  <ShieldCheck className="h-4 w-4" />
                )}
                {submitting ? "Создаём аккаунт…" : "Принять приглашение"}
              </button>
            </form>
          </div>
        )}
      </div>
    </main>
  );
}
