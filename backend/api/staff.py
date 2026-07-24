"""Tenant staff management and one-time email invitations."""

from datetime import datetime, timedelta, timezone
from hashlib import sha256
import secrets
from urllib.parse import quote
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from . import schemas
from .auth import staff_out
from .config import settings
from .database import get_db
from .deps import get_company, require_role
from .models import AdminUser, Branch, Company, StaffInvitation
from .security import create_token_pair, hash_password
from .staff_email import deliver_staff_invitation


router = APIRouter(
    prefix="/api/companies/{companyId}/staff",
    tags=["staff"],
)
public_router = APIRouter(
    prefix="/api/auth/staff/invitations",
    tags=["staff"],
)
require_owner = require_role("owner")


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


def _as_utc(value: datetime) -> datetime:
    # SQLite drops timezone metadata in unit tests; persisted values are UTC.
    if value.tzinfo is None or value.utcoffset() is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def _token_hash(raw_token: str) -> str:
    return sha256(raw_token.encode("utf-8")).hexdigest()


def _invite_url(raw_token: str) -> str:
    return (
        f"{settings.staff_invite_public_url}/staff-invite"
        f"#token={quote(raw_token, safe='')}"
    )


def _invitation_status(
    invitation: StaffInvitation,
) -> schemas.StaffInvitationStatus:
    if invitation.accepted_at is not None:
        return "accepted"
    if invitation.revoked_at is not None:
        return "revoked"
    if _as_utc(invitation.expires_at) <= _utc_now():
        return "expired"
    return "pending"


def _invitation_out(
    invitation: StaffInvitation,
) -> schemas.StaffInvitationOut:
    return schemas.StaffInvitationOut(
        id=invitation.id,
        companyId=invitation.company_id,
        email=invitation.email,
        role=invitation.role,
        branchId=invitation.branch_id,
        status=_invitation_status(invitation),
        deliveryStatus=invitation.delivery_status,
        expiresAt=invitation.expires_at,
        createdAt=invitation.created_at,
        sentAt=invitation.sent_at,
        acceptedAt=invitation.accepted_at,
    )


def _company_branch(
    db: Session,
    *,
    company_id: str,
    role: str,
    branch_id: str | None,
) -> Branch | None:
    if role == "manager":
        if branch_id is not None:
            raise HTTPException(
                status_code=422,
                detail="A manager cannot be assigned to one branch",
            )
        return None
    if not branch_id:
        raise HTTPException(
            status_code=422,
            detail="branchId is required for a barista",
        )
    branch = db.get(Branch, branch_id)
    if branch is None or branch.company_id != company_id:
        raise HTTPException(status_code=404, detail="Branch not found")
    return branch


def _ensure_invitation_usable(invitation: StaffInvitation) -> None:
    state = _invitation_status(invitation)
    if state == "expired":
        raise HTTPException(
            status_code=status.HTTP_410_GONE,
            detail="Invitation has expired",
        )
    if state != "pending":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Invitation is already {state}",
        )


def _find_invitation_by_token(
    db: Session,
    raw_token: str,
    *,
    for_update: bool = False,
) -> StaffInvitation:
    query = select(StaffInvitation).where(
        StaffInvitation.token_hash == _token_hash(raw_token)
    )
    if for_update:
        query = query.with_for_update()
    invitation = db.scalar(query)
    if invitation is None:
        raise HTTPException(status_code=404, detail="Invitation not found")
    _ensure_invitation_usable(invitation)
    return invitation


def _deliver(
    db: Session,
    *,
    invitation: StaffInvitation,
    company: Company,
    raw_token: str,
) -> schemas.StaffInvitationActionOut:
    url = _invite_url(raw_token)
    result = deliver_staff_invitation(
        recipient=invitation.email,
        company_name=company.name,
        role=invitation.role,
        invite_url=url,
        expires_hours=settings.staff_invite_expiry_hours,
    )
    invitation.delivery_status = result.status
    invitation.sent_at = _utc_now() if result.sent else None
    invitation.updated_at = _utc_now()
    db.add(invitation)
    db.commit()
    db.refresh(invitation)
    return schemas.StaffInvitationActionOut(
        invitation=_invitation_out(invitation),
        inviteUrl=url,
    )


@router.get("", response_model=list[schemas.StaffUserOut])
def list_staff(
    company: Company = Depends(get_company),
    _: AdminUser = Depends(require_owner),
    db: Session = Depends(get_db),
) -> list[schemas.StaffUserOut]:
    users = db.scalars(
        select(AdminUser)
        .where(AdminUser.company_id == company.id)
        .order_by(AdminUser.created_at.asc(), AdminUser.email.asc())
    ).all()
    return [staff_out(user) for user in users]


@router.get(
    "/invitations",
    response_model=list[schemas.StaffInvitationOut],
)
def list_invitations(
    company: Company = Depends(get_company),
    _: AdminUser = Depends(require_owner),
    db: Session = Depends(get_db),
) -> list[schemas.StaffInvitationOut]:
    invitations = db.scalars(
        select(StaffInvitation)
        .where(StaffInvitation.company_id == company.id)
        .order_by(StaffInvitation.created_at.desc())
        .limit(100)
    ).all()
    return [_invitation_out(invitation) for invitation in invitations]


@router.post(
    "/invitations",
    response_model=schemas.StaffInvitationActionOut,
    status_code=status.HTTP_201_CREATED,
)
def create_invitation(
    body: schemas.StaffInvitationCreate,
    company: Company = Depends(get_company),
    owner: AdminUser = Depends(require_owner),
    db: Session = Depends(get_db),
) -> schemas.StaffInvitationActionOut:
    _company_branch(
        db,
        company_id=company.id,
        role=body.role,
        branch_id=body.branchId,
    )
    existing_user = db.scalar(
        select(AdminUser).where(func.lower(AdminUser.email) == body.email)
    )
    if existing_user is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="A staff account with this email already exists",
        )

    now = _utc_now()
    pending = db.scalar(
        select(StaffInvitation).where(
            func.lower(StaffInvitation.email) == body.email,
            StaffInvitation.accepted_at.is_(None),
            StaffInvitation.revoked_at.is_(None),
            StaffInvitation.expires_at > now,
        )
    )
    if pending is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="An active invitation for this email already exists",
        )

    raw_token = secrets.token_urlsafe(32)
    invitation = StaffInvitation(
        id=f"invite-{uuid4().hex}",
        company_id=company.id,
        email=body.email,
        role=body.role,
        branch_id=body.branchId,
        token_hash=_token_hash(raw_token),
        invited_by_id=owner.id,
        expires_at=now
        + timedelta(hours=settings.staff_invite_expiry_hours),
        delivery_status="manual_required",
        created_at=now,
        updated_at=now,
    )
    db.add(invitation)
    db.commit()
    db.refresh(invitation)
    return _deliver(
        db,
        invitation=invitation,
        company=company,
        raw_token=raw_token,
    )


@router.post(
    "/invitations/{invitationId}/resend",
    response_model=schemas.StaffInvitationActionOut,
)
def resend_invitation(
    invitationId: str,
    company: Company = Depends(get_company),
    _: AdminUser = Depends(require_owner),
    db: Session = Depends(get_db),
) -> schemas.StaffInvitationActionOut:
    invitation = db.scalar(
        select(StaffInvitation)
        .where(
            StaffInvitation.id == invitationId,
            StaffInvitation.company_id == company.id,
        )
        .with_for_update()
    )
    if invitation is None:
        raise HTTPException(status_code=404, detail="Invitation not found")
    if invitation.accepted_at is not None or invitation.revoked_at is not None:
        _ensure_invitation_usable(invitation)

    raw_token = secrets.token_urlsafe(32)
    now = _utc_now()
    invitation.token_hash = _token_hash(raw_token)
    invitation.expires_at = now + timedelta(
        hours=settings.staff_invite_expiry_hours
    )
    invitation.delivery_status = "manual_required"
    invitation.sent_at = None
    invitation.updated_at = now
    db.add(invitation)
    db.commit()
    db.refresh(invitation)
    return _deliver(
        db,
        invitation=invitation,
        company=company,
        raw_token=raw_token,
    )


@router.delete(
    "/invitations/{invitationId}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def revoke_invitation(
    invitationId: str,
    company: Company = Depends(get_company),
    _: AdminUser = Depends(require_owner),
    db: Session = Depends(get_db),
) -> Response:
    invitation = db.scalar(
        select(StaffInvitation)
        .where(
            StaffInvitation.id == invitationId,
            StaffInvitation.company_id == company.id,
        )
        .with_for_update()
    )
    if invitation is None:
        raise HTTPException(status_code=404, detail="Invitation not found")
    if invitation.accepted_at is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Accepted invitation cannot be revoked",
        )
    if invitation.revoked_at is None:
        invitation.revoked_at = _utc_now()
        invitation.updated_at = _utc_now()
        db.add(invitation)
        db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.patch("/{staffId}", response_model=schemas.StaffUserOut)
def update_staff(
    staffId: str,
    body: schemas.StaffUpdate,
    company: Company = Depends(get_company),
    owner: AdminUser = Depends(require_owner),
    db: Session = Depends(get_db),
) -> schemas.StaffUserOut:
    target = db.get(AdminUser, staffId)
    if target is None or target.company_id != company.id:
        raise HTTPException(status_code=404, detail="Staff user not found")

    changed_fields = body.model_fields_set
    if target.role == "owner":
        if target.id != owner.id or changed_fields - {"name"}:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Owner role and access cannot be changed here",
            )
        if body.name is not None:
            target.name = body.name
    else:
        next_role = body.role if "role" in changed_fields else target.role
        if next_role == "manager":
            if "branchId" in changed_fields and body.branchId is not None:
                raise HTTPException(
                    status_code=422,
                    detail="A manager cannot be assigned to one branch",
                )
            next_branch_id = None
        else:
            next_branch_id = (
                body.branchId
                if "branchId" in changed_fields
                else target.branch_id
            )
        _company_branch(
            db,
            company_id=company.id,
            role=next_role,
            branch_id=next_branch_id,
        )
        target.role = next_role
        target.branch_id = (
            next_branch_id if next_role == "barista" else None
        )
        if body.name is not None:
            target.name = body.name
        if body.isActive is not None:
            target.is_active = body.isActive

    target.updated_at = _utc_now()
    db.add(target)
    db.commit()
    db.refresh(target)
    return staff_out(target)


@public_router.post(
    "/preview",
    response_model=schemas.StaffInvitationPreviewOut,
)
def preview_invitation(
    body: schemas.StaffInvitationTokenIn,
    db: Session = Depends(get_db),
) -> schemas.StaffInvitationPreviewOut:
    invitation = _find_invitation_by_token(db, body.token)
    company = db.get(Company, invitation.company_id)
    if company is None:
        raise HTTPException(status_code=404, detail="Company not found")
    branch_name = None
    if invitation.branch_id is not None:
        branch = db.get(Branch, invitation.branch_id)
        branch_name = branch.name if branch is not None else None
    return schemas.StaffInvitationPreviewOut(
        email=invitation.email,
        companyId=company.id,
        companyName=company.name,
        role=invitation.role,
        branchName=branch_name,
        expiresAt=invitation.expires_at,
    )


@public_router.post(
    "/accept",
    response_model=schemas.StaffLoginOut,
)
def accept_invitation(
    body: schemas.StaffInvitationAcceptIn,
    db: Session = Depends(get_db),
) -> schemas.StaffLoginOut:
    invitation = _find_invitation_by_token(
        db, body.token, for_update=True
    )
    company = db.get(Company, invitation.company_id)
    if company is None:
        raise HTTPException(status_code=404, detail="Company not found")
    _company_branch(
        db,
        company_id=company.id,
        role=invitation.role,
        branch_id=invitation.branch_id,
    )
    existing = db.scalar(
        select(AdminUser).where(
            func.lower(AdminUser.email) == invitation.email
        )
    )
    if existing is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="A staff account with this email already exists",
        )

    now = _utc_now()
    user = AdminUser(
        id=f"staff-{uuid4().hex}",
        company_id=company.id,
        email=invitation.email,
        hashed_password=hash_password(body.password),
        name=body.name,
        role=invitation.role,
        branch_id=invitation.branch_id,
        is_active=True,
        created_at=now,
        updated_at=now,
    )
    db.add(user)
    try:
        db.flush()
        invitation.accepted_user_id = user.id
        invitation.accepted_at = now
        invitation.updated_at = now
        db.add(invitation)
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Invitation could not be accepted",
        ) from exc

    access, refresh = create_token_pair(
        subject=user.id,
        typ="staff",
        company_id=user.company_id,
        role=user.role,
    )
    return schemas.StaffLoginOut(
        accessToken=access,
        refreshToken=refresh,
        user=staff_out(user),
    )
