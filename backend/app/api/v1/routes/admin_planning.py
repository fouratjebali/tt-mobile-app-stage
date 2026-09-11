from typing import Annotated, Any

from fastapi import APIRouter, Depends, File, Header, Query, UploadFile

from app.api.dependencies import (
    get_current_admin_planning_editor,
    get_current_admin_user,
)
from app.models.auth import User
from app.schemas.admin_planning import (
    AdminPlanningAutomationSettingsRequest,
    AdminPlanningBulkDraftActionRequest,
    AdminPlanningBulkSendDraftsRequest,
    AdminPlanningContactRequest,
    AdminPlanningGenerateDraftsRequest,
    AdminPlanningRegenerateDraftRequest,
    AdminPlanningRejectDraftRequest,
    AdminPlanningResponsableRequest,
    AdminPlanningRunAutomationRequest,
    AdminPlanningSendDraftRequest,
    AdminPlanningUpdateDraftRequest,
)
from app.services.planning_management_gateway import (
    PlanningManagementGateway,
    get_planning_management_gateway,
)


router = APIRouter()


@router.post(
    "/imports/preview",
    summary="Preview planning import",
    description="Uploads planning files to validate extracted sessions before saving.",
)
async def preview_planning_import(
    _: Annotated[User, Depends(get_current_admin_planning_editor)],
    gateway: Annotated[
        PlanningManagementGateway,
        Depends(get_planning_management_gateway),
    ],
    files: Annotated[list[UploadFile], File(...)],
) -> Any:
    return await gateway.post_files("import/preview", files)


@router.post(
    "/imports",
    summary="Import planning files",
    description="Uploads and stores training planning files in the planning service.",
)
async def import_planning_files(
    _: Annotated[User, Depends(get_current_admin_planning_editor)],
    gateway: Annotated[
        PlanningManagementGateway,
        Depends(get_planning_management_gateway),
    ],
    files: Annotated[list[UploadFile], File(...)],
) -> Any:
    return await gateway.post_files("import", files)


@router.get(
    "/imports",
    summary="List planning imports",
    description="Lists stored planning import batches for the admin dashboard.",
)
async def list_planning_imports(
    _: Annotated[User, Depends(get_current_admin_user)],
    gateway: Annotated[
        PlanningManagementGateway,
        Depends(get_planning_management_gateway),
    ],
) -> dict[str, Any]:
    payload = await gateway.get("imports")
    if isinstance(payload, list):
        return {"status": "ok", "count": len(payload), "imports": payload}
    return {"status": "ok", "imports": [], "raw": payload}


@router.get(
    "/imports/{import_id}",
    summary="Get planning import details",
    description="Returns files, sessions and import diagnostics for one import batch.",
)
async def get_planning_import(
    import_id: str,
    _: Annotated[User, Depends(get_current_admin_user)],
    gateway: Annotated[
        PlanningManagementGateway,
        Depends(get_planning_management_gateway),
    ],
) -> Any:
    return await gateway.get(f"imports/{import_id}")


@router.get(
    "/sessions",
    summary="List training sessions",
    description="Lists imported training sessions for calendar and table views.",
)
async def list_training_sessions(
    _: Annotated[User, Depends(get_current_admin_user)],
    gateway: Annotated[
        PlanningManagementGateway,
        Depends(get_planning_management_gateway),
    ],
    import_id: str | None = Query(default=None),
    year: str | None = Query(default=None),
    month: str | None = Query(default=None),
    date_from: str | None = Query(default=None),
    date_to: str | None = Query(default=None),
    status: str | None = Query(default=None),
    domain: str | None = Query(default=None),
    training_mode: str | None = Query(default=None),
    training_type: str | None = Query(default=None),
    cabinet: str | None = Query(default=None),
    location: str | None = Query(default=None),
    responsible: str | None = Query(default=None),
    search: str | None = Query(default=None),
    has_participants: bool | None = Query(default=None),
    missing_contacts: bool | None = Query(default=None),
    sort_by: str = Query(default="start_date"),
    sort_direction: str = Query(default="asc"),
    limit: int = Query(default=100, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
) -> Any:
    return await gateway.get(
        "sessions",
        params={
            "import_id": import_id,
            "year": year,
            "month": month,
            "date_from": date_from,
            "date_to": date_to,
            "session_status": status,
            "domain": domain,
            "training_mode": training_mode,
            "training_type": training_type,
            "cabinet": cabinet,
            "location": location,
            "responsible": responsible,
            "search": search,
            "has_participants": has_participants,
            "missing_contacts": missing_contacts,
            "sort_by": sort_by,
            "sort_direction": sort_direction,
            "limit": limit,
            "offset": offset,
        },
    )


@router.get(
    "/sessions/{session_key}",
    summary="Get training session details",
    description="Returns one training session with participants and metadata.",
)
async def get_training_session(
    session_key: str,
    _: Annotated[User, Depends(get_current_admin_user)],
    gateway: Annotated[
        PlanningManagementGateway,
        Depends(get_planning_management_gateway),
    ],
    import_id: str | None = Query(default=None),
) -> Any:
    return await gateway.get(
        f"sessions/{session_key}",
        params={"import_id": import_id},
    )


@router.get(
    "/missing-contacts",
    summary="List missing responsible contacts",
    description="Lists residences or responsables that still need recipient emails.",
)
async def list_missing_contacts(
    _: Annotated[User, Depends(get_current_admin_user)],
    gateway: Annotated[
        PlanningManagementGateway,
        Depends(get_planning_management_gateway),
    ],
    import_id: str | None = Query(default=None),
    limit: int = Query(default=200, ge=1, le=1000),
) -> Any:
    return await gateway.get(
        "missing-contacts",
        params={"import_id": import_id, "limit": limit},
    )


@router.get(
    "/contact-review",
    summary="List contact matching review",
    description="Lists responsible-contact matches that may need manual review.",
)
async def list_contact_review(
    _: Annotated[User, Depends(get_current_admin_user)],
    gateway: Annotated[
        PlanningManagementGateway,
        Depends(get_planning_management_gateway),
    ],
    import_id: str | None = Query(default=None),
    review_only: bool = Query(default=False),
    limit: int = Query(default=200, ge=1, le=1000),
    offset: int = Query(default=0, ge=0),
) -> Any:
    return await gateway.get(
        "contact-review",
        params={
            "import_id": import_id,
            "review_only": review_only,
            "limit": limit,
            "offset": offset,
        },
    )


@router.post(
    "/contacts/import",
    summary="Import responsible contact directory",
    description="Uploads responsable RH and DIR C/R contact files.",
)
async def import_responsible_contacts(
    _: Annotated[User, Depends(get_current_admin_planning_editor)],
    gateway: Annotated[
        PlanningManagementGateway,
        Depends(get_planning_management_gateway),
    ],
    files: Annotated[list[UploadFile], File(...)],
    import_id: str | None = Query(default=None),
) -> Any:
    return await gateway.post_files(
        "contacts/import",
        files,
        params={"import_id": import_id},
    )


@router.post(
    "/responsables/import",
    summary="Import responsables directory",
    description="Uploads responsable RH and DIR C/R directory files.",
)
async def import_responsables_directory(
    _: Annotated[User, Depends(get_current_admin_planning_editor)],
    gateway: Annotated[
        PlanningManagementGateway,
        Depends(get_planning_management_gateway),
    ],
    files: Annotated[list[UploadFile], File(...)],
    import_id: str | None = Query(default=None),
) -> Any:
    return await gateway.post_files(
        "contacts/import",
        files,
        params={"import_id": import_id},
    )


@router.get(
    "/responsables",
    summary="List responsables directory",
    description="Lists RH and DIR C/R responsables with search and quality filters.",
)
async def list_responsables_directory(
    _: Annotated[User, Depends(get_current_admin_user)],
    gateway: Annotated[
        PlanningManagementGateway,
        Depends(get_planning_management_gateway),
    ],
    search: str | None = Query(default=None),
    role: str | None = Query(default=None),
    residence: str | None = Query(default=None),
    direction: str | None = Query(default=None),
    has_email: bool | None = Query(default=None),
    duplicate_emails: bool | None = Query(default=None),
    source_file: str | None = Query(default=None),
    limit: int = Query(default=200, ge=1, le=1000),
    offset: int = Query(default=0, ge=0),
) -> Any:
    return await gateway.get(
        "responsables",
        params={
            "search": search,
            "role": role,
            "residence": residence,
            "direction": direction,
            "has_email": has_email,
            "duplicate_emails": duplicate_emails,
            "source_file": source_file,
            "limit": limit,
            "offset": offset,
        },
    )


@router.post(
    "/responsables",
    summary="Save responsable directory contact",
    description="Creates or updates one RH or DIR C/R responsable contact.",
)
async def save_responsable_directory_contact(
    request: AdminPlanningResponsableRequest,
    _: Annotated[User, Depends(get_current_admin_planning_editor)],
    gateway: Annotated[
        PlanningManagementGateway,
        Depends(get_planning_management_gateway),
    ],
) -> Any:
    return await gateway.post_json(
        "responsables",
        request.model_dump(),
    )


@router.get(
    "/responsables/{contact_key}",
    summary="Get responsable directory contact",
    description="Returns one RH or DIR C/R responsable contact by contact key.",
)
async def get_responsable_directory_contact(
    contact_key: str,
    _: Annotated[User, Depends(get_current_admin_user)],
    gateway: Annotated[
        PlanningManagementGateway,
        Depends(get_planning_management_gateway),
    ],
) -> Any:
    return await gateway.get(f"responsables/{contact_key}")


@router.delete(
    "/responsables/{contact_key}",
    summary="Delete responsable directory contact",
    description="Deletes one RH or DIR C/R responsable contact.",
)
async def delete_responsable_directory_contact(
    contact_key: str,
    _: Annotated[User, Depends(get_current_admin_planning_editor)],
    gateway: Annotated[
        PlanningManagementGateway,
        Depends(get_planning_management_gateway),
    ],
) -> Any:
    return await gateway.delete(f"responsables/{contact_key}")


@router.get(
    "/contacts",
    summary="List responsible contacts",
    description="Lists known responsible contacts used for training emails.",
)
async def list_responsible_contacts(
    _: Annotated[User, Depends(get_current_admin_user)],
    gateway: Annotated[
        PlanningManagementGateway,
        Depends(get_planning_management_gateway),
    ],
    limit: int = Query(default=200, ge=1, le=1000),
    offset: int = Query(default=0, ge=0),
) -> Any:
    return await gateway.get("contacts", params={"limit": limit, "offset": offset})


@router.post(
    "/contacts",
    summary="Save responsible contact",
    description="Creates or updates one responsible contact.",
)
async def save_responsible_contact(
    request: AdminPlanningContactRequest,
    _: Annotated[User, Depends(get_current_admin_planning_editor)],
    gateway: Annotated[
        PlanningManagementGateway,
        Depends(get_planning_management_gateway),
    ],
) -> Any:
    return await gateway.post_json(
        "contacts",
        request.model_dump(),
    )


@router.post(
    "/contacts/apply",
    summary="Apply contact mapping",
    description="Applies known responsible contacts to imported participants.",
)
async def apply_contact_mapping(
    _: Annotated[User, Depends(get_current_admin_planning_editor)],
    gateway: Annotated[
        PlanningManagementGateway,
        Depends(get_planning_management_gateway),
    ],
    import_id: str | None = Query(default=None),
) -> Any:
    return await gateway.post_json(
        "contacts/apply",
        {},
        params={"import_id": import_id},
    )


@router.get(
    "/automation/settings",
    summary="Get planning automation settings",
    description="Returns default automation settings for draft generation.",
)
async def get_automation_settings(
    _: Annotated[User, Depends(get_current_admin_user)],
    gateway: Annotated[
        PlanningManagementGateway,
        Depends(get_planning_management_gateway),
    ],
) -> Any:
    return await gateway.get("automation/settings")


@router.patch(
    "/automation/settings",
    summary="Update planning automation settings",
    description="Updates default automation settings for draft generation.",
)
async def update_automation_settings(
    request: AdminPlanningAutomationSettingsRequest,
    _: Annotated[User, Depends(get_current_admin_planning_editor)],
    gateway: Annotated[
        PlanningManagementGateway,
        Depends(get_planning_management_gateway),
    ],
) -> Any:
    return await gateway.patch_json(
        "automation/settings",
        request.model_dump(exclude_none=True),
    )


@router.post(
    "/automation/run",
    summary="Run planning automation",
    description="Runs contact mapping and draft generation for training sessions.",
)
async def run_planning_automation(
    request: AdminPlanningRunAutomationRequest,
    current_user: Annotated[User, Depends(get_current_admin_planning_editor)],
    gateway: Annotated[
        PlanningManagementGateway,
        Depends(get_planning_management_gateway),
    ],
) -> Any:
    payload = request.model_dump(exclude_none=True)
    payload["requested_by"] = request.requested_by or current_user.email
    return await gateway.post_json(
        "automation/run",
        payload,
    )


@router.get(
    "/automation/jobs",
    summary="List planning automation jobs",
    description="Lists automation runs with filters for admin monitoring.",
)
async def list_planning_automation_jobs(
    _: Annotated[User, Depends(get_current_admin_user)],
    gateway: Annotated[
        PlanningManagementGateway,
        Depends(get_planning_management_gateway),
    ],
    import_id: str | None = Query(default=None),
    job_status: str | None = Query(default=None),
    job_type: str | None = Query(default=None),
    limit: int = Query(default=100, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
) -> Any:
    return await gateway.get(
        "automation/jobs",
        params={
            "import_id": import_id,
            "job_status": job_status,
            "job_type": job_type,
            "limit": limit,
            "offset": offset,
        },
    )


@router.get(
    "/automation/jobs/{job_id}",
    summary="Get planning automation job",
    description="Returns one automation run with its captured result and logs.",
)
async def get_planning_automation_job(
    job_id: int,
    _: Annotated[User, Depends(get_current_admin_user)],
    gateway: Annotated[
        PlanningManagementGateway,
        Depends(get_planning_management_gateway),
    ],
) -> Any:
    return await gateway.get(f"automation/jobs/{job_id}")


@router.get(
    "/automation/jobs/{job_id}/logs",
    summary="List planning automation job logs",
    description="Returns step logs for one planning automation run.",
)
async def list_planning_automation_job_logs(
    job_id: int,
    _: Annotated[User, Depends(get_current_admin_user)],
    gateway: Annotated[
        PlanningManagementGateway,
        Depends(get_planning_management_gateway),
    ],
    limit: int = Query(default=200, ge=1, le=1000),
    offset: int = Query(default=0, ge=0),
) -> Any:
    return await gateway.get(
        f"automation/jobs/{job_id}/logs",
        params={"limit": limit, "offset": offset},
    )


@router.post(
    "/drafts/generate",
    summary="Generate training email drafts",
    description="Generates responsible-recipient training email drafts.",
)
async def generate_training_drafts(
    request: AdminPlanningGenerateDraftsRequest,
    _: Annotated[User, Depends(get_current_admin_planning_editor)],
    gateway: Annotated[
        PlanningManagementGateway,
        Depends(get_planning_management_gateway),
    ],
) -> Any:
    return await gateway.post_json(
        "drafts/generate",
        request.model_dump(),
    )


@router.get(
    "/drafts",
    summary="List training email drafts",
    description="Lists generated training emails waiting for review or sending.",
)
async def list_training_drafts(
    _: Annotated[User, Depends(get_current_admin_user)],
    gateway: Annotated[
        PlanningManagementGateway,
        Depends(get_planning_management_gateway),
    ],
    import_id: str | None = Query(default=None),
    session_key: str | None = Query(default=None),
    draft_status: str | None = Query(default=None),
    email_type: str | None = Query(default=None),
    limit: int = Query(default=100, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
) -> Any:
    return await gateway.get(
        "drafts",
        params={
            "import_id": import_id,
            "session_key": session_key,
            "draft_status": draft_status,
            "email_type": email_type,
            "limit": limit,
            "offset": offset,
        },
    )


@router.get(
    "/drafts/review",
    summary="Get training draft review queue",
    description="Lists training drafts with review summary counts for dashboard queues.",
)
async def get_training_draft_review(
    _: Annotated[User, Depends(get_current_admin_user)],
    gateway: Annotated[
        PlanningManagementGateway,
        Depends(get_planning_management_gateway),
    ],
    import_id: str | None = Query(default=None),
    session_key: str | None = Query(default=None),
    draft_status: str | None = Query(default=None),
    email_type: str | None = Query(default=None),
    limit: int = Query(default=100, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
) -> Any:
    return await gateway.get(
        "drafts/review",
        params={
            "import_id": import_id,
            "session_key": session_key,
            "draft_status": draft_status,
            "email_type": email_type,
            "limit": limit,
            "offset": offset,
        },
    )


@router.post(
    "/drafts/bulk-action",
    summary="Bulk review training drafts",
    description="Approves, rejects or regenerates selected training email drafts.",
)
async def bulk_review_training_drafts(
    request: AdminPlanningBulkDraftActionRequest,
    _: Annotated[User, Depends(get_current_admin_planning_editor)],
    gateway: Annotated[
        PlanningManagementGateway,
        Depends(get_planning_management_gateway),
    ],
) -> Any:
    return await gateway.post_json(
        "drafts/bulk-action",
        request.model_dump(),
    )


@router.post(
    "/drafts/bulk-send",
    summary="Bulk send approved training drafts",
    description="Sends selected approved drafts after dashboard safety confirmation.",
)
async def bulk_send_training_drafts(
    request: AdminPlanningBulkSendDraftsRequest,
    _: Annotated[User, Depends(get_current_admin_planning_editor)],
    gateway: Annotated[
        PlanningManagementGateway,
        Depends(get_planning_management_gateway),
    ],
    authorization: Annotated[str | None, Header()] = None,
) -> Any:
    return await gateway.post_json(
        "drafts/bulk-send",
        request.model_dump(exclude_none=True),
        authorization=authorization,
    )


@router.get(
    "/send-history",
    summary="List training send history",
    description="Lists sent training emails and errors.",
)
async def list_training_send_history(
    _: Annotated[User, Depends(get_current_admin_user)],
    gateway: Annotated[
        PlanningManagementGateway,
        Depends(get_planning_management_gateway),
    ],
    import_id: str | None = Query(default=None),
    draft_id: int | None = Query(default=None),
    send_status: str | None = Query(default=None),
    limit: int = Query(default=100, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
) -> Any:
    return await gateway.get(
        "send-history",
        params={
            "import_id": import_id,
            "draft_id": draft_id,
            "send_status": send_status,
            "limit": limit,
            "offset": offset,
        },
    )


@router.get(
    "/drafts/{draft_id}",
    summary="Get training email draft",
    description="Returns one generated training email draft.",
)
async def get_training_draft(
    draft_id: int,
    _: Annotated[User, Depends(get_current_admin_user)],
    gateway: Annotated[
        PlanningManagementGateway,
        Depends(get_planning_management_gateway),
    ],
) -> Any:
    return await gateway.get(f"drafts/{draft_id}")


@router.patch(
    "/drafts/{draft_id}",
    summary="Update training email draft",
    description="Updates recipients, subject, body or HTML body before sending.",
)
async def update_training_draft(
    draft_id: int,
    request: AdminPlanningUpdateDraftRequest,
    _: Annotated[User, Depends(get_current_admin_planning_editor)],
    gateway: Annotated[
        PlanningManagementGateway,
        Depends(get_planning_management_gateway),
    ],
) -> Any:
    return await gateway.patch_json(
        f"drafts/{draft_id}",
        request.model_dump(exclude_none=True),
    )


@router.post(
    "/drafts/{draft_id}/regenerate",
    summary="Regenerate training email draft",
    description="Regenerates one draft while preserving its review workflow.",
)
async def regenerate_training_draft(
    draft_id: int,
    request: AdminPlanningRegenerateDraftRequest,
    _: Annotated[User, Depends(get_current_admin_planning_editor)],
    gateway: Annotated[
        PlanningManagementGateway,
        Depends(get_planning_management_gateway),
    ],
) -> Any:
    return await gateway.post_json(
        f"drafts/{draft_id}/regenerate",
        request.model_dump(),
    )


@router.post(
    "/drafts/{draft_id}/approve",
    summary="Approve training email draft",
    description="Marks one draft as approved after human review.",
)
async def approve_training_draft(
    draft_id: int,
    _: Annotated[User, Depends(get_current_admin_planning_editor)],
    gateway: Annotated[
        PlanningManagementGateway,
        Depends(get_planning_management_gateway),
    ],
) -> Any:
    return await gateway.post_json(f"drafts/{draft_id}/approve", {})


@router.post(
    "/drafts/{draft_id}/reject",
    summary="Reject training email draft",
    description="Rejects one draft and stores the reviewer reason.",
)
async def reject_training_draft(
    draft_id: int,
    request: AdminPlanningRejectDraftRequest,
    _: Annotated[User, Depends(get_current_admin_planning_editor)],
    gateway: Annotated[
        PlanningManagementGateway,
        Depends(get_planning_management_gateway),
    ],
) -> Any:
    return await gateway.post_json(
        f"drafts/{draft_id}/reject",
        request.model_dump(),
    )


@router.post(
    "/drafts/{draft_id}/send",
    summary="Send approved training email draft",
    description="Sends one approved draft after explicit dashboard confirmation.",
)
async def send_training_draft(
    draft_id: int,
    request: AdminPlanningSendDraftRequest,
    _: Annotated[User, Depends(get_current_admin_planning_editor)],
    gateway: Annotated[
        PlanningManagementGateway,
        Depends(get_planning_management_gateway),
    ],
    authorization: Annotated[str | None, Header()] = None,
) -> Any:
    return await gateway.post_json(
        f"drafts/{draft_id}/send",
        request.model_dump(exclude_none=True),
        authorization=authorization,
    )
