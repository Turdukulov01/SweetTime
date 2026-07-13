import random
import string
from datetime import datetime, timedelta, timezone

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from passlib.context import CryptContext
from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app.models import RoleCode, User

password_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")


def hash_password(password: str) -> str:
    return password_context.hash(password)


def verify_password(password: str, hashed_password: str) -> bool:
    return password_context.verify(password, hashed_password)


def create_token(user: User, token_type: str, expires_delta: timedelta) -> str:
    expires_at = datetime.now(timezone.utc) + expires_delta
    payload = {"sub": user.id, "type": token_type, "exp": expires_at}
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def create_access_token(user: User) -> str:
    return create_token(user, "access", timedelta(minutes=settings.access_token_minutes))


def create_refresh_token(user: User) -> str:
    return create_token(user, "refresh", timedelta(days=settings.refresh_token_days))


def random_referral_code(prefix: str = "SWT") -> str:
    suffix = "".join(random.choice(string.ascii_uppercase + string.digits) for _ in range(6))
    return f"{prefix}-{suffix}"


def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)) -> User:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, settings.jwt_secret, algorithms=[settings.jwt_algorithm])
        user_id = payload.get("sub")
        if not user_id:
            raise credentials_exception
    except JWTError as exc:
        raise credentials_exception from exc
    user = db.get(User, user_id)
    if not user or not user.is_active:
        raise credentials_exception
    return user


def require_staff(user: User = Depends(get_current_user)) -> User:
    if user.role_code not in {RoleCode.owner.value, RoleCode.branch_manager.value, RoleCode.staff.value}:
        raise HTTPException(status_code=403, detail="Staff permissions required")
    return user


def require_owner(user: User = Depends(get_current_user)) -> User:
    if user.role_code != RoleCode.owner.value:
        raise HTTPException(status_code=403, detail="Owner permissions required")
    return user


def find_user_by_identifier(db: Session, company_id: str, identifier: str) -> User | None:
    return db.scalar(
        select(User).where(
            User.company_id == company_id,
            User.is_active.is_(True),
            or_(User.email == identifier, User.phone == identifier),
        )
    )
