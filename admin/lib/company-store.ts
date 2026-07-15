"use client";

// Состояние компании: брендинг + лояльность, товары, филиалы, новости, акции.
//
// Источник данных — ТОЛЬКО боевой API (backend/api), скоуп по companyId из JWT.
// Мок-подмены нет: пока данные не загружены — экран загрузки, если API не
// ответил — экран ошибки с «Повторить»/«Выйти».
// Мутации шлют PATCH/POST/DELETE с Bearer-токеном и применяют ответ сервера;
// при ошибке (403 «Недостаточно прав», сеть) изменение откатывается и
// показывается тост (errorMessage → ErrorToast в shell).
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
import { DataError, DataLoading } from "@/components/data-state";
import {
  apiCreateBranch,
  apiCreateNews,
  apiCreateProduct,
  apiCreatePromotion,
  apiDeleteNews,
  apiDeletePromotion,
  apiFetchBranches,
  apiFetchConfig,
  apiFetchNews,
  apiFetchProducts,
  apiFetchPromotions,
  apiPatchBranch,
  apiPatchConfig,
  apiPatchNews,
  apiPatchProduct,
  apiPatchPromotion,
  describeApiError
} from "@/lib/api";
import { logout } from "@/lib/session";
import type {
  Branch,
  Company,
  NewsStory,
  Product,
  Promotion
} from "@/lib/types";

interface CompanyState {
  company: Company;
  products: Product[];
  branches: Branch[];
  news: NewsStory[];
  promotions: Promotion[];
}

interface CompanyStoreValue extends CompanyState {
  /** Текст последней ошибки действия (для тоста), null — нет */
  errorMessage: string | null;
  /** Брендинг, лояльность, рефералка — частичное обновление компании */
  updateCompany: (patch: Partial<Omit<Company, "id">>) => void;
  addProduct: (product: Product) => void;
  updateProduct: (productId: string, patch: Partial<Omit<Product, "id">>) => void;
  addBranch: (branch: Branch) => void;
  updateBranch: (branchId: string, patch: Partial<Omit<Branch, "id">>) => void;
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

type LoadStatus = "loading" | "ready" | "error";

export function CompanyStoreProvider({
  companyId,
  children
}: {
  companyId: string;
  children: ReactNode;
}) {
  const [state, setState] = useState<CompanyState | null>(null);
  const [loadStatus, setLoadStatus] = useState<LoadStatus>("loading");
  const [loadError, setLoadError] = useState<string>("");
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [reloadToken, setReloadToken] = useState(0);

  const errorTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Дебаунс PATCH /config: брендинг правится посимвольно
  const configPatchRef = useRef<Partial<Omit<Company, "id">>>({});
  const configTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const showError = useCallback((error: unknown) => {
    setErrorMessage(describeApiError(error));
    if (errorTimerRef.current) clearTimeout(errorTimerRef.current);
    errorTimerRef.current = setTimeout(() => setErrorMessage(null), 4000);
  }, []);

  useEffect(() => {
    let cancelled = false;
    setLoadStatus("loading");

    Promise.all([
      apiFetchConfig(companyId),
      apiFetchProducts(companyId),
      apiFetchBranches(companyId),
      apiFetchNews(companyId),
      apiFetchPromotions(companyId)
    ])
      .then(([company, products, branches, news, promotions]) => {
        if (cancelled) return;
        setState({
          company,
          products,
          branches,
          news,
          promotions
        });
        setLoadStatus("ready");
      })
      .catch((error: unknown) => {
        if (cancelled) return;
        setLoadError(describeApiError(error));
        setLoadStatus("error");
      });

    return () => {
      cancelled = true;
    };
  }, [companyId, reloadToken]);

  useEffect(
    () => () => {
      if (configTimerRef.current) clearTimeout(configTimerRef.current);
      if (errorTimerRef.current) clearTimeout(errorTimerRef.current);
    },
    []
  );

  const applyCompany = useCallback((company: Company) => {
    setState((prev) => (prev ? { ...prev, company } : prev));
  }, []);

  const updateCompany = useCallback(
    (patch: Partial<Omit<Company, "id">>) => {
      setState((prev) =>
        prev ? { ...prev, company: { ...prev.company, ...patch } } : prev
      );

      // копим патч и шлём одним PATCH после паузы ввода
      configPatchRef.current = { ...configPatchRef.current, ...patch };
      if (configTimerRef.current) clearTimeout(configTimerRef.current);
      configTimerRef.current = setTimeout(() => {
        const merged = configPatchRef.current;
        configPatchRef.current = {};
        apiPatchConfig(companyId, merged)
          .then(applyCompany)
          .catch((error: unknown) => {
            showError(error);
            // Сервер не принял правку — возвращаем серверную истину в UI
            apiFetchConfig(companyId).then(applyCompany).catch(() => undefined);
          });
      }, 400);
    },
    [companyId, applyCompany, showError]
  );

  // ----- Товары -----

  const addProduct = useCallback(
    (product: Product) => {
      setState((prev) =>
        prev ? { ...prev, products: [...prev.products, product] } : prev
      );

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
        .catch((error: unknown) => {
          // Создание не подтвердилось сервером — убираем временную карточку
          setState((prev) =>
            prev
              ? {
                  ...prev,
                  products: prev.products.filter((p) => p.id !== tempId)
                }
              : prev
          );
          showError(error);
        });
    },
    [companyId, showError]
  );

  const updateProduct = useCallback(
    (productId: string, patch: Partial<Omit<Product, "id">>) => {
      let previous: Product | undefined;
      setState((prev) => {
        if (!prev) return prev;
        previous = prev.products.find((p) => p.id === productId);
        return {
          ...prev,
          products: prev.products.map((p) =>
            p.id === productId ? { ...p, ...patch } : p
          )
        };
      });

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
        .catch((error: unknown) => {
          // Откат: сервер не сохранил — UI не должен показывать «сохранено»
          setState((prev) =>
            prev && previous
              ? {
                  ...prev,
                  products: prev.products.map((p) =>
                    p.id === productId ? (previous as Product) : p
                  )
                }
              : prev
          );
          showError(error);
        });
    },
    [companyId, showError]
  );

  // ----- Филиалы -----

  const addBranch = useCallback(
    (branch: Branch) => {
      setState((prev) =>
        prev ? { ...prev, branches: [...prev.branches, branch] } : prev
      );

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
        .catch((error: unknown) => {
          setState((prev) =>
            prev
              ? {
                  ...prev,
                  branches: prev.branches.filter((b) => b.id !== tempId)
                }
              : prev
          );
          showError(error);
        });
    },
    [companyId, showError]
  );

  const updateBranch = useCallback(
    (branchId: string, patch: Partial<Omit<Branch, "id">>) => {
      let previous: Branch | undefined;
      setState((prev) => {
        if (!prev) return prev;
        previous = prev.branches.find((b) => b.id === branchId);
        return {
          ...prev,
          branches: prev.branches.map((b) =>
            b.id === branchId ? { ...b, ...patch } : b
          )
        };
      });

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
        .catch((error: unknown) => {
          setState((prev) =>
            prev && previous
              ? {
                  ...prev,
                  branches: prev.branches.map((b) =>
                    b.id === branchId ? (previous as Branch) : b
                  )
                }
              : prev
          );
          showError(error);
        });
    },
    [companyId, showError]
  );

  // ----- Новости-сторис -----

  const sortNews = (list: NewsStory[]) =>
    [...list].sort((a, b) => a.sortOrder - b.sortOrder);

  const addNews = useCallback(
    (news: NewsStory) => {
      setState((prev) =>
        prev ? { ...prev, news: sortNews([...prev.news, news]) } : prev
      );

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
        .catch((error: unknown) => {
          // Создание не подтвердилось сервером — убираем временную сторис
          setState((prev) =>
            prev
              ? { ...prev, news: prev.news.filter((n) => n.id !== tempId) }
              : prev
          );
          showError(error);
        });
    },
    [companyId, showError]
  );

  const updateNews = useCallback(
    (newsId: string, patch: Partial<Omit<NewsStory, "id">>) => {
      let previous: NewsStory | undefined;
      setState((prev) => {
        if (!prev) return prev;
        previous = prev.news.find((n) => n.id === newsId);
        return {
          ...prev,
          news: sortNews(
            prev.news.map((n) => (n.id === newsId ? { ...n, ...patch } : n))
          )
        };
      });

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
        .catch((error: unknown) => {
          setState((prev) =>
            prev && previous
              ? {
                  ...prev,
                  news: sortNews(
                    prev.news.map((n) =>
                      n.id === newsId ? (previous as NewsStory) : n
                    )
                  )
                }
              : prev
          );
          showError(error);
        });
    },
    [companyId, showError]
  );

  const removeNews = useCallback(
    (newsId: string) => {
      let removed: NewsStory | undefined;
      setState((prev) => {
        if (!prev) return prev;
        removed = prev.news.find((n) => n.id === newsId);
        return { ...prev, news: prev.news.filter((n) => n.id !== newsId) };
      });

      apiDeleteNews(companyId, newsId).catch((error: unknown) => {
        // Откат: возвращаем удалённую сторис на место
        setState((prev) =>
          prev && removed
            ? { ...prev, news: sortNews([...prev.news, removed]) }
            : prev
        );
        showError(error);
      });
    },
    [companyId, showError]
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
        .catch((error: unknown) => {
          setState((prev) =>
            prev
              ? {
                  ...prev,
                  promotions: prev.promotions.filter((p) => p.id !== tempId)
                }
              : prev
          );
          showError(error);
        });
    },
    [companyId, showError]
  );

  const updatePromotion = useCallback(
    (promotionId: string, patch: Partial<Omit<Promotion, "id">>) => {
      let previous: Promotion | undefined;
      setState((prev) => {
        if (!prev) return prev;
        previous = prev.promotions.find((p) => p.id === promotionId);
        return {
          ...prev,
          promotions: sortPromotions(
            prev.promotions.map((p) =>
              p.id === promotionId ? { ...p, ...patch } : p
            )
          )
        };
      });

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
        .catch((error: unknown) => {
          setState((prev) =>
            prev && previous
              ? {
                  ...prev,
                  promotions: sortPromotions(
                    prev.promotions.map((p) =>
                      p.id === promotionId ? (previous as Promotion) : p
                    )
                  )
                }
              : prev
          );
          showError(error);
        });
    },
    [companyId, showError]
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

      apiDeletePromotion(companyId, promotionId).catch((error: unknown) => {
        setState((prev) =>
          prev && removed
            ? {
                ...prev,
                promotions: sortPromotions([...prev.promotions, removed])
              }
            : prev
        );
        showError(error);
      });
    },
    [companyId, showError]
  );

  const value = useMemo<CompanyStoreValue | null>(
    () =>
      state
        ? {
            ...state,
            errorMessage,
            updateCompany,
            addProduct,
            updateProduct,
            addBranch,
            updateBranch,
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
      errorMessage,
      updateCompany,
      addProduct,
      updateProduct,
      addBranch,
      updateBranch,
      addNews,
      updateNews,
      removeNews,
      addPromotion,
      updatePromotion,
      removePromotion
    ]
  );

  if (loadStatus === "error" || (loadStatus === "ready" && !value)) {
    return createElement(DataError, {
      message: loadError || "Сервер вернул пустой ответ",
      onRetry: () => setReloadToken((n) => n + 1),
      onLogout: logout
    });
  }

  if (!value) {
    return createElement(DataLoading, { message: "Загружаем данные компании…" });
  }

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
