from datetime import datetime
import json
from typing import Annotated, Any

from fastapi import APIRouter, Depends, File, Header, HTTPException, Query, UploadFile
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.dependencies import (
    get_current_admin_planning_editor,
    get_current_admin_user,
)
from app.db.session import SessionLocal, get_db
from app.models.audit import AuditLog
from app.models.auth import User
from app.repositories.audit_repository import AuditRepository
from app.schemas.admin_planning import (
    AdminPlanningAutomationSettingsRequest,
    AdminPlanningBulkDraftActionRequest,
    AdminPlanningBulkSendDraftsRequest,
    AdminPlanningContactRequest,
    AdminPlanningGenerateDraftsRequest,
    AdminPlanningRegenerateDraftRequest,
    AdminPlanningRejectDraftRequest,
    AdminPlanningResponsableDirectoryRequest,
    AdminPlanningRunAutomationRequest,
    AdminPlanningSendDraftRequest,
    AdminPlanningUpdateDraftRequest,
)
from app.services.planning_management_gateway import (
    PlanningManagementGateway,
    get_planning_management_gateway,
)
from app.services.responsable_directory_service import ResponsableDirectoryService


router = APIRouter()


@router.get(
    "/analytics/overview",
    summary="Get planning analytics overview",
    description="Returns import, file, draft, send and automation counters for dashboard cards.",
)
async def get_planning_analytics_overview(
    _: Annotated[User, Depends(get_current_admin_user)],
    gateway: Annotated[
        PlanningManagementGateway,
        Depends(get_planning_management_gateway),
    ],
    db: Annotated[Session, Depends(get_db)],
    date_from: str | None = Query(default=None),
    date_to: str | None = Query(default=None),
) -> dict[str, Any]:
    payload = await gateway.get(
        "analytics/overview",
        params={"date_from": date_from, "date_to": date_to},
    )
    if isinstance(payload, dict):
        payload["admin_usage"] = _planning_usage_summary(
            db,
            date_from=_parse_admin_date(date_from),
            date_to=_parse_admin_date(date_to),
        )
    return payload


@router.get(
    "/analytics/files",
    summary="Get planning file analytics",
    description="Returns treated Excel/CSV file counts by status and recent imported files.",
)
async def get_planning_file_analytics(
    _: Annotated[User, Depends(get_current_admin_user)],
    gateway: Annotated[
        PlanningManagementGateway,
        Depends(get_planning_management_gateway),
    ],
    date_from: str | None = Query(default=None),
    date_to: str | None = Query(default=None),
    limit: int = Query(default=20, ge=1, le=100),
) -> Any:
    return await gateway.get(
        "analytics/files",
        params={"date_from": date_from, "date_to": date_to, "limit": limit},
    )


@router.get(
    "/analytics/drafts",
    summary="Get planning draft analytics",
    description="Returns draft counts by status, type, day and import batch.",
)
async def get_planning_draft_analytics(
    _: Annotated[User, Depends(get_current_admin_user)],
    gateway: Annotated[
        PlanningManagementGateway,
        Depends(get_planning_management_gateway),
    ],
    date_from: str | None = Query(default=None),
    date_to: str | None = Query(default=None),
    limit: int = Query(default=20, ge=1, le=100),
) -> Any:
    return await gateway.get(
        "analytics/drafts",
        params={"date_from": date_from, "date_to": date_to, "limit": limit},
    )


@router.get(
    "/analytics/users",
    summary="Get planning usage by admin user",
    description="Groups planning imports, draft generation and review actions by dashboard user.",
)
def get_planning_user_analytics(
    _: Annotated[User, Depends(get_current_admin_user)],
    db: Annotated[Session, Depends(get_db)],
    date_from: datetime | None = Query(default=None),
    date_to: datetime | None = Query(default=None),
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
) -> dict[str, Any]:
    return _planning_usage_by_user(
        db,
        date_from=date_from,
        date_to=date_to,
        limit=limit,
        offset=offset,
    )


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
    current_user: Annotated[User, Depends(get_current_admin_planning_editor)],
    gateway: Annotated[
        PlanningManagementGateway,
        Depends(get_planning_management_gateway),
    ],
    files: Annotated[list[UploadFile], File(...)],
) -> Any:
    result = await gateway.post_files("import", files)
    _record_planning_audit(current_user, "admin.planning.import.create", result=result)
    return result


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
    current_user: Annotated[User, Depends(get_current_admin_planning_editor)],
    gateway: Annotated[
        PlanningManagementGateway,
        Depends(get_planning_management_gateway),
    ],
    files: Annotated[list[UploadFile], File(...)],
    import_id: str | None = Query(default=None),
) -> Any:
    result = await gateway.post_files(
        "contacts/import",
        files,
        params={"import_id": import_id},
    )
    _record_planning_audit(
        current_user,
        "admin.planning.contacts.import",
        resource_id=import_id or "",
        result=result,
    )
    return result


@router.post(
    "/responsables/import",
    summary="Import responsables directory",
    description="Uploads responsable RH and DIR C/R directory files.",
)
async def import_responsables_directory(
    current_user: Annotated[User, Depends(get_current_admin_planning_editor)],
    gateway: Annotated[
        PlanningManagementGateway,
        Depends(get_planning_management_gateway),
    ],
    files: Annotated[list[UploadFile], File(...)],
    import_id: str | None = Query(default=None),
) -> Any:
    result = await gateway.post_files(
        "contacts/import",
        files,
        params={"import_id": import_id},
    )
    _record_planning_audit(
        current_user,
        "admin.planning.responsables.import",
        resource_id=import_id or "",
        result=result,
    )
    return result


@router.get(
    "/responsables",
    summary="List responsables directory",
    description="Lists RH and DIR C/R responsables with search and quality filters.",
)
async def list_responsables_directory(
    _: Annotated[User, Depends(get_current_admin_user)],
    db: Annotated[Session, Depends(get_db)],
    search: str | None = Query(default=None),
    role: str | None = Query(default=None),
    residence: str | None = Query(default=None),
    direction: str | None = Query(default=None),
    has_email: bool | None = Query(default=None),
    duplicate_emails: bool | None = Query(default=None),
    source_file: str | None = Query(default=None),
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
) -> Any:
    combined_search = " ".join(
        value
        for value in (search, role, direction, source_file)
        if value is not None and str(value).strip()
    )
    return ResponsableDirectoryService(db).list_responsables(
        search=combined_search or None,
        grande_residence=residence,
        limit=limit,
        offset=offset,
    )


@router.post(
    "/responsables",
    summary="Create responsable",
    description="Creates one responsable in the backend responsable directory.",
)
async def create_responsable_directory_entry(
    request: AdminPlanningResponsableDirectoryRequest,
    current_user: Annotated[User, Depends(get_current_admin_planning_editor)],
    db: Annotated[Session, Depends(get_db)],
) -> Any:
    try:
        responsable = ResponsableDirectoryService(db).create_responsable(
            nom_complet=request.nom_complet,
            fonction=request.fonction,
            grande_residence=request.grande_residence,
        )
    except ValueError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
    _record_responsable_audit(
        db,
        current_user,
        "admin.planning.responsable.create",
        "Created responsable",
        resource_id=responsable["id"],
        metadata={"before": None, "after": responsable, "changed_fields": []},
    )
    return {"status": "ok", "responsable": responsable}


@router.get(
    "/responsables/{contact_key}",
    summary="Get responsable",
    description="Returns one responsable from the backend responsable directory.",
)
async def get_responsable_directory_contact(
    contact_key: str,
    _: Annotated[User, Depends(get_current_admin_user)],
    db: Annotated[Session, Depends(get_db)],
) -> Any:
    responsable = ResponsableDirectoryService(db).get_responsable(contact_key)
    if responsable is None:
        raise HTTPException(status_code=404, detail="Responsable not found.")
    return {"status": "ok", "responsable": responsable}


@router.patch(
    "/responsables/{contact_key}",
    summary="Update responsable",
    description="Updates one responsable in the backend responsable directory.",
)
async def update_responsable_directory_entry(
    contact_key: str,
    request: AdminPlanningResponsableDirectoryRequest,
    current_user: Annotated[User, Depends(get_current_admin_planning_editor)],
    db: Annotated[Session, Depends(get_db)],
) -> Any:
    before = ResponsableDirectoryService(db).get_responsable(contact_key)
    if before is None:
        raise HTTPException(status_code=404, detail="Responsable not found.")
    try:
        responsable = ResponsableDirectoryService(db).update_responsable(
            contact_key,
            nom_complet=request.nom_complet,
            fonction=request.fonction,
            grande_residence=request.grande_residence,
        )
    except ValueError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
    if responsable is None:
        raise HTTPException(status_code=404, detail="Responsable not found.")
    _record_responsable_audit(
        db,
        current_user,
        "admin.planning.responsable.update",
        "Updated responsable",
        resource_id=contact_key,
        metadata={
            "before": before,
            "after": responsable,
            "changed_fields": _changed_fields(before, responsable),
        },
    )
    return {"status": "ok", "responsable": responsable}


@router.delete(
    "/responsables/{contact_key}",
    summary="Delete responsable",
    description="Deletes one responsable from the backend responsable directory.",
)
async def delete_responsable_directory_contact(
    contact_key: str,
    current_user: Annotated[User, Depends(get_current_admin_planning_editor)],
    db: Annotated[Session, Depends(get_db)],
) -> Any:
    before = ResponsableDirectoryService(db).get_responsable(contact_key)
    deleted = ResponsableDirectoryService(db).delete_responsable(contact_key)
    if not deleted:
        raise HTTPException(status_code=404, detail="Responsable not found.")
    _record_responsable_audit(
        db,
        current_user,
        "admin.planning.responsable.delete",
        "Deleted responsable",
        resource_id=contact_key,
        metadata={"before": before, "after": None, "changed_fields": []},
    )
    return {"status": "ok", "deleted": True, "id": contact_key}


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
    current_user: Annotated[User, Depends(get_current_admin_planning_editor)],
    gateway: Annotated[
        PlanningManagementGateway,
        Depends(get_planning_management_gateway),
    ],
) -> Any:
    result = await gateway.post_json(
        "contacts",
        request.model_dump(),
    )
    _record_planning_audit(
        current_user,
        "admin.planning.contact.save",
        resource_id=request.matricule or request.full_name,
        result=result,
    )
    return result


@router.post(
    "/contacts/apply",
    summary="Apply contact mapping",
    description="Applies known responsible contacts to imported participants.",
)
async def apply_contact_mapping(
    current_user: Annotated[User, Depends(get_current_admin_planning_editor)],
    gateway: Annotated[
        PlanningManagementGateway,
        Depends(get_planning_management_gateway),
    ],
    import_id: str | None = Query(default=None),
) -> Any:
    result = await gateway.post_json(
        "contacts/apply",
        {},
        params={"import_id": import_id},
    )
    _record_planning_audit(
        current_user,
        "admin.planning.contacts.apply",
        resource_id=import_id or "",
        result=result,
    )
    return result


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
    current_user: Annotated[User, Depends(get_current_admin_planning_editor)],
    gateway: Annotated[
        PlanningManagementGateway,
        Depends(get_planning_management_gateway),
    ],
) -> Any:
    payload = request.model_dump(exclude_none=True)
    if "enabled" in payload and "auto_run_after_import" not in payload:
        payload["auto_run_after_import"] = payload.pop("enabled")
    payload.pop("schedule", None)
    payload.pop("timezone", None)
    result = await gateway.patch_json(
        "automation/settings",
        payload,
    )
    _record_planning_audit(
        current_user,
        "admin.planning.automation.settings.update",
        result=result,
    )
    return result


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
    db: Session = Depends(get_db),
) -> Any:
    payload = request.model_dump(exclude_none=True)
    payload["requested_by"] = request.requested_by or current_user.email
    payload["responsables"] = _planning_responsables_payload(db)
    result = await gateway.post_json(
        "automation/run",
        payload,
    )
    _record_planning_audit(
        current_user,
        "admin.planning.automation.run",
        resource_id=payload.get("import_id", ""),
        result=result,
    )
    return result


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
    current_user: Annotated[User, Depends(get_current_admin_planning_editor)],
    gateway: Annotated[
        PlanningManagementGateway,
        Depends(get_planning_management_gateway),
    ],
    db: Session = Depends(get_db),
) -> Any:
    payload = request.model_dump(exclude_none=True)
    payload["responsables"] = _planning_responsables_payload(db)
    result = await gateway.post_json(
        "drafts/generate",
        payload,
    )
    _record_planning_audit(
        current_user,
        "admin.planning.drafts.generate",
        resource_id=request.import_id or request.session_key or "",
        result=result,
    )
    return result


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
    current_user: Annotated[User, Depends(get_current_admin_planning_editor)],
    gateway: Annotated[
        PlanningManagementGateway,
        Depends(get_planning_management_gateway),
    ],
) -> Any:
    payload = request.model_dump()
    if request.review_notes and not payload.get("reason"):
        payload["reason"] = request.review_notes
    payload.pop("review_notes", None)
    result = await gateway.post_json(
        "drafts/bulk-action",
        payload,
    )
    _record_planning_audit(
        current_user,
        f"admin.planning.drafts.bulk.{request.action}",
        resource_id=",".join(str(draft_id) for draft_id in request.draft_ids),
        result=result,
    )
    return result


@router.post(
    "/drafts/bulk-send",
    summary="Bulk send approved training drafts",
    description="Sends selected approved drafts after dashboard safety confirmation.",
)
async def bulk_send_training_drafts(
    request: AdminPlanningBulkSendDraftsRequest,
    current_user: Annotated[User, Depends(get_current_admin_planning_editor)],
    gateway: Annotated[
        PlanningManagementGateway,
        Depends(get_planning_management_gateway),
    ],
    authorization: Annotated[str | None, Header()] = None,
) -> Any:
    payload = request.model_dump(exclude_none=True)
    if payload.get("confirmation") == "SEND_APPROVED_DRAFT":
        payload["confirmed"] = True
    payload.pop("confirmation", None)
    result = await gateway.post_json(
        "drafts/bulk-send",
        payload,
        authorization=authorization,
    )
    _record_planning_audit(
        current_user,
        "admin.planning.drafts.bulk.send",
        resource_id=",".join(str(draft_id) for draft_id in request.draft_ids),
        result=result,
    )
    return result


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
    current_user: Annotated[User, Depends(get_current_admin_planning_editor)],
    gateway: Annotated[
        PlanningManagementGateway,
        Depends(get_planning_management_gateway),
    ],
) -> Any:
    result = await gateway.patch_json(
        f"drafts/{draft_id}",
        request.model_dump(exclude_none=True),
    )
    _record_planning_audit(
        current_user,
        "admin.planning.draft.update",
        resource_id=str(draft_id),
        result=result,
    )
    return result


@router.post(
    "/drafts/{draft_id}/regenerate",
    summary="Regenerate training email draft",
    description="Regenerates one draft while preserving its review workflow.",
)
async def regenerate_training_draft(
    draft_id: int,
    request: AdminPlanningRegenerateDraftRequest,
    current_user: Annotated[User, Depends(get_current_admin_planning_editor)],
    gateway: Annotated[
        PlanningManagementGateway,
        Depends(get_planning_management_gateway),
    ],
) -> Any:
    result = await gateway.post_json(
        f"drafts/{draft_id}/regenerate",
        request.model_dump(),
    )
    _record_planning_audit(
        current_user,
        "admin.planning.draft.regenerate",
        resource_id=str(draft_id),
        result=result,
    )
    return result


@router.post(
    "/drafts/{draft_id}/approve",
    summary="Approve training email draft",
    description="Marks one draft as approved after human review.",
)
async def approve_training_draft(
    draft_id: int,
    current_user: Annotated[User, Depends(get_current_admin_planning_editor)],
    gateway: Annotated[
        PlanningManagementGateway,
        Depends(get_planning_management_gateway),
    ],
) -> Any:
    result = await gateway.post_json(f"drafts/{draft_id}/approve", {})
    _record_planning_audit(
        current_user,
        "admin.planning.draft.approve",
        resource_id=str(draft_id),
        result=result,
    )
    return result


@router.post(
    "/drafts/{draft_id}/reject",
    summary="Reject training email draft",
    description="Rejects one draft and stores the reviewer reason.",
)
async def reject_training_draft(
    draft_id: int,
    request: AdminPlanningRejectDraftRequest,
    current_user: Annotated[User, Depends(get_current_admin_planning_editor)],
    gateway: Annotated[
        PlanningManagementGateway,
        Depends(get_planning_management_gateway),
    ],
) -> Any:
    reason = request.reason or request.review_notes
    result = await gateway.post_json(
        f"drafts/{draft_id}/reject",
        {"reason": reason},
    )
    _record_planning_audit(
        current_user,
        "admin.planning.draft.reject",
        resource_id=str(draft_id),
        result=result,
    )
    return result


@router.post(
    "/drafts/{draft_id}/send",
    summary="Send approved training email draft",
    description="Sends one approved draft after explicit dashboard confirmation.",
)
async def send_training_draft(
    draft_id: int,
    request: AdminPlanningSendDraftRequest,
    current_user: Annotated[User, Depends(get_current_admin_planning_editor)],
    gateway: Annotated[
        PlanningManagementGateway,
        Depends(get_planning_management_gateway),
    ],
    authorization: Annotated[str | None, Header()] = None,
) -> Any:
    payload = request.model_dump(exclude_none=True)
    if payload.get("confirmation") == "SEND_APPROVED_DRAFT":
        payload["confirmed"] = True
    payload.pop("confirmation", None)
    result = await gateway.post_json(
        f"drafts/{draft_id}/send",
        payload,
        authorization=authorization,
    )
    _record_planning_audit(
        current_user,
        "admin.planning.draft.send",
        resource_id=str(draft_id),
        result=result,
    )
    return result


def _record_planning_audit(
    actor: User,
    action: str,
    *,
    resource_id: str = "",
    result: Any = None,
) -> None:
    try:
        with SessionLocal() as db:
            AuditRepository(db).create(
                actor=actor,
                action=action,
                resource_type="planning",
                resource_id=resource_id,
                status=_audit_status(result),
                metadata=_compact_planning_metadata(result),
            )
    except Exception:
        pass


def _record_responsable_audit(
    db: Session,
    actor: User,
    action: str,
    summary: str,
    *,
    resource_id: str = "",
    metadata: dict[str, Any] | None = None,
) -> None:
    try:
        AuditRepository(db).create(
            actor=actor,
            action=action,
            resource_type="responsable",
            resource_id=resource_id,
            summary=summary,
            metadata=metadata or {},
        )
    except Exception:
        db.rollback()
        pass


def _changed_fields(before: dict[str, Any], after: dict[str, Any]) -> list[str]:
    return [
        key
        for key, value in after.items()
        if key in before and before.get(key) != value
    ]


def _planning_usage_summary(
    db: Session,
    *,
    date_from: datetime | None = None,
    date_to: datetime | None = None,
) -> dict[str, int]:
    usage = _planning_usage_by_user(
        db,
        date_from=date_from,
        date_to=date_to,
        limit=10000,
        offset=0,
    )
    return {
        "users": usage["total"],
        "actions_total": sum(item["actions_total"] for item in usage["users"]),
        "imports_created": sum(item["imports_created"] for item in usage["users"]),
        "files_treated": sum(item["files_treated"] for item in usage["users"]),
        "drafts_prepared": sum(item["drafts_prepared"] for item in usage["users"]),
        "drafts_reviewed": sum(item["drafts_reviewed"] for item in usage["users"]),
        "drafts_sent": sum(item["drafts_sent"] for item in usage["users"]),
    }


def _planning_usage_by_user(
    db: Session,
    *,
    date_from: datetime | None = None,
    date_to: datetime | None = None,
    limit: int = 50,
    offset: int = 0,
) -> dict[str, Any]:
    clauses = [
        AuditLog.resource_type == "planning",
        AuditLog.action.like("admin.planning.%"),
    ]
    if date_from is not None:
        clauses.append(AuditLog.created_at >= date_from)
    if date_to is not None:
        clauses.append(AuditLog.created_at <= date_to)

    rows = list(db.scalars(select(AuditLog).where(*clauses)))
    grouped: dict[str, dict[str, Any]] = {}
    for row in rows:
        key = row.actor_email or row.actor_user_id or "unknown"
        item = grouped.setdefault(
            key,
            {
                "actor_user_id": row.actor_user_id,
                "actor_email": row.actor_email or "unknown",
                "actor_role": row.actor_role,
                "actions_total": 0,
                "imports_created": 0,
                "files_treated": 0,
                "drafts_prepared": 0,
                "drafts_reviewed": 0,
                "drafts_sent": 0,
                "last_action_at": "",
            },
        )
        metadata = _audit_metadata_dict(row)
        item["actions_total"] += 1
        item["last_action_at"] = max(
            str(item["last_action_at"] or ""),
            row.created_at.isoformat() if row.created_at else "",
        )
        if row.action == "admin.planning.import.create":
            item["imports_created"] += 1
            item["files_treated"] += _metadata_count(metadata, "file_count")
        elif row.action == "admin.planning.drafts.generate":
            item["drafts_prepared"] += _metadata_count(
                metadata,
                "draft_count",
                "generated",
                "count",
            )
        elif row.action.startswith("admin.planning.drafts.bulk."):
            if row.action.endswith(".send"):
                item["drafts_sent"] += _metadata_count(
                    metadata,
                    "succeeded",
                    "draft_count",
                    "count",
                )
            else:
                item["drafts_reviewed"] += _metadata_count(
                    metadata,
                    "succeeded",
                    "draft_count",
                    "count",
                    default=1,
                )
        elif row.action in {
            "admin.planning.draft.approve",
            "admin.planning.draft.reject",
            "admin.planning.draft.regenerate",
            "admin.planning.draft.update",
        }:
            item["drafts_reviewed"] += 1
        elif row.action == "admin.planning.draft.send":
            item["drafts_sent"] += 1

    users = sorted(
        grouped.values(),
        key=lambda item: (item["drafts_prepared"], item["actions_total"], item["last_action_at"]),
        reverse=True,
    )
    paged = users[offset : offset + limit]
    return {
        "status": "ok",
        "total": len(users),
        "limit": limit,
        "offset": offset,
        "users": paged,
    }


def _audit_metadata_dict(log: AuditLog) -> dict[str, Any]:
    try:
        payload = json.loads(log.metadata_json or "{}")
    except json.JSONDecodeError:
        return {}
    return payload if isinstance(payload, dict) else {}


def _metadata_count(
    metadata: dict[str, Any],
    *keys: str,
    default: int = 0,
) -> int:
    for key in keys:
        value = metadata.get(key)
        if isinstance(value, bool):
            continue
        if isinstance(value, (int, float)):
            return int(value)
        if isinstance(value, str) and value.strip().isdigit():
            return int(value.strip())
    return default


def _parse_admin_date(value: str | None) -> datetime | None:
    if not value:
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def _planning_responsables_payload(db: Session) -> list[dict[str, Any]]:
    try:
        return ResponsableDirectoryService(db).list_all_for_planning()
    except Exception:
        return []


def _audit_status(result: Any) -> str:
    if not isinstance(result, dict):
        return "success"
    status_value = str(result.get("status") or "success").strip().lower()
    if status_value in {"ok", "sent", "success"}:
        return "success"
    if status_value in {"partial", "empty"}:
        return status_value
    if status_value in {"error", "failed"}:
        return "error"
    return status_value or "success"


def _compact_planning_metadata(result: Any) -> dict[str, Any]:
    if not isinstance(result, dict):
        return {}

    metadata: dict[str, Any] = {}
    for key in (
        "status",
        "import_id",
        "count",
        "total",
        "total_sessions",
        "total_participants",
        "generated",
        "succeeded",
        "failed",
        "mapped",
        "unmatched",
        "skipped_existing",
        "deleted_existing",
        "imported",
        "skipped",
    ):
        if key in result:
            metadata[key] = result[key]

    if isinstance(result.get("files"), list):
        metadata["file_count"] = len(result["files"])
    if isinstance(result.get("filenames"), list):
        metadata["file_count"] = len(result["filenames"])

    draft = result.get("draft")
    if isinstance(draft, dict):
        metadata["draft_id"] = draft.get("id")
        metadata["draft_status"] = draft.get("status")

    if isinstance(result.get("drafts"), list):
        metadata["draft_count"] = len(result["drafts"])

    if isinstance(result.get("errors"), list):
        metadata["error_count"] = len(result["errors"])

    return metadata
