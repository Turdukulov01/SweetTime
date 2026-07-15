"""Механизмы безопасности боевого backend.

В S1 используется только хэширование паролей (для сида demo-стаффа). JWT-логика
(create/verify токенов, зависимости get_current_*) добавляется на этапе S2 —
секрет/алгоритм уже читаются из настроек (`api.config.settings`).

Донор: `backend/app/security.py` (passlib + bcrypt).
"""

from passlib.context import CryptContext

password_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def hash_password(password: str) -> str:
    return password_context.hash(password)


def verify_password(password: str, hashed_password: str) -> bool:
    return password_context.verify(password, hashed_password)
