"use client";

import { RecurringRegistry } from "@/components/recurring-registry";
import { RoleGate } from "@/components/role-gate";

export default function RecurringOrdersPage() {
  return (
    <RoleGate allow={["owner", "manager"]}>
      <RecurringRegistry />
    </RoleGate>
  );
}
