from fastapi import APIRouter, HTTPException, Request, Response, status
import httpx

from app.core.config import settings


router = APIRouter()


@router.api_route(
    "/{planning_path:path}",
    methods=["GET", "POST", "PATCH", "DELETE"],
    summary="Forward training planning requests to the email agent",
)
async def proxy_planning_request(
    planning_path: str,
    request: Request,
) -> Response:
    target_url = f"{settings.AGENT1_URL.rstrip('/')}/planning/{planning_path}"
    headers = _forward_headers(request)
    body = await request.body()

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
