from fastapi import APIRouter, Depends

from app.schemas.bulk import BulkRequest, BulkResponse
from app.services.agent_bridge import AgentBridge, get_agent_bridge


router = APIRouter()


@router.post("/generate", response_model=BulkResponse)
async def generate_bulk(
    request: BulkRequest,
    bridge: AgentBridge = Depends(get_agent_bridge),
) -> BulkResponse:
    result = await bridge.generate_bulk(
        recipients=request.recipients_payload(),
        topic=request.topic,
        instructions=request.instructions,
    )
    return BulkResponse(result=result)


@router.post("/send", response_model=BulkResponse)
async def send_bulk(
    request: BulkRequest,
    bridge: AgentBridge = Depends(get_agent_bridge),
) -> BulkResponse:
    result = await bridge.send_bulk(
        recipients=request.recipients_payload(),
        topic=request.topic,
        instructions=request.instructions,
    )
    return BulkResponse(result=result)
