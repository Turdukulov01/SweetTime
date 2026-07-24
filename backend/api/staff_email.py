"""Delivery adapter for staff invitation links.

The invitation itself is durable in PostgreSQL and remains usable even when an
email provider is unavailable. In manual mode the owner copies the one-time
link from the admin panel; SMTP mode sends the same link and reports failures
honestly instead of claiming that an email was sent.
"""

from dataclasses import dataclass
from email.message import EmailMessage
import smtplib
import ssl

from .config import settings


@dataclass(frozen=True, slots=True)
class InvitationDelivery:
    status: str
    sent: bool


def deliver_staff_invitation(
    *,
    recipient: str,
    company_name: str,
    role: str,
    invite_url: str,
    expires_hours: int,
) -> InvitationDelivery:
    if settings.staff_invite_delivery_mode != "smtp":
        return InvitationDelivery(status="manual_required", sent=False)

    try:
        message = EmailMessage()
        message["Subject"] = f"Приглашение в {company_name}"
        message["From"] = settings.smtp_from_email
        message["To"] = recipient
        message.set_content(
            "\n".join(
                [
                    f"Вас пригласили в админ-панель {company_name}.",
                    f"Роль: {role}.",
                    "",
                    "Откройте ссылку и задайте собственный пароль:",
                    invite_url,
                    "",
                    f"Ссылка действует {expires_hours} ч. и используется один раз.",
                    "Если вы не ожидали это письмо, просто проигнорируйте его.",
                ]
            )
        )
        tls_context = ssl.create_default_context()
        if settings.smtp_security == "ssl":
            client: smtplib.SMTP = smtplib.SMTP_SSL(
                settings.smtp_host,
                settings.smtp_port,
                timeout=settings.smtp_timeout_seconds,
                context=tls_context,
            )
        else:
            client = smtplib.SMTP(
                settings.smtp_host,
                settings.smtp_port,
                timeout=settings.smtp_timeout_seconds,
            )
        with client:
            if settings.smtp_security == "starttls":
                client.starttls(context=tls_context)
            if settings.smtp_username:
                client.login(settings.smtp_username, settings.smtp_password)
            client.send_message(message)
    except (ValueError, OSError, smtplib.SMTPException):
        return InvitationDelivery(status="failed", sent=False)

    return InvitationDelivery(status="sent", sent=True)
