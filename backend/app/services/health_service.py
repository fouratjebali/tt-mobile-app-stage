from time import perf_counter
from urllib.parse import urlsplit, urlunsplit

import httpx
from redis.asyncio import Redis
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.core.config import settings
from app.schemas.health import HealthServicesResponse, ServiceHealth, ServiceStatus


class HealthService:
    def __init__(self, db: Session) -> None:
        self._db = db
        self._timeout = settings.HEALTHCHECK_TIMEOUT_SECONDS

    async def check_services(self) -> HealthServicesResponse:
        services = {
            "backend": ServiceHealth(status="ok", detail="API process is running."),
            "postgres": self._check_postgres(),
            "redis": await self._check_redis(),
            "email_agent": await self._check_http_service(
                settings.AGENT1_URL,
                "/health",
            ),
            "jury_agent": await self._check_http_service(
                settings.AGENT2_URL,
                "/health",
            ),
            "sentiment_agent": await self._check_http_service(
                settings.SENTIMENT_AGENT_URL,
                "/health",
            ),
            "ollama": await self._check_http_service(
                settings.OLLAMA_BASE_URL,
                "/api/tags",
            ),
        }

        return HealthServicesResponse(
            status=self._overall_status(services),
            services=services,
        )

    def _check_postgres(self) -> ServiceHealth:
        start = perf_counter()
        try:
            self._db.execute(text("SELECT 1"))
        except Exception as exc:
            return ServiceHealth(status="down", detail=str(exc))

        return ServiceHealth(status="ok", latency_ms=_latency_ms(start))

    async def _check_redis(self) -> ServiceHealth:
        start = perf_counter()
        redis = Redis.from_url(settings.REDIS_URL, socket_timeout=self._timeout)
        try:
            await redis.ping()
        except Exception as exc:
            return ServiceHealth(
                status="down",
                url=_safe_url(settings.REDIS_URL),
                detail=str(exc),
            )
        finally:
            await redis.aclose()

        return ServiceHealth(
            status="ok",
            latency_ms=_latency_ms(start),
            url=_safe_url(settings.REDIS_URL),
        )

    async def _check_http_service(self, base_url: str, path: str) -> ServiceHealth:
        normalized_url = f"{base_url.rstrip('/')}{path}"
        start = perf_counter()
        try:
            async with httpx.AsyncClient(timeout=self._timeout) as client:
                response = await client.get(normalized_url)
        except httpx.HTTPError as exc:
            return ServiceHealth(status="down", url=normalized_url, detail=str(exc))

        if response.status_code >= 500:
            status: ServiceStatus = "down"
        elif response.status_code >= 400:
            status = "degraded"
        else:
            status = "ok"

        return ServiceHealth(
            status=status,
            latency_ms=_latency_ms(start),
            url=normalized_url,
            detail=f"HTTP {response.status_code}",
        )

    def _overall_status(self, services: dict[str, ServiceHealth]) -> ServiceStatus:
        statuses = [service.status for service in services.values()]
        if any(status == "down" for status in statuses):
            return "down"
        if any(status == "degraded" for status in statuses):
            return "degraded"
        return "ok"


def _latency_ms(start: float) -> float:
    return round((perf_counter() - start) * 1000, 2)


def _safe_url(value: str) -> str:
    parsed = urlsplit(value)
    if "@" not in parsed.netloc:
        return value

    host = parsed.hostname or ""
    if parsed.port is not None:
        host = f"{host}:{parsed.port}"

    return urlunsplit((parsed.scheme, host, parsed.path, parsed.query, ""))
