from pydantic import BaseModel


class DashboardStatsResponse(BaseModel):
    result: str


class DashboardExportResponse(BaseModel):
    status: str
    message: str
