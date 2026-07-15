from fastapi import APIRouter

from app.core.config import settings
from app.schemas.health import HealthResponse


router = APIRouter()


@router.get("/health", response_model=HealthResponse)
def health() -> HealthResponse:
    return HealthResponse(
        status="ok",
        service="backend",
        version=settings.APP_VERSION,
        agent1_url=settings.AGENT1_URL,
        agent2_url=settings.AGENT2_URL,
    )
