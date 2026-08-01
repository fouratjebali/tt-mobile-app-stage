from typing import Any

from pydantic import BaseModel, Field


class DashboardStatsResponse(BaseModel):
    processed_count: int = 0
    urgent_count: int = 0
    review_count: int = 0
    sent_count: int = 0
    categories: dict[str, int] = Field(default_factory=dict)
    metadata: dict[str, Any] = Field(default_factory=dict)
    raw_result: str | None = None


class DashboardExportResponse(BaseModel):
    status: str
    message: str
