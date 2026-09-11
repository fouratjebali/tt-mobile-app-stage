from typing import Any

from pydantic import BaseModel, Field


class AdminPlanningResponse(BaseModel):
    status: str = "ok"
    data: Any


class AdminPlanningGenerateDraftsRequest(BaseModel):
    import_id: str | None = None
    session_key: str | None = None
    email_type: str = "auto"
    include_population: bool = True
    limit: int = Field(default=100, ge=1, le=500)
    replace_existing: bool = False


class AdminPlanningRunAutomationRequest(BaseModel):
    import_id: str | None = None
    email_type: str | None = None
    include_population: bool | None = None
    limit: int | None = Field(default=None, ge=1, le=1000)
    replace_existing: bool = False


class AdminPlanningAutomationSettingsRequest(BaseModel):
    auto_run_after_import: bool | None = None
    default_email_type: str | None = None
    include_population: bool | None = None
    max_drafts_per_run: int | None = Field(default=None, ge=1, le=500)


class AdminPlanningContactRequest(BaseModel):
    matricule: str = ""
    full_name: str = ""
    email: str = Field(min_length=3)
    direction: str = ""
    hr_responsible: str = ""


class AdminPlanningUpdateDraftRequest(BaseModel):
    subject: str | None = None
    body: str | None = None
    html_body: str | None = None
    recipients: list[str] | None = None
    cc: list[str] | None = None


class AdminPlanningRegenerateDraftRequest(BaseModel):
    email_type: str = "auto"
    include_population: bool = True


class AdminPlanningRejectDraftRequest(BaseModel):
    reason: str = ""


class AdminPlanningSendDraftRequest(BaseModel):
    confirmed: bool = False
    confirmed_recipient_count: int | None = Field(default=None, ge=0)
    confirmed_subject: str = ""
