import base64
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from auth.gmail_auth import get_gmail_service


def send_email(to: str, subject: str, body: str) -> dict:
    """
    Envoie un email simple via Gmail API.

    Args:
        to      : adresse du destinataire
        subject : sujet de l'email
        body    : corps en texte brut

    Returns:
        Dictionnaire avec l'id du message envoyé
    """
    service = get_gmail_service()

    message = MIMEText(body, "plain", "utf-8")
    message["to"]      = to
    message["subject"] = subject

    raw = base64.urlsafe_b64encode(message.as_bytes()).decode("utf-8")

    sent = service.users().messages().send(
        userId="me",
        body={"raw": raw}
    ).execute()

    return sent


def send_bulk_emails(recipients: list[dict]) -> list[dict]:
    """
    Envoie des emails personnalisés à plusieurs destinataires.

    Args:
        recipients : liste de dicts avec clés 'to', 'subject', 'body'
                     Exemple :
                     [
                       {"to": "alice@gmail.com",
                        "subject": "Réunion",
                        "body": "Bonjour Alice, ..."},
                       {"to": "bob@gmail.com",
                        "subject": "Rapport",
                        "body": "Bonjour Bob, ..."},
                     ]

    Returns:
        Liste des résultats (un par email envoyé)
    """
    results = []
    for r in recipients:
        try:
            result = send_email(r["to"], r["subject"], r["body"])
            results.append({"to": r["to"], "status": "sent", "id": result["id"]})
        except Exception as e:
            results.append({"to": r["to"], "status": "error", "error": str(e)})
    return results