from typing import Any

import httpx
from fastapi import HTTPException, UploadFile, status

from app.core.config import settings


class PlanningManagementGateway:
    def __init__(self) -> None:
        self._base_url = f"{settings.AGENT1_URL.rstrip('/')}/planning"
        self._timeout = settings.HTTP_TIMEOUT_SECONDS

    async def get(self, path: str, params: dict[str, Any] | None = None) -> Any:
        return await self._request("GET", path, params=params)

    async def post_json(
        self,
        path: str,
        payload: dict[str, Any],
        *,
        params: dict[str, Any] | None = None,
        authorization: str | None = None,
    ) -> Any:
        return await self._request(
            "POST",
            path,
            params=params,
            json=payload,
            authorization=authorization,
        )

    async def patch_json(
        self,
        path: str,
        payload: dict[str, Any],
        *,
        params: dict[str, Any] | None = None,
    ) -> Any:
        return await self._request("PATCH", path, params=params, json=payload)

    async def post_files(
        self,
        path: str,
        files: list[UploadFile],
        *,
        params: dict[str, Any] | None = None,
    ) -> Any:
        multipart_files = []
        for upload in files:
            filename = upload.filename or "upload.xlsx"
            content = await upload.read()
            if not content:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"{filename} is empty.",
                )
            multipart_files.append(
                (
                    "files",
                    (
                        filename,
                        content,
                        upload.content_type or "application/octet-stream",
                    ),
                )
            )
        return await self._request("POST", path, params=params, files=multipart_files)

    async def _request(
        self,
        method: str,
        path: str,
        *,
        params: dict[str, Any] | None = None,
        json: dict[str, Any] | None = None,
        files: list[tuple[str, tuple[str, bytes, str]]] | None = None,
        authorization: str | None = None,
    ) -> Any:
        headers = {}
        if authorization:
            headers["Authorization"] = authorization

        try:
            async with httpx.AsyncClient(timeout=self._timeout) as client:
                response = await client.request(
                    method,
                    f"{self._base_url}/{path.strip('/')}",
                    params=_clean_params(params),
                    json=json,
                    files=files,
                    headers=headers,
                )
                response.raise_for_status()
        except httpx.HTTPStatusError as exc:
            raise HTTPException(
                status_code=exc.response.status_code,
                detail=_response_detail(exc.response),
            ) from exc
        except httpx.HTTPError as exc:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"Planning service is unavailable: {exc}",
            ) from exc

        if not response.content:
            return {"status": "ok"}
        try:
            return response.json()
        except ValueError as exc:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Planning service returned an invalid JSON response.",
            ) from exc


def get_planning_management_gateway() -> PlanningManagementGateway:
    return PlanningManagementGateway()


def _clean_params(params: dict[str, Any] | None) -> dict[str, Any] | None:
    if params is None:
        return None
    return {key: value for key, value in params.items() if value is not None}


def _response_detail(response: httpx.Response) -> Any:
    try:
        payload = response.json()
    except ValueError:
        return response.text or "Planning service request failed."
    if isinstance(payload, dict) and "detail" in payload:
        return payload["detail"]
    return payload
