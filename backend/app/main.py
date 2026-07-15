from fastapi import FastAPI

from app.api.v1.router import api_router
from app.core.config import settings


def create_app() -> FastAPI:
    app = FastAPI(
        title=settings.APP_NAME,
        version=settings.APP_VERSION,
        description="Backend API bridge for the mobile app, Agent 1, Jury Agent, PostgreSQL, and Redis.",
    )

    app.include_router(api_router, prefix=settings.API_V1_PREFIX)

    @app.get("/")
    def root() -> dict[str, str]:
        return {
            "message": "TT Mail Assistant Backend is running",
            "docs": "/docs",
            "health": f"{settings.API_V1_PREFIX}/health",
        }

    return app


app = create_app()
