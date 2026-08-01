from fastapi import APIRouter
from fastapi import Depends
from sqlalchemy.orm import Session

from app.core.config import settings
from app.db.session import get_db
from app.schemas.health import HealthResponse, HealthServicesResponse
from app.services.health_service import HealthService


router = APIRouter()


@router.get("/health", response_model=HealthResponse)
def health() -> HealthResponse:
    return HealthResponse(
        status="ok",
        service="backend",
        version=settings.APP_VERSION,
        agent1_url=settings.AGENT1_URL,
        agent2_url=settings.AGENT2_URL,
        sentiment_agent_url=settings.SENTIMENT_AGENT_URL,
    )


@router.get("/health/services", response_model=HealthServicesResponse)
async def services_health(db: Session = Depends(get_db)) -> HealthServicesResponse:
    return await HealthService(db).check_services()
