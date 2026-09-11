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
    requested_by: str | None = None


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


class AdminPlanningResponsableRequest(BaseModel):
    role: str = Field(default="rh", pattern="^(rh|dir|director|directeur)$")
    residence: str = Field(min_length=1)
    email: str = Field(min_length=3)
    full_name: str = ""
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


class AdminPlanningBulkDraftActionRequest(BaseModel):
    draft_ids: list[int] = Field(min_length=1, max_length=100)
    action: str = Field(pattern="^(approve|reject|regenerate)$")
    reason: str = ""
    email_type: str = "auto"
    include_population: bool = True


class AdminPlanningBulkSendDraftsRequest(BaseModel):
    draft_ids: list[int] = Field(min_length=1, max_length=50)
    confirmed: bool = False
    confirmed_draft_count: int | None = Field(default=None, ge=0)
    confirmed_total_recipient_count: int | None = Field(default=None, ge=0)
