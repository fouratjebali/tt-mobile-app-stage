from typing import Any

from fastapi import APIRouter, Depends, HTTPException

from app.schemas.bulk import BulkRequest, BulkResponse
from app.services.agent_bridge import AgentBridge, get_agent_bridge
from app.utils.json_tools import list_from_payload


router = APIRouter()


@router.post(
    "/generate",
    response_model=BulkResponse,
    summary="Generate bulk email drafts",
    description=(
        "Generates personalized emails for multiple recipients without "
        "sending them. Used for preview and review in the mobile app."
    ),
)
async def generate_bulk(
    request: BulkRequest,
    bridge: AgentBridge = Depends(get_agent_bridge),
) -> BulkResponse:
    recipients = request.recipients_payload()
    try:
        result = await bridge.generate_bulk(
            recipients=recipients,
            topic=request.topic,
            instructions=request.instructions,
        )
    except HTTPException as exc:
        if exc.status_code != 502:
            raise
        return _fallback_bulk_response(
            recipients=recipients,
            topic=request.topic,
            instructions=request.instructions,
            raw_result=str(exc.detail),
        )

    return _to_bulk_response(result.payload, result.raw_result)


@router.post(
    "/send",
    response_model=BulkResponse,
    summary="Send bulk emails",
    description=(
        "Generates and sends personalized emails to the provided recipients "
        "through the email agent and Gmail sender."
    ),
)
async def send_bulk(
    request: BulkRequest,
    bridge: AgentBridge = Depends(get_agent_bridge),
) -> BulkResponse:
    result = await bridge.send_bulk(
        recipients=request.recipients_payload(),
        topic=request.topic,
        instructions=request.instructions,
    )
    return _to_bulk_response(result.payload, result.raw_result)


@router.post(
    "/send-drafts",
    response_model=BulkResponse,
    summary="Send edited group drafts",
    description="Sends edited draft emails after the mobile preview step.",
)
async def send_edited_bulk_drafts(
    request: dict[str, list[dict[str, Any]]],
    bridge: AgentBridge = Depends(get_agent_bridge),
) -> BulkResponse:
    result = await bridge.send_bulk_drafts(drafts=request.get("drafts", []))
    return _to_bulk_response(result.payload, result.raw_result)


def _to_bulk_response(payload: dict, raw_result: str) -> BulkResponse:
    details = list_from_payload(payload, "details", "results", "emails")
    return BulkResponse(
        status=str(payload.get("status", "ok")),
        total=int(payload.get("total", len(details)) or 0),
        sent=int(payload.get("sent", 0) or 0),
        errors=int(payload.get("errors", 0) or 0),
        details=details,
        raw_result=raw_result,
    )


def _fallback_bulk_response(
    *,
    recipients: list[dict[str, Any]],
    topic: str,
    instructions: str,
    raw_result: str,
) -> BulkResponse:
    details = []
    language = _fallback_language(instructions)
    short = "short" in instructions.lower() or "brief" in instructions.lower()
    for index, recipient in enumerate(recipients, start=1):
        name = str(recipient.get("name") or "there").strip()
        email = str(recipient.get("email") or "").strip()
        role = str(recipient.get("role") or "Recipient").strip()
        body = _fallback_body(name=name, topic=topic, language=language, short=short)
        details.append(
            {
                "id": f"draft-{index}",
                "to": email,
                "recipient": name,
                "subject": topic,
                "body": body,
                "status": "draft",
                "personalization_note": f"Fallback draft for {role}.",
            }
        )

    return BulkResponse(
        status="fallback",
        total=len(details),
        sent=0,
        errors=0,
        details=details,
        raw_result=raw_result,
    )


def _fallback_language(instructions: str) -> str:
    return "French" if "french" in instructions.lower() else "English"


def _fallback_body(*, name: str, topic: str, language: str, short: bool) -> str:
    if language == "French":
        if short:
            return (
                f"Bonjour {name},\n\n"
                f"Je vous contacte au sujet de {topic}.\n\n"
                "Pouvez-vous me confirmer votre retour ?\n\n"
                "Cordialement,"
            )
        return (
            f"Bonjour {name},\n\n"
            f"Je vous contacte au sujet de {topic}. "
            "Je souhaitais partager ce message avec vous et recueillir votre retour.\n\n"
            "N'hesitez pas a me dire si vous avez besoin de plus d'informations.\n\n"
            "Cordialement,"
        )

    if short:
        return (
            f"Hello {name},\n\n"
            f"I am contacting you about {topic}.\n\n"
            "Please let me know if this works for you.\n\n"
            "Best regards,"
        )
    return (
        f"Hello {name},\n\n"
        f"I am contacting you about {topic}. "
        "I wanted to share this with you and hear your thoughts.\n\n"
        "Please let me know if you need any additional details.\n\n"
        "Best regards,"
    )
