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


class DashboardExportRequest(BaseModel):
    period: str = '7d'


class DashboardExportResponse(BaseModel):
    status: str
    message: str
    period: str = '7d'
    file_name: str | None = None
    file_size_bytes: int | None = None
    generated_at: str | None = None
