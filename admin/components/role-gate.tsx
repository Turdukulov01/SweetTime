"use client";

// Страничный guard по ролям: если роль текущего пользователя не входит в
// allow, тихо уводит на доступную страницу (barista → /orders, иначе → /).
// Guard авторизации (редирект на /login) выполняет layout shell.

import { useRouter } from "next/navigation";
import { useEffect, type ReactNode } from "react";
import { useSession } from "@/lib/session";
import type { Role } from "@/lib/types";

export function RoleGate({
  allow,
  children
}: {
  allow: Role[];
  children: ReactNode;
}) {
  const router = useRouter();
  const { status, user } = useSession();
  const allowed = user !== null && allow.includes(user.role);

  useEffect(() => {
    if (status === "authenticated" && user && !allowed) {
      router.replace(user.role === "barista" ? "/orders" : "/");
    }
  }, [status, user, allowed, router]);

  if (status !== "authenticated" || !allowed) return null;

  return <>{children}</>;
}
