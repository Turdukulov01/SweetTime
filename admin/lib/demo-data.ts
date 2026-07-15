// ДЕМО-ДАННЫЕ для того, чего ПОКА НЕТ в боевом API (backend/api).
//
// Правило: боевые сущности (компания, товары, филиалы, заказы, новости, акции)
// берутся ТОЛЬКО из API и никогда не подменяются моками. Здесь остались:
//   1) сотрудники — серверных ручек управления сотрудниками ещё нет;
//   2) «постоянные заказы» — фича ещё не реализована на сервере;
//   3) подсказка со списком демо-аккаунтов на странице входа.
// Всё перечисленное помечено в интерфейсе как демо-данные.
//
// Изоляция тенантов сохраняется: наружу — только выборки по companyId.

import type { AdminUser, RecurringOrder } from "@/lib/types";

function daysFromNow(days: number): string {
  const d = new Date();
  d.setDate(d.getDate() + days);
  d.setHours(23, 59, 0, 0);
  return d.toISOString();
}

// ---------------------------------------------------------------------------
// Сотрудники (зеркало сида боевой БД — но управление ими пока локальное)
// ---------------------------------------------------------------------------

const demoStaff: AdminUser[] = [
  {
    id: "u-sw-owner",
    email: "owner@sweettime.kg",
    name: "Владелец SweetTime",
    role: "owner",
    companyId: "sweettime"
  },
  {
    id: "u-sw-manager",
    email: "manager@sweettime.kg",
    name: "Менеджер SweetTime",
    role: "manager",
    companyId: "sweettime"
  },
  {
    id: "u-sw-barista",
    email: "barista@sweettime.kg",
    name: "Бариста SweetTime",
    role: "barista",
    companyId: "sweettime",
    branchId: "b1"
  },
  {
    id: "u-cg-owner",
    email: "owner@coffeego.kg",
    name: "Владелец CoffeeGo",
    role: "owner",
    companyId: "coffeego"
  }
];

// ---------------------------------------------------------------------------
// «Постоянные заказы» — предоплаченный напиток к нужному времени
// ---------------------------------------------------------------------------

const demoRecurring: RecurringOrder[] = [
  {
    id: "r-sw-1",
    companyId: "sweettime",
    customerName: "Данияр",
    productName: "Розовая луна с молочным чаем (M)",
    readyTime: "11:00",
    branchId: "b1",
    plan: "week",
    paidUntil: daysFromNow(4),
    active: true
  },
  {
    id: "r-sw-2",
    companyId: "sweettime",
    customerName: "Айгерим",
    productName: "Колд брю ванильная роза (S)",
    readyTime: "09:30",
    branchId: "b2",
    plan: "month",
    paidUntil: daysFromNow(18),
    active: true
  },
  {
    id: "r-sw-3",
    companyId: "sweettime",
    customerName: "Мээрим",
    productName: "Матча мятное облако (M)",
    readyTime: "14:00",
    branchId: "b3",
    plan: "week",
    paidUntil: daysFromNow(-2),
    active: false
  },
  {
    id: "r-cg-1",
    companyId: "coffeego",
    customerName: "Марат",
    productName: "Капучино (M)",
    readyTime: "08:30",
    branchId: "cg-b1",
    plan: "month",
    paidUntil: daysFromNow(22),
    active: true
  }
];

// ---------------------------------------------------------------------------
// Публичный API демо-слоя (всегда скоуплен по companyId)
// ---------------------------------------------------------------------------

/** Демо-список сотрудников компании (API управления сотрудниками пока нет). */
export function getDemoStaff(companyId: string): AdminUser[] {
  return demoStaff
    .filter((u) => u.companyId === companyId)
    .map((u) => ({ ...u }));
}

/** Демо-«постоянные заказы» компании (фичи на сервере пока нет). */
export function getDemoRecurring(companyId: string): RecurringOrder[] {
  return demoRecurring
    .filter((r) => r.companyId === companyId)
    .map((r) => ({ ...r }));
}

/** Подсказка на странице входа: аккаунты из сида боевой БД (пароль demo). */
export function getDemoAccounts(): Array<{
  email: string;
  roleLabel: string;
  companyName: string;
}> {
  const roleLabels: Record<string, string> = {
    owner: "владелец",
    manager: "менеджер",
    barista: "бариста"
  };
  const companyNames: Record<string, string> = {
    sweettime: "SweetTime",
    coffeego: "CoffeeGo"
  };
  return demoStaff.map((u) => ({
    email: u.email,
    roleLabel: roleLabels[u.role] ?? u.role,
    companyName: companyNames[u.companyId] ?? u.companyId
  }));
}
