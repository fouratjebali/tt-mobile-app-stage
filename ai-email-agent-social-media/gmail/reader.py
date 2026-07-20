import base64
from dataclasses import dataclass
from typing import Optional

try:
    from auth.gmail_auth import get_gmail_service, AuthenticationError
except ImportError:
    get_gmail_service = None

    class AuthenticationError(RuntimeError):
        pass


@dataclass
class Email:
    """Représente un email récupéré depuis Gmail."""
    id: str
    subject: str
    sender: str
    body: str
    date: str
    is_read: bool

    def short_body(self, max_chars: int = 300) -> str:
        """Retourne les premiers caractères du corps."""
        return self.body[:max_chars] + "..." if len(self.body) > max_chars else self.body


def _get_header(headers: list, name: str) -> str:
    """Extrait la valeur d'un header par son nom."""
    for h in headers:
        if h["name"].lower() == name.lower():
            return h["value"]
    return ""


def _decode_body(payload: dict) -> str:
    """Décode le corps base64 d'un email en texte lisible."""
    body = ""

    if "parts" in payload:
        for part in payload["parts"]:
            if part["mimeType"] == "text/plain":
                data = part["body"].get("data", "")
                if data:
                    body = base64.urlsafe_b64decode(data).decode("utf-8", errors="ignore")
                    break
    elif "body" in payload and payload["body"].get("data"):
        body = base64.urlsafe_b64decode(
            payload["body"]["data"]
        ).decode("utf-8", errors="ignore")

    return body.strip()


def _offline_mailbox() -> list[Email]:
    """Mailbox factice déterministe pour les environnements sans Gmail/Google."""
    return [
        Email("offline-001", "Urgent: service outage on account", "vip-client@example.com",
              "Our dashboard is down and our team needs help immediately.", "Mon, 01 Jul 2026 08:10:00 +0000", False),
        Email("offline-002", "Complaint about delayed response", "angry.customer@example.com",
              "I am disappointed with the delay and expect a proper resolution.", "Mon, 01 Jul 2026 09:15:00 +0000", False),
        Email("offline-003", "Invoice for June subscription", "billing@vendor.com",
              "Please find attached the invoice for your June subscription renewal.", "Mon, 01 Jul 2026 10:05:00 +0000", False),
        Email("offline-004", "Weekly newsletter", "news@updates.com",
              "Here is this week's newsletter and product updates.", "Mon, 01 Jul 2026 11:30:00 +0000", False),
        Email("offline-005", "Need help configuring SMTP", "it-admin@example.com",
              "I need help configuring SMTP for our new mail server.", "Mon, 01 Jul 2026 12:20:00 +0000", False),
        Email("offline-006", "Meeting reminder for tomorrow", "hr@example.com",
              "Reminder: our meeting is scheduled for tomorrow at 10am.", "Mon, 01 Jul 2026 13:00:00 +0000", False),
        Email("offline-007", "Promotion: 20% off enterprise plan", "sales@provider.com",
              "We are offering a 20% discount on the enterprise plan this month.", "Mon, 01 Jul 2026 13:40:00 +0000", False),
        Email("offline-008", "Support ticket update", "support@saas.com",
              "Your ticket has been updated and we are investigating the issue.", "Mon, 01 Jul 2026 14:10:00 +0000", False),
        Email("offline-009", "Automated security notification", "no-reply@security.com",
              "This is an automated security notification with no action required.", "Mon, 01 Jul 2026 15:05:00 +0000", True),
        Email("offline-010", "Payment failed for your order", "orders@shop.com",
              "The payment for your order failed. Please update your billing details.", "Mon, 01 Jul 2026 16:25:00 +0000", False),
        Email("offline-011", "Urgent: deadline moved to today", "project-lead@example.com",
              "The deadline moved to today. Please review immediately.", "Tue, 02 Jul 2026 08:05:00 +0000", False),
        Email("offline-012", "Question about account access", "customer@example.com",
              "How do I regain access to my account?", "Tue, 02 Jul 2026 09:20:00 +0000", False),
        Email("offline-013", "Notification: password reset complete", "no-reply@service.com",
              "Your password reset is complete.", "Tue, 02 Jul 2026 10:15:00 +0000", True),
        Email("offline-014", "Need a quote for renewal", "procurement@example.com",
              "Please send us a quote for the renewal of our contract.", "Tue, 02 Jul 2026 11:45:00 +0000", False),
        Email("offline-015", "Thanks for your support", "happy.customer@example.com",
              "Thanks for your quick support last week.", "Tue, 02 Jul 2026 12:30:00 +0000", True),
    ]


def _offline_lookup(email_id: str) -> Optional[Email]:
    for email in _offline_mailbox():
        if email.id == email_id:
            return email
    return None


def _offline_filter(emails: list[Email], query: str) -> list[Email]:
    query = (query or "").strip().lower()
    if not query:
        return emails

    filtered = emails
    if "is:unread" in query:
        filtered = [email for email in filtered if not email.is_read]

    keywords = [token for token in query.split() if not token.startswith("is:")]
    if keywords:
        filtered = [
            email for email in filtered
            if all(token in f"{email.subject} {email.sender} {email.body}".lower() for token in keywords)
        ]

    return filtered


def fetch_emails(max_results: int = 10, query: str = "is:unread") -> list[Email]:
    """
    Récupère des emails depuis Gmail.

    Args:
        max_results : nombre max d'emails à récupérer
        query       : filtre Gmail (ex: 'is:unread', 'from:boss@gmail.com')

    Returns:
        Liste d'objets Email
    """
    emails = []

    try:
        service = get_gmail_service()
    except Exception:
        fallback = _offline_filter(_offline_mailbox(), query)
        return fallback[:max_results]

    results = service.users().messages().list(
        userId="me",
        maxResults=max_results,
        q=query
    ).execute()

    messages = results.get("messages", [])

    for msg in messages:
        msg_data = service.users().messages().get(
            userId="me",
            id=msg["id"],
            format="full"
        ).execute()

        headers = msg_data["payload"]["headers"]
        labels  = msg_data.get("labelIds", [])

        email = Email(
            id=msg["id"],
            subject=_get_header(headers, "Subject") or "(Sans objet)",
            sender=_get_header(headers, "From"),
            body=_decode_body(msg_data["payload"]),
            date=_get_header(headers, "Date"),
            is_read="UNREAD" not in labels,
        )
        emails.append(email)

    return emails


def fetch_single_email(email_id: str) -> Optional[Email]:
    """Récupère un seul email par son ID Gmail."""
    try:
        service = get_gmail_service()
    except Exception:
        return _offline_lookup(email_id)

    msg_data = service.users().messages().get(
        userId="me",
        id=email_id,
        format="full"
    ).execute()

    headers = msg_data["payload"]["headers"]
    labels  = msg_data.get("labelIds", [])

    return Email(
        id=email_id,
        subject=_get_header(headers, "Subject") or "(Sans objet)",
        sender=_get_header(headers, "From"),
        body=_decode_body(msg_data["payload"]),
        date=_get_header(headers, "Date"),
        is_read="UNREAD" not in labels,
    )