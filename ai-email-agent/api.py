from functools import lru_cache
from email.utils import parsedate_to_datetime
from email.utils import parseaddr
from typing import Any

from fastapi import FastAPI, File, HTTPException, Query, UploadFile, status
from pydantic import BaseModel, Field

from agent.chains import EmailChains
from agent.agent import EmailAgent
from config.settings import settings
from gmail.reader import Email, fetch_emails, fetch_single_email
from gmail.sender import send_email as gmail_send
from planning.service import PlanningImportService


app = FastAPI(title="TT Mail Assistant Agent 1")
chains = EmailChains()
planning_import_service = PlanningImportService()


class ChatRequest(BaseModel):
    message: str


class ChatResponse(BaseModel):
    response: str


class SendReplyRequest(BaseModel):
    body: str = Field(min_length=1)


class EmailPayload(BaseModel):
    id: str = Field(min_length=1)
    subject: str = ""
    sender: str = ""
    body: str = ""
    body_preview: str = ""
    date: str = ""
    received_at: str | None = None
    is_read: bool = False


class BulkDraft(BaseModel):
    recipient: str = ""
    to: str = ""
    email: str = ""
    subject: str = Field(min_length=1)
    body: str = Field(min_length=1)


class SendBulkDraftsRequest(BaseModel):
    drafts: list[BulkDraft] = Field(min_length=1)


class PlanningImportSummary(BaseModel):
    import_id: str
    created_at: str
    status: str
    total_sessions: int
    total_participants: int
    missing_email_count: int
    warning_count: int
    error_count: int
    files: list[dict[str, Any]]


@lru_cache(maxsize=1)
def get_agent() -> EmailAgent:
    return EmailAgent()


@app.get("/health")
def health() -> dict[str, str]:
    return {
        "status": "ok",
        "service": "agent1",
        "ollama_base_url": settings.OLLAMA_BASE_URL,
        "ollama_model": settings.OLLAMA_MODEL,
    }


@app.get("/emails/unread")
def unread_emails(
    max_results: int = Query(default=10, ge=1, le=50),
) -> dict[str, Any]:
    emails = fetch_emails(max_results=max_results, query="is:unread")
    return _email_list_response(emails, include_analysis=True)


@app.get("/emails/review")
def review_emails(
    max_results: int = Query(default=10, ge=1, le=50),
) -> dict[str, Any]:
    emails = fetch_emails(max_results=max_results, query="is:unread")
    reviewed = [_email_with_analysis(email) for email in emails]
    urgent = [
        email
        for email in reviewed
        if email.get("priority") == "URGENT" or int(email.get("urgency_score", 0)) >= 7
    ]
    return {
        "status": "ok",
        "count": len(urgent),
        "urgent_emails": urgent,
    }


@app.get("/emails/{email_id}")
def email_detail(email_id: str) -> dict[str, Any]:
    email = fetch_single_email(email_id)
    if email is None:
        return {"status": "not_found", "email": None}
    return _email_detail_response(email)


@app.post("/emails/analyze")
def analyze_email(request: EmailPayload) -> dict[str, Any]:
    return _email_detail_response(_email_from_payload(request))


@app.post("/emails/{email_id}/send")
def send_email_reply(email_id: str, request: SendReplyRequest) -> dict[str, Any]:
    email = fetch_single_email(email_id)
    if email is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Email {email_id} not found.",
        )

    recipient = parseaddr(email.sender)[1] or email.sender.strip()
    if "@" not in recipient:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot send reply because the sender address is invalid.",
        )

    subject = _reply_subject(email.subject)
    try:
        sent = gmail_send(to=recipient, subject=subject, body=request.body)
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Gmail send failed: {exc}",
        ) from exc

    message_id = str(sent.get("id") or "").strip()
    if not message_id:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Gmail did not confirm the sent message.",
        )

    return {
        "status": "sent",
        "message_id": message_id,
        "to": recipient,
        "subject": subject,
    }


@app.post("/bulk/send-drafts")
def send_bulk_drafts(request: SendBulkDraftsRequest) -> dict[str, Any]:
    details: list[dict[str, Any]] = []

    for draft in request.drafts:
        recipient = draft.to.strip() or draft.email.strip() or draft.recipient.strip()
        if "@" not in recipient:
            details.append(
                {
                    "recipient": recipient,
                    "to": recipient,
                    "subject": draft.subject,
                    "status": "error",
                    "error": "Recipient email is invalid.",
                }
            )
            continue

        try:
            sent = gmail_send(to=recipient, subject=draft.subject, body=draft.body)
            details.append(
                {
                    "recipient": recipient,
                    "to": recipient,
                    "subject": draft.subject,
                    "status": "sent",
                    "message_id": str(sent.get("id") or ""),
                }
            )
        except Exception as exc:
            details.append(
                {
                    "recipient": recipient,
                    "to": recipient,
                    "subject": draft.subject,
                    "status": "error",
                    "error": str(exc),
                }
            )

    sent_count = sum(1 for item in details if item.get("status") == "sent")
    error_count = len(details) - sent_count
    return {
        "status": "ok" if error_count == 0 else "partial",
        "total": len(details),
        "sent": sent_count,
        "errors": error_count,
        "details": details,
    }


@app.post("/planning/import")
async def import_planning_files(
    files: list[UploadFile] = File(...),
) -> dict[str, Any]:
    if not files:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="At least one planning file is required.",
        )
    if len(files) > 5:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You can import a maximum of 5 planning files at once.",
        )

    loaded_files: list[tuple[str, bytes]] = []
    for upload in files:
        filename = upload.filename or "planning.xlsx"
        content = await upload.read()
        if not content:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"{filename} is empty.",
            )
        loaded_files.append((filename, content))

    try:
        result = planning_import_service.import_files(loaded_files)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc

    return result.to_dict()


@app.get("/planning/imports", response_model=list[PlanningImportSummary])
def list_planning_imports() -> list[dict[str, Any]]:
    return planning_import_service.list_imports()


@app.get("/planning/imports/{import_id}")
def get_planning_import(import_id: str) -> dict[str, Any]:
    result = planning_import_service.get_import(import_id)
    if result is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Planning import {import_id} not found.",
        )
    return result


@app.get("/planning/sessions")
def list_planning_sessions(
    import_id: str | None = Query(default=None),
    limit: int = Query(default=100, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
) -> dict[str, Any]:
    sessions = planning_import_service.list_sessions(
        import_id=import_id,
        limit=limit,
        offset=offset,
    )
    return {
        "status": "ok",
        "count": len(sessions),
        "sessions": sessions,
    }


@app.get("/planning/sessions/{session_key}")
def get_planning_session(
    session_key: str,
    import_id: str | None = Query(default=None),
) -> dict[str, Any]:
    session = planning_import_service.get_session(
        session_key,
        import_id=import_id,
    )
    if session is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Training session {session_key} not found.",
        )
    return {
        "status": "ok",
        "session": session,
    }


@app.get("/planning/missing-contacts")
def list_planning_missing_contacts(
    import_id: str | None = Query(default=None),
    limit: int = Query(default=200, ge=1, le=1000),
) -> dict[str, Any]:
    contacts = planning_import_service.list_missing_contacts(
        import_id=import_id,
        limit=limit,
    )
    return {
        "status": "ok",
        "count": len(contacts),
        "contacts": contacts,
    }


@app.post("/planning/contacts/import")
async def import_employee_contacts(
    files: list[UploadFile] = File(...),
) -> dict[str, Any]:
    if not files:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="At least one contact directory file is required.",
        )

    loaded_files: list[tuple[str, bytes]] = []
    for upload in files:
        filename = upload.filename or "contacts.xlsx"
        content = await upload.read()
        if not content:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"{filename} is empty.",
            )
        loaded_files.append((filename, content))

    try:
        return planning_import_service.import_contacts(loaded_files)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc


@app.get("/planning/contacts")
def list_employee_contacts(
    limit: int = Query(default=200, ge=1, le=1000),
    offset: int = Query(default=0, ge=0),
) -> dict[str, Any]:
    contacts = planning_import_service.list_contacts(limit=limit, offset=offset)
    return {
        "status": "ok",
        "count": len(contacts),
        "contacts": contacts,
    }


@app.post("/planning/contacts/apply")
def apply_employee_contact_mapping(
    import_id: str | None = Query(default=None),
) -> dict[str, Any]:
    result = planning_import_service.apply_contact_mapping(import_id=import_id)
    return {
        "status": "ok",
        **result,
    }


@app.get("/dashboard/stats")
def dashboard_stats(
    max_results: int = Query(default=10, ge=1, le=50),
) -> dict[str, Any]:
    emails = fetch_emails(max_results=max_results, query="is:unread")
    categories: dict[str, int] = {}
    urgent_count = 0
    review_count = 0

    for email in emails:
        analyzed = _email_with_analysis(email)
        category = str(analyzed.get("category", "INFORMATION"))
        categories[category] = categories.get(category, 0) + 1
        if analyzed.get("priority") == "URGENT":
            urgent_count += 1
        if int(analyzed.get("urgency_score", 0)) >= 7:
            review_count += 1

    return {
        "processed_count": len(emails),
        "urgent_count": urgent_count,
        "review_count": review_count,
        "sent_count": 0,
        "categories": categories,
    }


@app.post("/chat", response_model=ChatResponse)
def chat(request: ChatRequest) -> ChatResponse:
    fast_response = _try_fast_chat_response(request.message)
    if fast_response is not None:
        return ChatResponse(response=fast_response)

    response = get_agent().chat(request.message)
    return ChatResponse(response=response)


def _try_fast_chat_response(message: str) -> str | None:
    normalized = message.lower()
    wants_unread = "unread" in normalized or "inbox" in normalized
    wants_latest = "latest" in normalized or "last" in normalized or "recent" in normalized
    wants_summary = (
        "summarize" in normalized
        or "summarise" in normalized
        or "summary" in normalized
        or "resume" in normalized
        or "résume" in normalized
        or "résumé" in normalized
    )
    wants_single_latest = (
        "last email" in normalized
        or "latest email" in normalized
        or "recent email" in normalized
    )
    wants_classify = "classify" in normalized or "classification" in normalized
    wants_urgent = "urgent" in normalized or "priority" in normalized
    wants_stats = "stats" in normalized or "dashboard" in normalized or "statistics" in normalized

    if wants_stats:
        stats = dashboard_stats(max_results=10)
        categories = stats.get("categories", {})
        return (
            "Dashboard snapshot:\n"
            f"- Processed unread emails: {stats.get('processed_count', 0)}\n"
            f"- Urgent emails: {stats.get('urgent_count', 0)}\n"
            f"- Need review: {stats.get('review_count', 0)}\n"
            f"- Categories: {categories}"
        )

    if wants_urgent:
        result = review_emails(max_results=5)
        urgent_emails = result.get("urgent_emails", [])
        if not urgent_emails:
            return "I did not find urgent unread emails right now."
        lines = ["Here are the unread emails that need review:"]
        for item in urgent_emails:
            lines.append(
                "- {subject} from {sender}: {priority} priority, score {score}.".format(
                    subject=item["subject"],
                    sender=item["sender"],
                    priority=item["priority"].lower(),
                    score=item["urgency_score"],
                )
            )
        return "\n".join(lines)

    if not wants_unread and not wants_latest and not wants_classify and not wants_summary:
        return None

    emails = fetch_emails(
        max_results=1 if wants_single_latest or wants_summary else 5,
        query="is:unread",
    )
    if not emails:
        return "I did not find unread emails in your Gmail inbox."

    if wants_summary or wants_single_latest:
        return _format_chat_email_summary(_email_with_analysis(emails[0]))

    if wants_classify:
        analyzed = [_email_with_analysis(email) for email in emails]
        lines = ["Here are your latest unread emails with classification:"]
        for item in analyzed:
            lines.append(
                "- {subject} from {sender}: {category}, {priority} priority.".format(
                    subject=item["subject"],
                    sender=item["sender"],
                    category=item["category"],
                    priority=item["priority"].lower(),
                )
            )
        return "\n".join(lines)

    lines = ["Here are your latest unread emails:"]
    for email in emails:
        lines.append(_format_chat_email_line(_email_with_analysis(email)))
    return "\n".join(lines)


def _format_chat_email_summary(email: dict[str, Any]) -> str:
    priority = str(email.get("priority") or "NORMAL").lower()
    score = int(email.get("urgency_score") or 0)
    summary = str(email.get("summary") or email.get("body_preview") or "No summary available.").strip()
    reply = str(email.get("suggested_reply") or "").strip()
    lines = [
        "Latest unread email:",
        f"- Subject: {email.get('subject') or '(no subject)'}",
        f"- From: {email.get('sender') or ''}",
        f"- Category: {email.get('category') or 'INFORMATION'}",
        f"- Priority: {priority} ({score}/10)",
        f"- Summary: {summary}",
    ]
    if reply:
        lines.append(f"- Suggested reply: {reply}")
    return "\n".join(lines)


def _format_chat_email_line(email: dict[str, Any]) -> str:
    priority = str(email.get("priority") or "NORMAL").lower()
    summary = str(email.get("summary") or email.get("body_preview") or "").strip()
    return (
        f"- {email.get('subject') or '(no subject)'} from {email.get('sender') or ''}: "
        f"{priority} priority. {summary}"
    ).strip()


def _email_list_response(
    emails: list[Email],
    *,
    include_analysis: bool = False,
) -> dict[str, Any]:
    return {
        "status": "ok" if emails else "empty",
        "count": len(emails),
        "emails": [
            _email_with_analysis(email) if include_analysis else _email_preview(email)
            for email in emails
        ],
    }


def _email_preview(email: Email) -> dict[str, Any]:
    return {
        "id": email.id,
        "subject": email.subject,
        "sender": email.sender,
        "date": _iso_date(email.date),
        "is_read": email.is_read,
        "body_preview": email.short_body(),
        "body": email.body,
    }


def _iso_date(value: str) -> str:
    try:
        return parsedate_to_datetime(value).isoformat()
    except (TypeError, ValueError, IndexError):
        return value


def _email_with_analysis(email: Email) -> dict[str, Any]:
    classification = chains._rule_based_classify(
        subject=email.subject,
        sender=email.sender,
        body=email.body,
    )
    priority = chains._rule_based_priority(
        subject=email.subject,
        sender=email.sender,
        body=email.body,
        category=classification.category,
    )
    summary = chains._rule_based_summary(
        subject=email.subject,
        sender=email.sender,
        body=email.body,
    )
    reply = chains._rule_based_reply(
        subject=email.subject,
        sender=email.sender,
        body=email.body,
        category=classification.category,
        priority=priority.priority,
        summary=summary.summary,
    )

    return {
        **_email_preview(email),
        "category": classification.category,
        "confidence": classification.confidence,
        "priority": priority.priority,
        "urgency_score": priority.urgency_score,
        "summary": summary.summary,
        "action_required": summary.action_required,
        "language": summary.language,
        "suggested_reply": reply.reply,
        "reply_subject": reply.reply_subject,
        "tone": reply.tone,
    }


def _email_detail_response(email: Email) -> dict[str, Any]:
    analyzed = _email_with_analysis(email)
    reply = chains._rule_based_reply(
        subject=email.subject,
        sender=email.sender,
        body=email.body,
        category=str(analyzed["category"]),
        priority=str(analyzed["priority"]),
        summary=str(analyzed["summary"]),
    )

    return {
        "status": "ok",
        "email": analyzed,
        "category": analyzed["category"],
        "confidence": analyzed["confidence"],
        "priority": analyzed["priority"],
        "urgency_score": analyzed["urgency_score"],
        "summary": analyzed["summary"],
        "action_required": analyzed["action_required"],
        "language": analyzed["language"],
        "suggested_reply": reply.reply,
        "reply_subject": reply.reply_subject,
        "tone": reply.tone,
    }


def _email_from_payload(payload: EmailPayload) -> Email:
    body = payload.body.strip() or payload.body_preview.strip()
    return Email(
        id=payload.id,
        subject=payload.subject or "(no subject)",
        sender=payload.sender,
        body=body,
        date=payload.date or payload.received_at or "",
        is_read=payload.is_read,
    )


def _reply_subject(subject: str) -> str:
    cleaned = subject.strip() if subject else "Your message"
    if cleaned.lower().startswith("re:"):
        return cleaned
    return f"Re: {cleaned}"
