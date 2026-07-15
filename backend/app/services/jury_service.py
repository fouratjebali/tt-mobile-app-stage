import httpx
from fastapi import HTTPException, status

from app.core.config import settings
from app.schemas.jury import JuryRequest, JuryResponse


class JuryService:
    def __init__(self, base_url: str):
        self.base_url = base_url.rstrip("/")

    async def verify(self, request: JuryRequest) -> JuryResponse:
        try:
            async with httpx.AsyncClient(timeout=settings.HTTP_TIMEOUT_SECONDS) as client:
                response = await client.post(
                    f"{self.base_url}/verify",
                    json=request.model_dump(),
                )
                response.raise_for_status()
        except httpx.HTTPError as exc:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"Jury Agent is unavailable: {exc}",
            ) from exc

        return JuryResponse.model_validate(response.json())


def get_jury_service() -> JuryService:
    return JuryService(settings.AGENT2_URL)
