"""SweetTime боевой backend (FastAPI + PostgreSQL + Alembic).

Пакет `backend/api` — каноническая боевая основа. Контракт совпадает с
демо-мостом `backend/app_demo` (`/api/companies/{cid}/...`, camelCase,
локализованные поля `{ru,ky,en}`), но хранилище — PostgreSQL, схема ведётся
через Alembic, а модели пользователей (AdminUser/Customer) готовятся под
JWT-авторизацию (добавляется на этапе S2).

Демо-мост `backend/app_demo` и черновик `backend/app` не затрагиваются.
"""
