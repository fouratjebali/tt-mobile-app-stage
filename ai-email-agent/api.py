from functools import lru_cache
from email.utils import parsedate_to_datetime
from email.utils import parseaddr
from typing import Any

from fastapi import FastAPI, File, Header, HTTPException, Query, UploadFile, status
from pydantic import BaseModel, Field

from agent.chains import EmailChains
from agent.agent import EmailAgent
from config.settings import settings
from gmail.reader import Email, fetch_emails, fetch_single_email
from gmail.sender import send_email as gmail_send
from outlook.graph_client import OutlookGraphClient, OutlookGraphError
from outlook.session_store import OutlookSession, OutlookSessionStore, is_expiring_soon
from planning.service import PlanningImportService


app = FastAPI(title="TT Mail Assistant Agent 1")
chains = EmailChains()
planning_import_service = PlanningImportService()
outlook_session_store = OutlookSessionStore()
outlook_graph_client = OutlookGraphClient(
    client_id=settings.MICROSOFT_CLIENT_ID or settings.client_id or "",
    client_secret=settings.MICROSOFT_CLIENT_SECRET or settings.client_secret or "",
    tenant_id=settings.MICROSOFT_TENANT_ID,
)


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


class MicrosoftAuthRequest(BaseModel):
    access_token: str = Field(min_length=1)
    id_token: str | None = None
    refresh_token: str = ""
    expires_at: str | None = None


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


class GenerateTrainingDraftsRequest(BaseModel):
    import_id: str | None = None
    session_key: str | None = None
    email_type: str = "auto"
    include_population: bool = True
    limit: int = Field(default=100, ge=1, le=500)


class RunPlanningAutomationRequest(BaseModel):
    import_id: str | None = None
    email_type: str = "auto"
    include_population: bool = True
    limit: int = Field(default=500, ge=1, le=1000)


class SaveEmployeeContactRequest(BaseModel):
    matricule: str = ""
    full_name: str = ""
    email: str = Field(min_length=3)
    direction: str = ""
    hr_responsible: str = ""


class UpdateTrainingDraftRequest(BaseModel):
    subject: str | None = None
    body: str | None = None
    html_body: str | None = None
    recipients: list[str] | None = None
    cc: list[str] | None = None


class RejectTrainingDraftRequest(BaseModel):
    reason: str = ""


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


@app.post("/auth/microsoft")
def sign_in_with_microsoft(request: MicrosoftAuthRequest) -> dict[str, Any]:
    try:
        me = outlook_graph_client.get_me(request.access_token)
    except OutlookGraphError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Microsoft token could not be verified: {exc}",
        ) from exc

    user = _user_from_graph_profile(me)
    session = outlook_session_store.create_session(
        access_token=request.access_token,
        refresh_token=request.refresh_token,
        expires_at=request.expires_at or "",
        user_id=user["id"],
        email=user["email"],
        display_name=user["display_name"],
        photo_url=user["photo_url"],
    )
    return {
        "status": "ok",
        "session_token": session.session_token,
        "expires_at": session.expires_at,
        "user": user,
    }


@app.get("/auth/me")
def current_outlook_user(
    authorization: str | None = Header(default=None),
) -> dict[str, Any]:
    session = _require_outlook_session(authorization)
    return {
        "id": session.user_id,
        "email": session.email,
        "display_name": session.display_name,
        "photo_url": session.photo_url,
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


@app.post("/planning/contacts")
def save_employee_contact(request: SaveEmployeeContactRequest) -> dict[str, Any]:
    try:
        result = planning_import_service.save_contact(
            matricule=request.matricule,
            full_name=request.full_name,
            email=request.email,
            direction=request.direction,
            hr_responsible=request.hr_responsible,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc
    return {
        "status": "ok",
        **result,
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


@app.post("/planning/drafts/generate")
def generate_training_drafts(request: GenerateTrainingDraftsRequest) -> dict[str, Any]:
    try:
        return planning_import_service.generate_training_drafts(
            import_id=request.import_id,
            session_key=request.session_key,
            email_type=request.email_type,
            include_population=request.include_population,
            limit=request.limit,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc


@app.post("/planning/automation/run")
def run_planning_automation(request: RunPlanningAutomationRequest) -> dict[str, Any]:
    try:
        return planning_import_service.run_training_automation(
            import_id=request.import_id,
            email_type=request.email_type,
            include_population=request.include_population,
            limit=request.limit,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc


@app.get("/planning/drafts")
def list_training_drafts(
    import_id: str | None = Query(default=None),
    session_key: str | None = Query(default=None),
    draft_status: str | None = Query(default=None),
    limit: int = Query(default=100, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
) -> dict[str, Any]:
    drafts = planning_import_service.list_training_drafts(
        import_id=import_id,
        session_key=session_key,
        status=draft_status,
        limit=limit,
        offset=offset,
    )
    return {
        "status": "ok",
        "count": len(drafts),
        "drafts": drafts,
    }


@app.get("/planning/send-history")
def list_training_send_history(
    import_id: str | None = Query(default=None),
    draft_id: int | None = Query(default=None),
    send_status: str | None = Query(default=None),
    limit: int = Query(default=100, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
) -> dict[str, Any]:
    history = planning_import_service.list_training_send_logs(
        import_id=import_id,
        draft_id=draft_id,
        status=send_status,
        limit=limit,
        offset=offset,
    )
    return {
        "status": "ok",
        "count": len(history),
        "history": history,
    }


@app.get("/planning/drafts/{draft_id}")
def get_training_draft(draft_id: int) -> dict[str, Any]:
    draft = planning_import_service.get_training_draft(draft_id)
    if draft is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Training draft {draft_id} not found.",
        )
    return {
        "status": "ok",
        "draft": draft,
    }


@app.patch("/planning/drafts/{draft_id}")
def update_training_draft(
    draft_id: int,
    request: UpdateTrainingDraftRequest,
) -> dict[str, Any]:
    try:
        draft = planning_import_service.update_training_draft(
            draft_id,
            subject=request.subject,
            body=request.body,
            html_body=request.html_body,
            recipients=request.recipients,
            cc=request.cc,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(exc),
        ) from exc
    if draft is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Training draft {draft_id} not found.",
        )
    return {
        "status": "ok",
        "draft": draft,
    }


@app.post("/planning/drafts/{draft_id}/approve")
def approve_training_draft(draft_id: int) -> dict[str, Any]:
    try:
        draft = planning_import_service.approve_training_draft(draft_id)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(exc),
        ) from exc
    if draft is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Training draft {draft_id} not found.",
        )
    return {
        "status": "ok",
        "draft": draft,
    }


@app.post("/planning/drafts/{draft_id}/reject")
def reject_training_draft(
    draft_id: int,
    request: RejectTrainingDraftRequest,
) -> dict[str, Any]:
    try:
        draft = planning_import_service.reject_training_draft(
            draft_id,
            reason=request.reason,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(exc),
        ) from exc
    if draft is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Training draft {draft_id} not found.",
        )
    return {
        "status": "ok",
        "draft": draft,
    }


@app.post("/planning/drafts/{draft_id}/send")
def send_training_draft(
    draft_id: int,
    authorization: str | None = Header(default=None),
) -> dict[str, Any]:
    session = _require_outlook_session(authorization)
    try:
        draft = planning_import_service.send_training_draft(
            draft_id,
            outlook_sender=outlook_graph_client,
            access_token=session.access_token,
        )
    except OutlookGraphError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Outlook send failed: {exc}",
        ) from exc
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(exc),
        ) from exc
    if draft is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Training draft {draft_id} not found.",
        )
    return {
        "status": "sent",
        "draft": draft,
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



def _require_outlook_session(authorization: str | None) -> OutlookSession:
    token = _bearer_token(authorization)
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Outlook session is required.",
        )

    session = outlook_session_store.get_session(token)
    if session is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Outlook session is invalid or expired.",
        )

    if is_expiring_soon(session.expires_at) and session.refresh_token:
        try:
            refreshed = outlook_graph_client.refresh_access_token(session.refresh_token)
            access_token = refreshed["access_token"]
            if access_token:
                updated = outlook_session_store.update_tokens(
                    session.session_token,
                    access_token=access_token,
                    refresh_token=refreshed.get("refresh_token", ""),
                    expires_at=refreshed.get("expires_at", ""),
                )
                if updated is not None:
                    return updated
        except OutlookGraphError:
            return session

    return session


def _bearer_token(authorization: str | None) -> str:
    if not authorization:
        return ""
    prefix = "bearer "
    if authorization.lower().startswith(prefix):
        return authorization[len(prefix) :].strip()
    return authorization.strip()


def _user_from_graph_profile(profile: dict[str, Any]) -> dict[str, str]:
    email = str(profile.get("mail") or profile.get("userPrincipalName") or "").strip()
    user_id = str(profile.get("id") or email or "microsoft").strip()
    return {
        "id": user_id,
        "email": email,
        "display_name": str(profile.get("displayName") or email or "Outlook user"),
        "photo_url": "",
    }
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
