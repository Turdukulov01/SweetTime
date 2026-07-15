"use client";

import { useState, type ReactNode } from "react";
import { FolderOpen, Newspaper, Sparkles } from "lucide-react";
import { CollectionsTab } from "@/components/news/collections-tab";
import { FeedTab } from "@/components/news/feed-tab";
import { StoriesTab } from "@/components/news/stories-tab";
import { RoleGate } from "@/components/role-gate";
import { useCompanyStore } from "@/lib/company-store";
import { ContentManagerProvider } from "@/lib/content-store";
import { cn } from "@/lib/utils";

type ContentTab = "stories" | "collections" | "feed";

const TABS: Array<{
  id: ContentTab;
  label: string;
  description: string;
  icon: typeof Sparkles;
}> = [
  {
    id: "stories",
    label: "Сторисы",
    description: "Главная и подборки",
    icon: Sparkles
  },
  {
    id: "collections",
    label: "Подборки",
    description: "Разделы страницы /news",
    icon: FolderOpen
  },
  {
    id: "feed",
    label: "Лента",
    description: "Постоянные публикации",
    icon: Newspaper
  }
];

function ContentPage() {
  const { company } = useCompanyStore();
  const [tab, setTab] = useState<ContentTab>("stories");

  return (
    <ContentManagerProvider companyId={company.id}>
      <div>
        <div>
          <h1 className="text-2xl">Новости и сторисы</h1>
          <p className="mt-1 max-w-3xl text-sm text-coffee-500">
            Управляйте короткими сторис, тематическими подборками и постоянной
            лентой. Все изменения появляются в приложении только после ответа
            сервера.
          </p>
        </div>

        <div
          role="tablist"
          aria-label="Разделы новостей"
          className="mt-6 grid max-w-3xl grid-cols-1 gap-2 rounded-2xl border border-coffee-900/10 bg-white/70 p-2 dark:bg-white/5 sm:grid-cols-3"
        >
          {TABS.map((item) => {
            const active = tab === item.id;
            const Icon = item.icon;
            return (
              <button
                key={item.id}
                type="button"
                role="tab"
                aria-selected={active}
                onClick={() => setTab(item.id)}
                className={cn(
                  "focus-ring flex items-center gap-3 rounded-xl px-4 py-3 text-left transition",
                  active
                    ? "bg-accent text-white shadow-sm"
                    : "text-coffee-700 hover:bg-coffee-900/5"
                )}
              >
                <Icon className="h-5 w-5 shrink-0" />
                <span>
                  <span className="block text-sm font-semibold">{item.label}</span>
                  <span
                    className={cn(
                      "block text-[11px]",
                      active ? "text-white/75" : "text-coffee-500"
                    )}
                  >
                    {item.description}
                  </span>
                </span>
              </button>
            );
          })}
        </div>

        <section role="tabpanel">
          {tab === "stories" && <StoriesTab />}
          {tab === "collections" && <CollectionsTab />}
          {tab === "feed" && <FeedTab />}
        </section>
      </div>
    </ContentManagerProvider>
  );
}

export default function NewsPage(): ReactNode {
  return (
    <RoleGate allow={["owner", "manager"]}>
      <ContentPage />
    </RoleGate>
  );
}
