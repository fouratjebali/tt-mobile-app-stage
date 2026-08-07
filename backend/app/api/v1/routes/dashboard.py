from fastapi import APIRouter, Depends

from app.schemas.dashboard import DashboardExportResponse, DashboardStatsResponse
from app.services.agent_bridge import AgentBridge, get_agent_bridge


router = APIRouter()


@router.get(
    "/stats",
    response_model=DashboardStatsResponse,
    summary="Get dashboard statistics",
    description=(
        "Builds aggregated email activity statistics for the mobile dashboard."
    ),
)
async def dashboard_stats(
    bridge: AgentBridge = Depends(get_agent_bridge),
) -> DashboardStatsResponse:
    result = await bridge.dashboard_stats()
    payload = result.payload
    return DashboardStatsResponse(
        processed_count=int(payload.get("processed_count", 0) or 0),
        urgent_count=int(payload.get("urgent_count", 0) or 0),
        review_count=int(payload.get("review_count", 0) or 0),
        sent_count=int(payload.get("sent_count", 0) or 0),
        categories=_to_categories(payload.get("categories")),
        metadata={
            key: value
            for key, value in payload.items()
            if key
            not in {
                "processed_count",
                "urgent_count",
                "review_count",
                "sent_count",
                "categories",
            }
        },
        raw_result=result.raw_result,
    )


@router.post(
    "/export",
    response_model=DashboardExportResponse,
    summary="Prepare dashboard export",
    description=(
        "Reserved endpoint for future PDF/report export of dashboard metrics."
    ),
)
async def dashboard_export() -> DashboardExportResponse:
    return DashboardExportResponse(
        status="pending",
        message="Dashboard export endpoint is reserved for the report/PDF export workflow.",
    )


def _to_categories(value) -> dict[str, int]:
    if not isinstance(value, dict):
        return {}

    categories: dict[str, int] = {}
    for key, count in value.items():
        try:
            categories[str(key)] = int(count)
        except (TypeError, ValueError):
            categories[str(key)] = 0

    return categories
