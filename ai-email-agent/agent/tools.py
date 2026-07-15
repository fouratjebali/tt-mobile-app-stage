import json
import re
from gmail.reader import fetch_emails, fetch_single_email
from gmail.sender import send_email as gmail_send, send_bulk_emails
from agent.chains import EmailChains

try:
    from langchain_core.tools import tool
except ImportError:
    class _SimpleTool:
        def __init__(self, func):
            self.func = func
            self.name = func.__name__

        def invoke(self, input_data=None):
            if input_data is None:
                input_data = {}
            if not isinstance(input_data, dict):
                raise TypeError("Tool input must be a dictionary")
            return self.func(**input_data)

        def __call__(self, *args, **kwargs):
            return self.func(*args, **kwargs)

    def tool(func):
        return _SimpleTool(func)

# Instance partagée des chains (évite de recharger le LLM à chaque appel)
_chains = EmailChains()


_GMAIL_ID_HINTS = (
    "first email id",
    "second email id",
    "third email id",
    "fourth email id",
    "fifth email id",
    "email id from read_emails output",
    "paste",
    "placeholder",
)


def _validate_email_id(email_id: str) -> str | None:
    cleaned_id = email_id.strip()
    if not cleaned_id:
        return "Email ID is required. Copy the exact id from read_emails output."

    lowered = cleaned_id.lower()
    if any(hint in lowered for hint in _GMAIL_ID_HINTS):
        return "Invalid placeholder email ID. Copy the exact id value from read_emails output."

    if re.search(r"\s", cleaned_id):
        return "Invalid email ID format. Gmail message IDs do not contain spaces."

    return None


# OUTIL 1 : Lire les emails
@tool
def read_emails(query: str = "is:unread", max_results: int = 10) -> str:
    """
    Reads emails from Gmail and returns them as a JSON string.
    Use this tool first to get emails before analyzing them.

    Args:
        query      : Gmail search query. Examples:
                     'is:unread'           → unread emails
                     'is:unread urgent'    → unread emails with 'urgent'
                     'from:boss@gmail.com' → emails from a specific sender
                     ''                   → latest emails (read + unread)
        max_results: maximum number of emails to retrieve (default 10)

    Returns:
        JSON string with list of emails (id, subject, sender, date, body preview)
    """
    emails = fetch_emails(max_results=max_results, query=query)

    if not emails:
        return json.dumps({"status": "empty", "emails": [], "count": 0})

    result = []
    for e in emails:
        result.append({
            "id":      e.id,
            "subject": e.subject,
            "sender":  e.sender,
            "date":    e.date,
            "is_read": e.is_read,
            "body_preview": e.body[:300],
        })

    return json.dumps({
        "status": "ok",
        "count":  len(result),
        "emails": result,
    }, ensure_ascii=False)


# OUTIL 2 : Classifier un email
@tool
def classify_email(email_id: str) -> str:
    """
    Classifies a single email by its Gmail ID.
    Categories: RECLAMATION, INFORMATION, SUPPORT, COMMERCIAL.
    Always call read_emails first to get email IDs.

    Args:
        email_id: the Gmail message ID (from read_emails output)

    Returns:
        JSON string with category, confidence score, and reason
    """
    validation_error = _validate_email_id(email_id)
    if validation_error:
        return json.dumps({"error": validation_error, "email_id": email_id}, ensure_ascii=False)

    try:
        email = fetch_single_email(email_id)
    except Exception as exc:
        return json.dumps({"error": str(exc), "email_id": email_id}, ensure_ascii=False)

    if not email:
        return json.dumps({"error": f"Email {email_id} not found", "email_id": email_id}, ensure_ascii=False)

    result = _chains.classify(
        subject=email.subject,
        sender=email.sender,
        body=email.body,
    )

    return json.dumps({
        "email_id":   email_id,
        "subject":    email.subject,
        "category":   result.category,
        "confidence": result.confidence,
        "reason":     result.reason,
    }, ensure_ascii=False)


# OUTIL 3 : Prioriser un email
@tool
def prioritize_email(email_id: str, category: str = "UNKNOWN") -> str:
    """
    Determines the urgency/priority of a single email.
    Priority levels: URGENT, NORMAL, LOW.
    Call classify_email first to get the category.

    Args:
        email_id: the Gmail message ID
        category: the category from classify_email (optional, helps accuracy)

    Returns:
        JSON string with priority, urgency score (1-10), and reason
    """
    validation_error = _validate_email_id(email_id)
    if validation_error:
        return json.dumps({"error": validation_error, "email_id": email_id}, ensure_ascii=False)

    try:
        email = fetch_single_email(email_id)
    except Exception as exc:
        return json.dumps({"error": str(exc), "email_id": email_id}, ensure_ascii=False)

    if not email:
        return json.dumps({"error": f"Email {email_id} not found", "email_id": email_id}, ensure_ascii=False)

    result = _chains.prioritize(
        subject=email.subject,
        sender=email.sender,
        body=email.body,
        category=category,
    )

    return json.dumps({
        "email_id":     email_id,
        "subject":      email.subject,
        "priority":     result.priority,
        "urgency_score": result.urgency_score,
        "reason":       result.reason,
    }, ensure_ascii=False)


# OUTIL 4 : Résumer un email
@tool
def summarize_email(email_id: str) -> str:
    """
    Generates a short summary of an email and identifies required actions.

    Args:
        email_id: the Gmail message ID

    Returns:
        JSON string with summary, required action, and detected language
    """
    validation_error = _validate_email_id(email_id)
    if validation_error:
        return json.dumps({"error": validation_error, "email_id": email_id}, ensure_ascii=False)

    try:
        email = fetch_single_email(email_id)
    except Exception as exc:
        return json.dumps({"error": str(exc), "email_id": email_id}, ensure_ascii=False)

    if not email:
        return json.dumps({"error": f"Email {email_id} not found", "email_id": email_id}, ensure_ascii=False)

    result = _chains.summarize(
        subject=email.subject,
        sender=email.sender,
        body=email.body,
    )

    return json.dumps({
        "email_id":       email_id,
        "subject":        email.subject,
        "summary":        result.summary,
        "action_required": result.action_required,
        "language":       result.language,
    }, ensure_ascii=False)


# OUTIL 5 : Suggérer une réponse
@tool
def suggest_reply(
    email_id: str,
    category: str = "SUPPORT",
    priority: str = "NORMAL",
) -> str:
    """
    Generates a professional reply suggestion for an email.
    The reply is in the same language as the original email.
    Call classify_email and prioritize_email first for best results.

    Args:
        email_id : the Gmail message ID
        category : from classify_email output
        priority : from prioritize_email output

    Returns:
        JSON string with suggested reply text and subject line
    """
    validation_error = _validate_email_id(email_id)
    if validation_error:
        return json.dumps({"error": validation_error, "email_id": email_id}, ensure_ascii=False)

    try:
        email = fetch_single_email(email_id)
    except Exception as exc:
        return json.dumps({"error": str(exc), "email_id": email_id}, ensure_ascii=False)

    if not email:
        return json.dumps({"error": f"Email {email_id} not found", "email_id": email_id}, ensure_ascii=False)

    summary_result = _chains.summarize(
        subject=email.subject,
        sender=email.sender,
        body=email.body,
    )

    result = _chains.suggest_reply(
        subject=email.subject,
        sender=email.sender,
        body=email.body,
        category=category,
        priority=priority,
        summary=summary_result.summary,
    )

    return json.dumps({
        "email_id":      email_id,
        "to":            email.sender,
        "reply_subject": result.reply_subject,
        "reply_body":    result.reply,
        "tone":          result.tone,
    }, ensure_ascii=False)


# OUTIL 6 : Envoyer un email
@tool
def send_single_email(to: str, subject: str, body: str) -> str:
    """
    Sends a single email via Gmail.
    Use this after suggest_reply to actually send the response.

    Args:
        to     : recipient email address (e.g. 'contact@example.com')
        subject: email subject line
        body   : email body text

    Returns:
        JSON string with send status and message ID
    """
    try:
        result = gmail_send(to=to, subject=subject, body=body)
        return json.dumps({
            "status":     "sent",
            "to":         to,
            "subject":    subject,
            "message_id": result.get("id", "unknown"),
        }, ensure_ascii=False)
    except Exception as e:
        return json.dumps({
            "status": "error",
            "to":     to,
            "error":  str(e),
        }, ensure_ascii=False)


# OUTIL 7 : Envoyer des emails en masse (bulk)
@tool
def send_bulk_email(recipients_json: str) -> str:
    """
    Sends personalized emails to multiple recipients at once.
    Use this when the user wants to send different emails to several people.

    Args:
        recipients_json: JSON string with list of recipients. Each must have:
                         'to'      : email address
                         'subject' : email subject
                         'body'    : personalized email body
                         Example:
                         '[
                           {"to":"alice@mail.com","subject":"Meeting","body":"Hi Alice..."},
                           {"to":"bob@mail.com","subject":"Report","body":"Hi Bob..."}
                         ]'

    Returns:
        JSON string with send status for each recipient
    """
    try:
        recipients = json.loads(recipients_json)
    except json.JSONDecodeError:
        return json.dumps({"status": "error", "error": "Invalid JSON for recipients"})

    results = send_bulk_emails(recipients)

    sent  = sum(1 for r in results if r["status"] == "sent")
    errors = sum(1 for r in results if r["status"] == "error")

    return json.dumps({
        "total":   len(results),
        "sent":    sent,
        "errors":  errors,
        "details": results,
    }, ensure_ascii=False)


# OUTIL 8 : Obtenir uniquement les emails urgents
@tool
def get_urgent_emails(max_results: int = 20) -> str:
    """
    Reads emails, classifies and prioritizes each one,
    then returns ONLY the URGENT ones.
    This tool is slower (calls LLM per email) but filters automatically.

    Args:
        max_results: how many emails to scan (default 20)

    Returns:
        JSON string with only URGENT emails and their analysis
    """
    emails = fetch_emails(max_results=max_results, query="is:unread")

    if not emails:
        return json.dumps({"status": "empty", "urgent_emails": [], "count": 0})

    urgent = []
    for email in emails:
        classification = _chains.classify(
            subject=email.subject,
            sender=email.sender,
            body=email.body,
        )
        priority = _chains.prioritize(
            subject=email.subject,
            sender=email.sender,
            body=email.body,
            category=classification.category,
        )
        if priority.priority == "URGENT":
            urgent.append({
                "id":           email.id,
                "subject":      email.subject,
                "sender":       email.sender,
                "category":     classification.category,
                "urgency_score": priority.urgency_score,
                "reason":       priority.reason,
            })

    return json.dumps({
        "status":        "ok",
        "count":         len(urgent),
        "urgent_emails": urgent,
    }, ensure_ascii=False)


# OUTIL 9 : Bulk email intelligent avec personnalisation
@tool
def generate_and_send_bulk_emails(
    recipients_json: str,
    topic: str,
    instructions: str = "",
    dry_run: bool = False,
) -> str:
    """
    Generates and sends PERSONALIZED emails to multiple recipients.
    Each email is uniquely tailored to the recipient's role and context.
    Use this when the user wants to send DIFFERENT content to different people.

    Args:
        recipients_json : JSON string with list of recipients. Each must have:
                          'name'    : recipient's full name
                          'email'   : email address
                          'role'    : their job role/position
                          'context' : specific context for personalization
                          Example:
                          '[
                            {"name":"Alice","email":"alice@co.com",
                             "role":"Chef de projet",
                             "context":"Elle gère le projet X, demande un point"},
                            {"name":"Bob","email":"bob@co.com",
                             "role":"Développeur",
                             "context":"En retard sur la deadline du module Y"}
                          ]'
        topic        : the general topic/purpose of all emails
        instructions : additional writing instructions (tone, content to include)
        dry_run      : if True, generates but does NOT send (for preview)

    Returns:
        JSON string with generation and send results per recipient
    """
    from agent.bulk_generator import BulkEmailGenerator, Recipient

    try:
        raw_recipients = json.loads(recipients_json)
    except json.JSONDecodeError:
        return json.dumps({"error": "Invalid JSON for recipients_json"})

    recipients = [
        Recipient(
            name=r.get("name", "Unknown"),
            email=r.get("email", ""),
            role=r.get("role", "Collaborateur"),
            context=r.get("context", ""),
        )
        for r in raw_recipients
    ]

    generator = BulkEmailGenerator()
    results   = generator.generate_and_send(
        recipients=recipients,
        topic=topic,
        instructions=instructions,
        send=not dry_run,
    )

    return generator.results_to_json(results)


# Liste de tous les outils (importée par l'agent)
ALL_TOOLS = [
    read_emails,
    classify_email,
    prioritize_email,
    summarize_email,
    suggest_reply,
    send_single_email,
    send_bulk_email,
    get_urgent_emails,
    generate_and_send_bulk_emails,
]