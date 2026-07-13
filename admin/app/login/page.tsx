"use client";

import { useRouter } from "next/navigation";
import { useEffect, useState, type FormEvent } from "react";
import { KeyRound, LogIn } from "lucide-react";
import { getDemoAccounts } from "@/lib/data";
import { login, useSession } from "@/lib/session";

const demoAccounts = getDemoAccounts();

export default function LoginPage() {
  const router = useRouter();
  const { status } = useSession();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);

  // Уже вошли — сразу в панель
  useEffect(() => {
    if (status === "authenticated") router.replace("/");
  }, [status, router]);

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const session = login(email, password);
    if (!session) {
      setError("Неверный email или пароль. Пароль всех демо-аккаунтов: demo");
      return;
    }
    setError(null);
    router.replace("/");
  }

  function fillDemo(demoEmail: string) {
    setEmail(demoEmail);
    setPassword("demo");
    setError(null);
  }

  return (
    <main className="flex min-h-screen items-center justify-center px-4 py-10">
      <div className="w-full max-w-md">
        <div className="mb-6 text-center">
          <h1 className="text-3xl">SweetTime Admin</h1>
          <p className="mt-1 text-sm text-coffee-500">
            Единая панель управления для кофеен
          </p>
        </div>

        <div className="surface px-6 py-6">
          <form onSubmit={handleSubmit} className="space-y-4" noValidate>
            <div>
              <label
                htmlFor="email"
                className="mb-1.5 block text-sm font-medium text-coffee-700"
              >
                Email
              </label>
              <input
                id="email"
                type="email"
                autoComplete="username"
                required
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="owner@sweettime.kg"
                className="input"
              />
            </div>

            <div>
              <label
                htmlFor="password"
                className="mb-1.5 block text-sm font-medium text-coffee-700"
              >
                Пароль
              </label>
              <input
                id="password"
                type="password"
                autoComplete="current-password"
                required
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="demo"
                className="input"
              />
            </div>

            {error && (
              <p role="alert" className="text-sm font-medium text-red-600">
                {error}
              </p>
            )}

            <button
              type="submit"
              className="focus-ring flex h-11 w-full items-center justify-center gap-2 rounded-full bg-candy-500 text-sm font-semibold text-white transition hover:bg-candy-700"
            >
              <LogIn className="h-4 w-4" />
              Войти
            </button>
          </form>
        </div>

        <div className="surface mt-4 px-6 py-4">
          <p className="flex items-center gap-1.5 text-xs font-semibold uppercase tracking-wide text-coffee-500">
            <KeyRound className="h-3.5 w-3.5" />
            Демо-аккаунты (пароль: demo)
          </p>
          <ul className="mt-2 space-y-1">
            {demoAccounts.map((account) => (
              <li key={account.email}>
                <button
                  type="button"
                  onClick={() => fillDemo(account.email)}
                  className="focus-ring w-full rounded-lg px-2 py-1.5 text-left text-sm text-coffee-700 transition hover:bg-candy-50"
                >
                  <span className="font-medium text-coffee-900">
                    {account.email}
                  </span>{" "}
                  — {account.roleLabel}, {account.companyName}
                </button>
              </li>
            ))}
          </ul>
        </div>
      </div>
    </main>
  );
}
