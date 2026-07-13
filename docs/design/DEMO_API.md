# SweetTime Demo API — контракт моста «приложение ↔ админка»

Дата: 2026-07-12. Назначение: живой демо-backend (FastAPI + SQLite), соединяющий Flutter-приложение
и мультитенантную админку. Форма API повторяет будущий боевой backend (Postgres добавится позже,
контракт не изменится). Порт: **8000**. CORS: открыт для localhost (админка :3020, Flutter web).

## Принципы

- Мультитенантность: все ручки под `/api/companies/{companyId}/...`; данные жёстко фильтруются
  по companyId. Авторизации в демо нет (добавится JWT на боевом этапе).
- Хранилище: SQLite `backend/demo.db`, SQLAlchemy 2 typed (`Mapped`/`mapped_column`).
  При первом старте — сид: компании `sweettime` и `coffeego` с теми же данными, что в моках
  админки (`admin/lib/data.ts`) и приложения (`lib/shared/demo_data.dart`).
- Деньги — целые сомы. Статусы заказов: `new | preparing | ready | done | cancelled`.
- Запуск: `py -m uvicorn app_demo.main:app --port 8000` из папки `backend/` (зависимости —
  `py -m pip install fastapi uvicorn sqlalchemy`).

## Ручки

| Метод | Путь | Тело/ответ |
|---|---|---|
| GET | `/api/companies/{cid}/config` | Company: `{id, name, appName, accentColor, currency, loyalty:{earnRate, maxSpendShare, expiryMonths}, referral:{invitedBonus, inviterBonus}}` |
| PATCH | `/api/companies/{cid}/config` | частичное обновление тех же полей (админка: брендинг + лояльность) |
| GET | `/api/companies/{cid}/products` | `[{id, name, category, description, price, color, sizes:[{name, priceDelta}], toppings:[{name, priceDelta}], availableBranchIds, active, isNew, isBestSeller}]` |
| POST | `/api/companies/{cid}/products` | создать товар (админка) |
| PATCH | `/api/companies/{cid}/products/{id}` | частичное обновление (админка: тумблер active, правки) |
| GET | `/api/companies/{cid}/branches` | `[{id, name, address, hours, phone, isOpen}]` |
| POST | `/api/companies/{cid}/branches` | создание филиала: `{name, address, hours, phone, isOpen?}` |
| PATCH | `/api/companies/{cid}/branches/{id}` | частичное обновление |
| GET | `/api/companies/{cid}/orders` | список заказов, новые сверху: `[{id, number, customerName, branchId, type: pickup|scheduled|qr, status, readyTime, items:[{productName, size, quantity, total}], total, paymentMethod: mock|cash|qr, pointsUsed, pointsEarned, createdAt}]` |
| POST | `/api/companies/{cid}/orders` | **из приложения**: `{customerName, branchId, type, readyTime, items:[...], total, paymentMethod?, pointsUsed}` → ответ: заказ с `id`, `number` (SW-1050+), `status: preparing`, `pointsEarned` (5% от total, серверный расчёт); `paymentMethod` optional, default `mock` |
| PATCH | `/api/companies/{cid}/orders/{id}/status` | `{status}` — валидные переходы вперёд + cancel (админка) |
| GET | `/health` | `{status: "ok"}` |

## Потребители

- **Админка**: при `NEXT_PUBLIC_API_URL=http://localhost:8000` сторы инициализируются из API,
  мутации шлют PATCH/POST; заказы поллятся каждые 5 сек. Без переменной — прежние моки.
- **Flutter**: при старте пробует API (таймаут 2 сек): конфиг компании (акцент, имя, лояльность),
  товары, филиалы; чекаут делает POST заказа. При недоступном API — молча работает на DemoData
  (APK остаётся автономным). companyId приложения: `sweettime`.

## Демо-сценарий («вау-эффект»)

1. В приложении оформляется заказ → через ≤5 сек он появляется в очереди админки «Новые/Готовится».
2. Бариста в админке двигает статус → (в демо приложение статус не поллит; добавим на боевом этапе).
3. В админке owner меняет акцентный цвет/название → перезапуск/обновление приложения — оно в новом бренде.
