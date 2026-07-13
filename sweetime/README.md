# 🧋 Sweetime Bubble Tea & Coffee — Frontend

> Production-ready интернет-магазин авторского бабл-ти и кофе.  
> Next.js 15 · React 19 · TypeScript · Tailwind CSS · Framer Motion

---

## Стек

| Слой | Технология |
|---|---|
| Framework | Next.js 15 (App Router) |
| UI Library | React 19 |
| Типизация | TypeScript 5 (strict) |
| Стили | Tailwind CSS 3 с кастомным design-token-слоем |
| Анимации | Framer Motion 11 |
| Иконки | Lucide React |
| Графики | Recharts |
| Шрифты | Fraunces (display) · Plus Jakarta Sans (body) · IBM Plex Mono |
| Линтер | ESLint + Next core-web-vitals |
| Форматтер | Prettier + prettier-plugin-tailwindcss |
| CI/CD | GitHub Actions |
| Контейнер | Docker (multi-stage, standalone) |
| Деплой | Vercel |

---

## Структура проекта

```
src/
├── app/                   # App Router — страницы и layouts
│   ├── page.tsx           # Главная страница
│   ├── catalog/           # Каталог с фильтрами и пагинацией
│   ├── product/[slug]/    # Страница товара
│   ├── cart/              # Корзина
│   ├── checkout/          # Оформление заказа
│   ├── auth/              # Авторизация (login / register / recover)
│   ├── profile/           # Личный кабинет
│   ├── admin/             # Админ-панель
│   ├── sitemap.ts         # Динамический sitemap.xml
│   └── robots.ts          # robots.txt
├── components/
│   ├── layout/            # Header, Footer, MobileMenu
│   ├── ui/                # Design system: Button, Input, Card, Badge, Skeleton, PearlLoader
│   ├── home/              # HeroBanner, Promotions, Categories, ProductRail, Reviews
│   ├── catalog/           # ProductCard, SearchBar, Filters, SortDropdown, Pagination
│   ├── product/           # Gallery, Customizer, ReviewsList, Recommendations
│   ├── cart/              # CartItemRow, CartDrawer, PromoCodeInput, OrderSummary
│   ├── checkout/          # DeliveryOptions, PaymentForm
│   ├── auth/              # AuthShell, PhoneSmsForm, SocialButtons
│   ├── profile/           # BonusBalance, OrderHistory, FavoriteDrinks, AddressBook, SettingsForm
│   └── admin/             # Sidebar, DashboardStats, AnalyticsCharts, ProductsTable, OrdersTable, UsersTable, CouponsTable
├── context/               # CartContext, AuthContext, ThemeContext
├── hooks/                 # useDebounce, useClickOutside
├── lib/
│   ├── api.ts             # API-слой (заглушка → реальный backend)
│   ├── mock-data.ts       # Тестовые данные: товары, категории, отзывы, заказы
│   ├── constants.ts       # Конфигурация: размеры, топпинги, сайт
│   └── utils.ts           # cn(), formatPrice(), formatDate(), …
└── types/
    └── index.ts           # Все TypeScript-типы домена
```

---

## Быстрый старт

### Требования

- **Node.js 20+** и **npm 10+**
- (Опционально) **Docker 24+**

### Установка

```bash
git clone https://github.com/your-org/sweetime-frontend.git
cd sweetime-frontend

# Установить зависимости
npm install

# Скопировать переменные окружения
cp .env.example .env.local

# Запустить dev-сервер
npm run dev
```

Откройте [http://localhost:3000](http://localhost:3000).

### Полезные команды

```bash
npm run dev        # Режим разработки с hot-reload
npm run build      # Production build
npm run start      # Запустить production build локально
npm run lint       # ESLint
npm run format     # Prettier
npx tsc --noEmit   # Проверка типов
```

---

## Дизайн-система

### Палитра

| Токен | HEX | Применение |
|---|---|---|
| `cream` | `#FDF6ED` | Фоновый цвет |
| `pink-300` | `#F6B8C4` | Акцентный, hover-состояния |
| `berry-500` | `#5B2A3A` | Заголовки, основные кнопки |
| `mint-300` | `#9BDCC8` | Бейджи «новинка», доставка |
| `caramel-300` | `#DDB878` | Рейтинг, акции |
| `ink` | `#4A3B3F` | Основной текст |
| `ink-muted` | `#8A7A7E` | Вторичный текст |

### Шрифты

- **Fraunces** — display-шрифт (заголовки, логотип)
- **Plus Jakarta Sans** — UI-шрифт (тело, кнопки, формы)
- **IBM Plex Mono** — цифры (цены, ID заказов)

### Фирменный элемент

Пузырьки тапиоки (`<PearlLoader />`) — анимация «жемчужины поднимаются в стакане».  
Используется как глобальный лоадер и визуальный мотив в hero-баннере.

---

## Подключение реального backend API (Этап 13)

Все запросы к данным изолированы в `src/lib/api.ts`.  
Каждая функция возвращает `Promise` и работает с мок-данными.  
Для подключения реального API достаточно заменить тело функции на `fetch`:

```ts
// До (mock):
export async function fetchProducts(query) {
  return delay({ items: filtered, total, page, perPage });
}

// После (real API):
export async function fetchProducts(query) {
  const params = new URLSearchParams({ ...query });
  const res = await fetch(`${API_BASE}/products?${params}`, { next: { revalidate: 60 } });
  if (!res.ok) throw new Error('fetchProducts failed');
  return res.json();
}
```

Компоненты при этом не меняются.

---

## Docker

```bash
# Собрать образ
docker build -t sweetime-frontend .

# Запустить
docker run -p 3000:3000 sweetime-frontend

# Или через Compose
docker compose up
```

---

## Деплой на Vercel

1. Импортировать репозиторий на [vercel.com](https://vercel.com)
2. В настройках проекта добавить переменную окружения `NEXT_PUBLIC_API_BASE_URL`
3. Каждый push в `main` деплоится автоматически

Файл `vercel.json` содержит конфигурацию региона (Fra1), security-заголовков и редиректов.

---

## CI/CD

GitHub Actions (`.github/workflows/ci.yml`) запускает:

1. **lint** — ESLint + TypeScript type-check на каждый PR
2. **build** — `next build` на каждый PR
3. **docker** — сборка и пуш Docker-образа в GHCR при мердже в `main`

---

## Roadmap (Этап 13 — Backend)

- [ ] Подключить реальный REST API (FastAPI / NestJS / Supabase)
- [ ] NextAuth.js для OAuth Google + Apple + SMS через Firebase/Twilio
- [ ] Stripe или CloudPayments для оплаты
- [ ] Real-time статус заказа через WebSocket / Server-Sent Events
- [ ] Push-уведомления (Web Push API)
- [ ] A/B тестирование баннеров (Vercel Edge Config)
- [ ] Internationalisation (ky, ru, en)

---

## Лицензия

MIT © Sweetime 2026
