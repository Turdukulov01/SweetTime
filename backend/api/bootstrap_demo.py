"""One-shot, tenant-safe production bootstrap for the CoffeeGo showcase."""

import os
from pathlib import Path

from .database import SessionLocal
from .seed import ProductionBootstrapError, bootstrap_production_demo_company


def _required_env(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise ProductionBootstrapError(f"{name} is required")
    return value


def _read_owner_password() -> str:
    password_file = Path(_required_env("DEMO_OWNER_PASSWORD_FILE"))
    try:
        return password_file.read_text(encoding="utf-8").rstrip("\r\n")
    except OSError as exc:
        raise ProductionBootstrapError(
            f"Cannot read DEMO_OWNER_PASSWORD_FILE: {password_file}"
        ) from exc


def main() -> int:
    email = _required_env("DEMO_OWNER_EMAIL")
    name = _required_env("DEMO_OWNER_NAME")
    password = _read_owner_password()

    with SessionLocal() as db:
        created = bootstrap_production_demo_company(
            db,
            owner_email=email,
            owner_name=name,
            owner_password=password,
        )
    outcome = (
        "created"
        if created
        else "already exists; state verified/repaired without duplicates"
    )
    print(f"Production CoffeeGo demo tenant {outcome}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ProductionBootstrapError as exc:
        raise SystemExit(f"Demo bootstrap refused: {exc}") from exc
