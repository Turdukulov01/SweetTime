"use client";

import { ShieldAlert } from "lucide-react";
import { RoleGate } from "@/components/role-gate";

function StaffUnavailable() {
  return (
    <div>
      <h1 className="text-2xl">Сотрудники</h1>
      <p className="mt-1 text-sm text-coffee-500">
        Управление доступом будет подключено отдельным защищённым этапом.
      </p>

      <div className="surface mt-6 flex max-w-2xl items-start gap-3 border-amber-500/40 bg-amber-50 px-5 py-4 dark:bg-amber-500/10">
        <ShieldAlert className="mt-0.5 h-5 w-5 shrink-0 text-amber-600" />
        <div>
          <p className="font-semibold text-coffee-900">
            Раздел пока недоступен
          </p>
          <p className="mt-1 text-sm leading-relaxed text-coffee-700">
            Серверные операции приглашения, смены роли, назначения филиала и
            удаления сотрудников ещё не реализованы. Админка не показывает
            демо-сотрудников и не создаёт несохраняемые изменения.
          </p>
        </div>
      </div>
    </div>
  );
}

export default function StaffPage() {
  return (
    <RoleGate allow={["owner"]}>
      <StaffUnavailable />
    </RoleGate>
  );
}
