from fastapi import APIRouter, Depends

from app.schemas.jury import JuryRequest, JuryResponse
from app.services.jury_service import JuryService, get_jury_service


router = APIRouter()


@router.post(
    "/verify",
    response_model=JuryResponse,
    summary="Verify an AI email decision",
    description=(
        "Sends the email, agent analysis and proposed response to the jury "
        "agent, then returns an independent verdict with confidence score."
    ),
)
async def verify(
    request: JuryRequest,
    service: JuryService = Depends(get_jury_service),
) -> JuryResponse:
    return await service.verify(request)
