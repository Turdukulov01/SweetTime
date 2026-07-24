# Деплой — постоянные заказы v1 (генерация + расписание + пуши)

Ревизия: **`5df3ddb`** (версия `1.0.4+5`). Изменения: backend (генерация заказов из
подписок + планировщик + FCM-инфраструктура), admin (расписание постоянных), Flutter
(редактирование подписки + метка). **Две миграции:** `e5a7c3d19b60`, `f7b9d4e82c15`.

Порядок как в `ROLLOUT-2026-07-24.md` (архив + guard `.env` + бэкап перед миграцией).

## 1. С Windows
```powershell
cd C:\Users\user\flutter_project\sweettime\sweettime
scp .\dist\sweettime-5df3ddb.tar.gz               ranex@81.88.192.41:/tmp/
# APK (после сборки): dist\SweetTime-Android-test-2026-07-24c.apk → /tmp/SweetTime.apk
```

## 2. На сервере (SSH)
```bash
set -euo pipefail
archive=/tmp/sweettime-5df3ddb.tar.gz
expected_sha=d0decd85be33d2d37a61b4a2849c5f6c51f9efe3ce769074c4442cd59c28c139
echo "$expected_sha  $archive" | sha256sum -c -

cd /srv/projects/sweetime/deploy/production
# 0) Текущая ревизия БД — ждём d8e42c1a7f90 (голова прошлого этапа)
docker compose --env-file .env run --rm migrate alembic -c /app/api/alembic.ini current
# 1) Бэкап ДО миграции
./backup-production.sh
# 2) Код (guard .env)
env_before="$(sha256sum .env | awk '{print $1}')"
tar -xzf "$archive" -C /srv/projects/sweetime
env_after="$(sha256sum .env | awk '{print $1}')"
test "$env_before" = "$env_after" || { echo "ОШИБКА: .env изменился"; exit 1; }
# 3) Сборка + миграция (применит e5a7c3d19b60 → f7b9d4e82c15)
docker compose --env-file .env config --quiet
docker compose --env-file .env build backend admin
docker compose --env-file .env run --rm migrate
# 4) Пересоздать сервисы
docker compose --env-file .env up -d --force-recreate --no-deps --wait --wait-timeout 180 backend admin
docker compose --env-file .env up -d --force-recreate --no-deps nginx
docker compose --env-file .env ps
# 5) Smoke
base=https://lnp-corporation.duckdns.org
for p in /ready /login /api/companies/sweettime/config; do
  printf '%s -> %s\n' "$p" "$(curl -sS -o /dev/null -w '%{http_code}' "$base$p")"
done
# 6) APK
sudo install -m 644 /tmp/SweetTime.apk /srv/sweetime/downloads/SweetTime.apk
```

Планировщик стартует автоматически внутри backend (asyncio-таск в lifespan). Он раз в
60с генерирует scheduled-заказы на сегодня и активирует их за 10 минут до времени выдачи.
Без Firebase пуши — честный no-op, всё остальное работает.

---

# Включение push-уведомлений (FCM) — действия владельца в Firebase

Пуши работают только после этих шагов. До них активация заказов работает без уведомлений.

## A. Firebase Console (один раз)
1. https://console.firebase.google.com → **Add project**. Можно **добавить в существующий
   Google Cloud проект** `project-1c2e438d-1859-42b3-bc5` (тот же, что для Google Sign-In) —
   тогда всё в одном месте. Или отдельный проект — тоже ок.
2. В проекте: **Add app → Android**.
   - Android package name: **`kg.sweettime.app`** (точно так).
   - Скачать **`google-services.json`**.
3. **Project settings → Service accounts → Generate new private key** → скачать JSON
   (это секрет сервера для отправки пушей). Назовём `fcm-service-account.json`.

## B. Сервер (секрет отправки)
```bash
install -d -m 700 /srv/sweetime/secrets
# загрузить fcm-service-account.json в /srv/sweetime/secrets/ (scp), затем:
chmod 640 /srv/sweetime/secrets/fcm-service-account.json
```
В `deploy/production/.env` добавить:
```dotenv
FCM_SERVICE_ACCOUNT_HOST_FILE=/srv/sweetime/secrets/fcm-service-account.json
```
Поднять backend с FCM-overlay:
```bash
cd /srv/projects/sweetime/deploy/production
docker compose --env-file .env -f docker-compose.yml -f docker-compose.fcm.yml \
  up -d --force-recreate --no-deps backend
```

## C. Flutter-клиент (отдельная задача разработки, ~полдня)
Требует `google-services.json` из шага A2, затем в приложение добавляется
`firebase_core` + `firebase_messaging`: запрос разрешения на уведомления (Android 13+),
получение device-токена и его отправка на `PUT /customer/me/push-tokens`, удаление на
выходе (`POST /customer/me/push-tokens/remove`). Backend-эндпоинты уже готовы.
Пока этот клиентский слой не собран, токенов нет и отправлять некуда — но сервер к этому
полностью готов (fail-closed).

## Приёмка после деплоя
- Создать подписку в приложении на ближайшее время (напр. +15 минут) → в админке в
  «Расписание постоянных» появляется строка; за 10 минут до времени заказ уходит в «Новые»
  с бейджем «Постоянный · к HH:MM»; в истории клиента — метка «Постоянный заказ».
- Проверить редактирование: изменить состав/время/пожелания → «Сохранить изменения» (без
  повторной оплаты), срок подписки не сдвигается, цена дня пересчитывается.
