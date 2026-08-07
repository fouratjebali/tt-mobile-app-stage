from fastapi import APIRouter, Depends

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
    result = await bridge.generate_bulk(
        recipients=request.recipients_payload(),
        topic=request.topic,
        instructions=request.instructions,
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
