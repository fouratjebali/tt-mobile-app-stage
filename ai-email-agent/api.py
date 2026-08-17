from functools import lru_cache
from email.utils import parsedate_to_datetime
from typing import Any

from fastapi import FastAPI, Query
from pydantic import BaseModel

from agent.chains import EmailChains
from agent.agent import EmailAgent
from config.settings import settings
from gmail.reader import Email, fetch_emails, fetch_single_email


app = FastAPI(title="TT Mail Assistant Agent 1")
chains = EmailChains()


class ChatRequest(BaseModel):
    message: str


class ChatResponse(BaseModel):
    response: str


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

    if not wants_unread and not wants_latest and not wants_classify:
        return None

    emails = fetch_emails(max_results=5, query="is:unread")
    if not emails:
        return "I did not find unread emails in your Gmail inbox."

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
        lines.append(
            f"- {email.subject} from {email.sender}: {email.short_body(140)}"
        )
    return "\n".join(lines)


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
