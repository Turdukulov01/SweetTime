"use client";

// Клиентское редактируемое состояние компании: брендинг + лояльность,
// товары, филиалы, сотрудники, «постоянные заказы».
//
// Источник данных: при заданном NEXT_PUBLIC_API_URL стор инициализируется
// из demo-API (config + products + branches), мутации шлют PATCH/POST и
// применяют ответ сервера. При недоступном API — graceful fallback на моки
// (console.warn). Сотрудники и recurring всегда на моках — их нет в API.
//
// Провайдер монтируется в shell с key={companyId}: при перелогине состояние
// пересоздаётся, данные чужой компании не «протекают».

import {
  createContext,
  createElement,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode
} from "react";
import {
  apiCreateBranch,
  apiCreateNews,
  apiCreateProduct,
  apiCreatePromotion,
  apiDeleteNews,
  apiDeletePromotion,
  apiEnabled,
  apiFetchBranches,
  apiFetchConfig,
  apiFetchNews,
  apiFetchProducts,
  apiFetchPromotions,
  apiPatchBranch,
  apiPatchConfig,
  apiPatchNews,
  apiPatchProduct,
  apiPatchPromotion
} from "@/lib/api";
import { getCompanyData } from "@/lib/data";
import type {
  AdminUser,
  Branch,
  Company,
  NewsStory,
  Product,
  Promotion,
  RecurringOrder
} from "@/lib/types";

interface CompanyState {
  company: Company;
  products: Product[];
  branches: Branch[];
  users: AdminUser[];
  recurring: RecurringOrder[];
  news: NewsStory[];
  promotions: Promotion[];
}

interface CompanyStoreValue extends CompanyState {
  /** Брендинг, лояльность, рефералка — частичное обновление компании */
  updateCompany: (patch: Partial<Omit<Company, "id">>) => void;
  addProduct: (product: Product) => void;
  updateProduct: (productId: string, patch: Partial<Omit<Product, "id">>) => void;
  addBranch: (branch: Branch) => void;
  updateBranch: (branchId: string, patch: Partial<Omit<Branch, "id">>) => void;
  addUser: (user: AdminUser) => void;
  updateUser: (userId: string, patch: Partial<Omit<AdminUser, "id">>) => void;
  removeUser: (userId: string) => void;
  addNews: (news: NewsStory) => void;
  updateNews: (newsId: string, patch: Partial<Omit<NewsStory, "id">>) => void;
  removeNews: (newsId: string) => void;
  addPromotion: (promotion: Promotion) => void;
  updatePromotion: (
    promotionId: string,
    patch: Partial<Omit<Promotion, "id">>
  ) => void;
  removePromotion: (promotionId: string) => void;
}

const CompanyStoreContext = createContext<CompanyStoreValue | null>(null);

const warnApi = (action: string, error: unknown) =>
  console.warn(
    `[admin] API: не удалось ${action} — изменение только локально.`,
    error
  );

export function CompanyStoreProvider({
  companyId,
  children
}: {
  companyId: string;
  children: ReactNode;
}) {
  // Мгновенный сид из моков, чтобы UI не ждал сеть; API заменит данные ниже
  const [state, setState] = useState<CompanyState | null>(() => {
    const data = getCompanyData(companyId);
    if (!data) return null;
    return {
      company: data.company,
      products: data.products,
      branches: data.branches,
      users: data.users,
      recurring: data.recurring,
      news: data.news,
      promotions: data.promotions
    };
  });

  // true после успешной загрузки из API — тогда мутации шлют PATCH/POST
  const apiModeRef = useRef(false);

  // Дебаунс PATCH /config: брендинг правится посимвольно
  const configPatchRef = useRef<Partial<Omit<Company, "id">>>({});
  const configTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    if (!apiEnabled) return;
    let cancelled = false;

    Promise.all([
      apiFetchConfig(companyId),
      apiFetchProducts(companyId),
      apiFetchBranches(companyId),
      apiFetchNews(companyId),
      apiFetchPromotions(companyId)
    ])
      .then(([company, products, branches, news, promotions]) => {
        if (cancelled) return;
        apiModeRef.current = true;
        setState((prev) =>
          prev
            ? { ...prev, company, products, branches, news, promotions }
            : prev
        );
      })
      .catch((error) => {
        console.warn(
          "[admin] API недоступен, работаем на мок-данных:",
          error instanceof Error ? error.message : error
        );
      });

    return () => {
      cancelled = true;
      if (configTimerRef.current) clearTimeout(configTimerRef.current);
    };
  }, [companyId]);

  const applyCompany = useCallback((company: Company) => {
    setState((prev) => (prev ? { ...prev, company } : prev));
  }, []);

  const updateCompany = useCallback(
    (patch: Partial<Omit<Company, "id">>) => {
      setState((prev) =>
        prev ? { ...prev, company: { ...prev.company, ...patch } } : prev
      );
      if (!apiModeRef.current) return;

      // копим патч и шлём одним PATCH после паузы ввода
      configPatchRef.current = { ...configPatchRef.current, ...patch };
      if (configTimerRef.current) clearTimeout(configTimerRef.current);
      configTimerRef.current = setTimeout(() => {
        const merged = configPatchRef.current;
        configPatchRef.current = {};
        apiPatchConfig(companyId, merged)
          .then(applyCompany)
          .catch((error) => warnApi("сохранить настройки компании", error));
      }, 400);
    },
    [companyId, applyCompany]
  );

  const addProduct = useCallback(
    (product: Product) => {
      setState((prev) =>
        prev ? { ...prev, products: [...prev.products, product] } : prev
      );
      if (!apiModeRef.current) return;

      const { id: tempId, companyId: _cid, ...payload } = product;
      apiCreateProduct(companyId, payload)
        .then((created) => {
          // заменяем временный товар серверным (с настоящим id)
          setState((prev) =>
            prev
              ? {
                  ...prev,
                  products: prev.products.map((p) =>
                    p.id === tempId ? created : p
                  )
                }
              : prev
          );
        })
        .catch((error) => warnApi("создать товар", error));
    },
    [companyId]
  );

  const updateProduct = useCallback(
    (productId: string, patch: Partial<Omit<Product, "id">>) => {
      setState((prev) =>
        prev
          ? {
              ...prev,
              products: prev.products.map((p) =>
                p.id === productId ? { ...p, ...patch } : p
              )
            }
          : prev
      );
      if (!apiModeRef.current) return;

      apiPatchProduct(companyId, productId, patch)
        .then((updated) => {
          setState((prev) =>
            prev
              ? {
                  ...prev,
                  products: prev.products.map((p) =>
                    p.id === productId ? updated : p
                  )
                }
              : prev
          );
        })
        .catch((error) => warnApi("сохранить товар", error));
    },
    [companyId]
  );

  const updateBranch = useCallback(
    (branchId: string, patch: Partial<Omit<Branch, "id">>) => {
      setState((prev) =>
        prev
          ? {
              ...prev,
              branches: prev.branches.map((b) =>
                b.id === branchId ? { ...b, ...patch } : b
              )
            }
          : prev
      );
      if (!apiModeRef.current) return;

      apiPatchBranch(companyId, branchId, patch)
        .then((updated) => {
          setState((prev) =>
            prev
              ? {
                  ...prev,
                  branches: prev.branches.map((b) =>
                    b.id === branchId ? updated : b
                  )
                }
              : prev
          );
        })
        .catch((error) => warnApi("сохранить филиал", error));
    },
    [companyId]
  );

  const addBranch = useCallback(
    (branch: Branch) => {
      setState((prev) =>
        prev ? { ...prev, branches: [...prev.branches, branch] } : prev
      );
      if (!apiModeRef.current) return;

      const { id: tempId, companyId: _cid, ...payload } = branch;
      apiCreateBranch(companyId, payload)
        .then((created) => {
          setState((prev) =>
            prev
              ? {
                  ...prev,
                  branches: prev.branches.map((b) =>
                    b.id === tempId ? created : b
                  )
                }
              : prev
          );
        })
        .catch((error) => {
          // Создание не подтвердилось сервером: убираем временную карточку,
          // чтобы UI не показывал несуществующий после перезагрузки филиал.
          setState((prev) =>
            prev
              ? {
                  ...prev,
                  branches: prev.branches.filter((b) => b.id !== tempId)
                }
              : prev
          );
          console.warn("[admin] API: не удалось создать филиал, изменение отменено.", error);
        });
    },
    [companyId]
  );

  // Сотрудники — только моки (в demo-API их нет)
  const addUser = useCallback((user: AdminUser) => {
    setState((prev) =>
      prev ? { ...prev, users: [...prev.users, user] } : prev
    );
  }, []);

  const updateUser = useCallback(
    (userId: string, patch: Partial<Omit<AdminUser, "id">>) => {
      setState((prev) =>
        prev
          ? {
              ...prev,
              users: prev.users.map((u) =>
                u.id === userId ? { ...u, ...patch } : u
              )
            }
          : prev
      );
    },
    []
  );

  const removeUser = useCallback((userId: string) => {
    setState((prev) =>
      prev
        ? { ...prev, users: prev.users.filter((u) => u.id !== userId) }
        : prev
    );
  }, []);

  // ----- Новости-сторис -----

  const sortNews = (list: NewsStory[]) =>
    [...list].sort((a, b) => a.sortOrder - b.sortOrder);

  const addNews = useCallback(
    (news: NewsStory) => {
      setState((prev) =>
        prev ? { ...prev, news: sortNews([...prev.news, news]) } : prev
      );
      if (!apiModeRef.current) return;

      const { id: tempId, companyId: _cid, ...payload } = news;
      apiCreateNews(companyId, payload)
        .then((created) => {
          setState((prev) =>
            prev
              ? {
                  ...prev,
                  news: sortNews(
                    prev.news.map((n) => (n.id === tempId ? created : n))
                  )
                }
              : prev
          );
        })
        .catch((error) => {
          // Создание не подтвердилось сервером — убираем временную сторис
          setState((prev) =>
            prev
              ? { ...prev, news: prev.news.filter((n) => n.id !== tempId) }
              : prev
          );
          console.warn(
            "[admin] API: не удалось создать новость, изменение отменено.",
            error
          );
        });
    },
    [companyId]
  );

  const updateNews = useCallback(
    (newsId: string, patch: Partial<Omit<NewsStory, "id">>) => {
      setState((prev) =>
        prev
          ? {
              ...prev,
              news: sortNews(
                prev.news.map((n) => (n.id === newsId ? { ...n, ...patch } : n))
              )
            }
          : prev
      );
      if (!apiModeRef.current) return;

      apiPatchNews(companyId, newsId, patch)
        .then((updated) => {
          setState((prev) =>
            prev
              ? {
                  ...prev,
                  news: sortNews(
                    prev.news.map((n) => (n.id === newsId ? updated : n))
                  )
                }
              : prev
          );
        })
        .catch((error) => warnApi("сохранить новость", error));
    },
    [companyId]
  );

  const removeNews = useCallback(
    (newsId: string) => {
      let removed: NewsStory | undefined;
      setState((prev) => {
        if (!prev) return prev;
        removed = prev.news.find((n) => n.id === newsId);
        return { ...prev, news: prev.news.filter((n) => n.id !== newsId) };
      });
      if (!apiModeRef.current) return;

      apiDeleteNews(companyId, newsId).catch((error) => {
        // Откат: возвращаем удалённую сторис на место
        setState((prev) =>
          prev && removed
            ? { ...prev, news: sortNews([...prev.news, removed]) }
            : prev
        );
        console.warn(
          "[admin] API: не удалось удалить новость, изменение отменено.",
          error
        );
      });
    },
    [companyId]
  );

  // ----- Сезонные акции -----

  const sortPromotions = (list: Promotion[]) =>
    [...list].sort((a, b) => a.sortOrder - b.sortOrder);

  const addPromotion = useCallback(
    (promotion: Promotion) => {
      setState((prev) =>
        prev
          ? {
              ...prev,
              promotions: sortPromotions([...prev.promotions, promotion])
            }
          : prev
      );
      if (!apiModeRef.current) return;

      const { id: tempId, companyId: _cid, ...payload } = promotion;
      apiCreatePromotion(companyId, payload)
        .then((created) => {
          setState((prev) =>
            prev
              ? {
                  ...prev,
                  promotions: sortPromotions(
                    prev.promotions.map((p) => (p.id === tempId ? created : p))
                  )
                }
              : prev
          );
        })
        .catch((error) => {
          setState((prev) =>
            prev
              ? {
                  ...prev,
                  promotions: prev.promotions.filter((p) => p.id !== tempId)
                }
              : prev
          );
          console.warn(
            "[admin] API: не удалось создать акцию, изменение отменено.",
            error
          );
        });
    },
    [companyId]
  );

  const updatePromotion = useCallback(
    (promotionId: string, patch: Partial<Omit<Promotion, "id">>) => {
      setState((prev) =>
        prev
          ? {
              ...prev,
              promotions: sortPromotions(
                prev.promotions.map((p) =>
                  p.id === promotionId ? { ...p, ...patch } : p
                )
              )
            }
          : prev
      );
      if (!apiModeRef.current) return;

      apiPatchPromotion(companyId, promotionId, patch)
        .then((updated) => {
          setState((prev) =>
            prev
              ? {
                  ...prev,
                  promotions: sortPromotions(
                    prev.promotions.map((p) =>
                      p.id === promotionId ? updated : p
                    )
                  )
                }
              : prev
          );
        })
        .catch((error) => warnApi("сохранить акцию", error));
    },
    [companyId]
  );

  const removePromotion = useCallback(
    (promotionId: string) => {
      let removed: Promotion | undefined;
      setState((prev) => {
        if (!prev) return prev;
        removed = prev.promotions.find((p) => p.id === promotionId);
        return {
          ...prev,
          promotions: prev.promotions.filter((p) => p.id !== promotionId)
        };
      });
      if (!apiModeRef.current) return;

      apiDeletePromotion(companyId, promotionId).catch((error) => {
        setState((prev) =>
          prev && removed
            ? { ...prev, promotions: sortPromotions([...prev.promotions, removed]) }
            : prev
        );
        console.warn(
          "[admin] API: не удалось удалить акцию, изменение отменено.",
          error
        );
      });
    },
    [companyId]
  );

  const value = useMemo<CompanyStoreValue | null>(
    () =>
      state
        ? {
            ...state,
            updateCompany,
            addProduct,
            updateProduct,
            addBranch,
            updateBranch,
            addUser,
            updateUser,
            removeUser,
            addNews,
            updateNews,
            removeNews,
            addPromotion,
            updatePromotion,
            removePromotion
          }
        : null,
    [
      state,
      updateCompany,
      addProduct,
      updateProduct,
      addBranch,
      updateBranch,
      addUser,
      updateUser,
      removeUser,
      addNews,
      updateNews,
      removeNews,
      addPromotion,
      updatePromotion,
      removePromotion
    ]
  );

  if (!value) return null;

  return createElement(CompanyStoreContext.Provider, { value }, children);
}

export function useCompanyStore(): CompanyStoreValue {
  const ctx = useContext(CompanyStoreContext);
  if (!ctx) {
    throw new Error(
      "useCompanyStore должен вызываться внутри <CompanyStoreProvider>"
    );
  }
  return ctx;
}
