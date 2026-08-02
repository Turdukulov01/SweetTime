import logging
import smtplib

from api import staff_email


class _FakeSmtp:
    def __init__(self, events, *args, **kwargs):
        self.events = events
        self.events.append(("connect", args, kwargs))

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, traceback):
        self.events.append(("close",))

    def starttls(self, *, context):
        self.events.append(("starttls", context is not None))

    def login(self, username, password):
        self.events.append(("login", username, password))

    def send_message(self, message):
        self.events.append(
            (
                "send",
                message["From"],
                message["To"],
                message["Subject"],
                message.get_content(),
            )
        )


def _configure_smtp(monkeypatch, *, security="starttls") -> None:
    monkeypatch.setattr(
        staff_email.settings, "staff_invite_delivery_mode", "smtp"
    )
    monkeypatch.setattr(staff_email.settings, "smtp_host", "smtp.test")
    monkeypatch.setattr(staff_email.settings, "smtp_port", 587)
    monkeypatch.setattr(staff_email.settings, "smtp_username", "sender")
    monkeypatch.setattr(staff_email.settings, "smtp_password", "secret")
    monkeypatch.setattr(
        staff_email.settings, "smtp_from_email", "sender@example.test"
    )
    monkeypatch.setattr(staff_email.settings, "smtp_security", security)
    monkeypatch.setattr(staff_email.settings, "smtp_timeout_seconds", 7)


def _deliver():
    return staff_email.deliver_staff_invitation(
        recipient="manager@recipient.test",
        company_name="SweetTime",
        role="manager",
        invite_url="https://admin.test/staff-invite#token=one-time",
        expires_hours=72,
    )


def test_manual_delivery_never_connects_to_smtp(monkeypatch) -> None:
    monkeypatch.setattr(
        staff_email.settings, "staff_invite_delivery_mode", "manual"
    )

    def unexpected_connection(*args, **kwargs):
        raise AssertionError("manual delivery must not open SMTP")

    monkeypatch.setattr(staff_email.smtplib, "SMTP", unexpected_connection)

    result = _deliver()

    assert result.status == "manual_required"
    assert result.sent is False


def test_starttls_delivery_authenticates_and_sends_invitation(monkeypatch) -> None:
    _configure_smtp(monkeypatch)
    events = []
    monkeypatch.setattr(
        staff_email.smtplib,
        "SMTP",
        lambda *args, **kwargs: _FakeSmtp(events, *args, **kwargs),
    )

    result = _deliver()

    assert result.status == "sent"
    assert result.sent is True
    assert events[0][0] == "connect"
    assert events[0][1] == ("smtp.test", 587)
    assert events[0][2]["timeout"] == 7
    assert [event[0] for event in events] == [
        "connect",
        "starttls",
        "login",
        "send",
        "close",
    ]
    sent = events[3]
    assert sent[1] == "sender@example.test"
    assert sent[2] == "manager@recipient.test"
    assert "Приглашение в SweetTime" == sent[3]
    assert "https://admin.test/staff-invite#token=one-time" in sent[4]


def test_ssl_delivery_uses_implicit_tls_without_starttls(monkeypatch) -> None:
    _configure_smtp(monkeypatch, security="ssl")
    events = []
    monkeypatch.setattr(
        staff_email.smtplib,
        "SMTP_SSL",
        lambda *args, **kwargs: _FakeSmtp(events, *args, **kwargs),
    )

    result = _deliver()

    assert result.sent is True
    assert [event[0] for event in events] == [
        "connect",
        "login",
        "send",
        "close",
    ]
    assert events[0][2]["context"] is not None


def test_smtp_relay_without_credentials_does_not_attempt_login(monkeypatch) -> None:
    _configure_smtp(monkeypatch)
    monkeypatch.setattr(staff_email.settings, "smtp_username", "")
    monkeypatch.setattr(staff_email.settings, "smtp_password", "")
    events = []
    monkeypatch.setattr(
        staff_email.smtplib,
        "SMTP",
        lambda *args, **kwargs: _FakeSmtp(events, *args, **kwargs),
    )

    result = _deliver()

    assert result.sent is True
    assert [event[0] for event in events] == [
        "connect",
        "starttls",
        "send",
        "close",
    ]


def test_smtp_failure_is_reported_without_logging_recipient_or_secret(
    monkeypatch,
    caplog,
) -> None:
    _configure_smtp(monkeypatch)

    def failed_connection(*args, **kwargs):
        raise smtplib.SMTPConnectError(421, "provider unavailable")

    monkeypatch.setattr(staff_email.smtplib, "SMTP", failed_connection)

    with caplog.at_level(logging.ERROR, logger="api.staff_email"):
        result = _deliver()

    assert result.status == "failed"
    assert result.sent is False
    log_text = caplog.text
    assert "recipient_domain=recipient.test" in log_text
    assert "manager@recipient.test" not in log_text
    assert "secret" not in log_text
    assert "error_type=SMTPConnectError" in log_text
    assert "smtp_code=421" in log_text


def test_rejected_recipient_address_is_not_exposed_in_logs(
    monkeypatch,
    caplog,
) -> None:
    _configure_smtp(monkeypatch)

    class _RejectingSmtp(_FakeSmtp):
        def send_message(self, message):
            raise smtplib.SMTPRecipientsRefused(
                {"manager@recipient.test": (550, b"mailbox unavailable")}
            )

    monkeypatch.setattr(
        staff_email.smtplib,
        "SMTP",
        lambda *args, **kwargs: _RejectingSmtp([], *args, **kwargs),
    )

    with caplog.at_level(logging.ERROR, logger="api.staff_email"):
        result = _deliver()

    assert result.status == "failed"
    assert result.sent is False
    assert "recipient_domain=recipient.test" in caplog.text
    assert "error_type=SMTPRecipientsRefused" in caplog.text
    assert "manager@recipient.test" not in caplog.text
    assert "mailbox unavailable" not in caplog.text
