import json
from typing import Annotated, Any

from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response, status
import httpx
from sqlalchemy.orm import Session

from app.api.dependencies import get_current_user
from app.core.config import settings
from app.db.session import get_db
from app.models.auth import User
from app.services.outlook_graph_service import OutlookGraphService
from app.services.responsable_directory_service import ResponsableDirectoryService


router = APIRouter()


@router.get(
    "/responsables",
    summary="List responsables from the backend directory",
    description="Returns responsables stored in PostgreSQL with search and pagination.",
)
def list_responsables_directory(
    db: Annotated[Session, Depends(get_db)],
    search: str | None = Query(default=None),
    fonction: str | None = Query(default=None),
    grande_residence: str | None = Query(default=None),
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
) -> dict:
    return ResponsableDirectoryService(db).list_responsables(
        search=search,
        fonction=fonction,
        grande_residence=grande_residence,
        limit=limit,
        offset=offset,
    )


@router.get(
    "/send-history",
    summary="List sent training emails from Outlook",
    description=(
        "Returns recent messages from the user's Outlook Sent Items folder. "
        "Training drafts are sent manually from Outlook, so this endpoint does "
        "not read the planning agent send log."
    ),
)
async def list_outlook_sent_history(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
    import_id: str | None = Query(default=None),
    draft_id: int | None = Query(default=None),
    send_status: str | None = Query(default=None),
    search: str | None = Query(default=None),
    limit: int = Query(default=50, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
) -> dict:
    _ = (import_id, draft_id, send_status)
    history = await OutlookGraphService(db).list_sent_messages(
        user=user,
        max_results=limit,
        skip=offset,
        search=search,
    )
    return {
        "status": "ok",
        "source": "outlook_sent_items",
        "count": len(history),
        "limit": limit,
        "offset": offset,
        "history": history,
    }


@router.api_route(
    "/{planning_path:path}",
    methods=["GET", "POST", "PATCH", "DELETE"],
    summary="Forward training planning requests to the email agent",
)
async def proxy_planning_request(
    planning_path: str,
    request: Request,
    db: Annotated[Session, Depends(get_db)],
) -> Response:
    target_url = f"{settings.AGENT1_URL.rstrip('/')}/planning/{planning_path}"
    headers = _forward_headers(request)
    body = await _planning_body_with_responsables(planning_path, request, db)

    try:
        async with httpx.AsyncClient(timeout=settings.HTTP_TIMEOUT_SECONDS) as client:
            response = await client.request(
                request.method,
                target_url,
                params=request.query_params,
                content=body,
                headers=headers,
            )
    except httpx.HTTPError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Planning service is unavailable: {exc}",
        ) from exc

    return Response(
        content=response.content,
        status_code=response.status_code,
        media_type=response.headers.get("content-type"),
    )


def _forward_headers(request: Request) -> dict[str, str]:
    excluded = {"host", "content-length", "connection"}
    return {
        key: value
        for key, value in request.headers.items()
        if key.lower() not in excluded
    }


async def _planning_body_with_responsables(
    planning_path: str,
    request: Request,
    db: Session,
) -> bytes:
    body = await request.body()
    if request.method.upper() != "POST":
        return body
    if planning_path.strip("/") not in {"drafts/generate", "automation/run"}:
        return body
    content_type = request.headers.get("content-type", "")
    if "application/json" not in content_type.lower():
        return body
    try:
        payload: dict[str, Any] = json.loads(body.decode("utf-8")) if body else {}
    except (UnicodeDecodeError, json.JSONDecodeError):
        return body
    payload["responsables"] = ResponsableDirectoryService(db).list_all_for_planning()
    return json.dumps(payload).encode("utf-8")
