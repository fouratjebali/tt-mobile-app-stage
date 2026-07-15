from fastapi import APIRouter, Depends

from app.schemas.jury import JuryRequest, JuryResponse
from app.services.jury_service import JuryService, get_jury_service


router = APIRouter()


@router.post("/verify", response_model=JuryResponse)
async def verify(
    request: JuryRequest,
    service: JuryService = Depends(get_jury_service),
) -> JuryResponse:
    return await service.verify(request)
