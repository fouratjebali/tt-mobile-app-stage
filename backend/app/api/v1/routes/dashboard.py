from fastapi import APIRouter, Depends

from app.schemas.dashboard import DashboardExportResponse, DashboardStatsResponse
from app.services.agent_bridge import AgentBridge, get_agent_bridge


router = APIRouter()


@router.get("/stats", response_model=DashboardStatsResponse)
async def dashboard_stats(
    bridge: AgentBridge = Depends(get_agent_bridge),
) -> DashboardStatsResponse:
    result = await bridge.dashboard_stats()
    return DashboardStatsResponse(result=result)


@router.post("/export", response_model=DashboardExportResponse)
async def dashboard_export() -> DashboardExportResponse:
    return DashboardExportResponse(
        status="pending",
        message="Dashboard export endpoint is reserved for the report/PDF export workflow.",
    )
