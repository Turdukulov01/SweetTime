"""One-shot production bootstrap for the SweetTime storefront and first owner."""

import os
from pathlib import Path

from .database import SessionLocal
from .seed import ProductionBootstrapError, bootstrap_production_sweettime


def _required_env(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise ProductionBootstrapError(f"{name} is required")
    return value


def _read_owner_password() -> str:
    password_file = Path(_required_env("BOOTSTRAP_OWNER_PASSWORD_FILE"))
    try:
        return password_file.read_text(encoding="utf-8").rstrip("\r\n")
    except OSError as exc:
        raise ProductionBootstrapError(
            f"Cannot read BOOTSTRAP_OWNER_PASSWORD_FILE: {password_file}"
        ) from exc


def main() -> int:
    email = _required_env("BOOTSTRAP_OWNER_EMAIL")
    name = _required_env("BOOTSTRAP_OWNER_NAME")
    password = _read_owner_password()

    with SessionLocal() as db:
        bootstrap_production_sweettime(
            db,
            owner_email=email,
            owner_name=name,
            owner_password=password,
        )
    print(f"Production SweetTime bootstrap completed for owner {email.strip().lower()}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ProductionBootstrapError as exc:
        raise SystemExit(f"Bootstrap refused: {exc}") from exc
