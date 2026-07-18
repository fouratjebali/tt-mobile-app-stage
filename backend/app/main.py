from fastapi import FastAPI

from app.api.v1.router import api_router
from app.core.config import settings
from app.db.session import init_db


def create_app() -> FastAPI:
    app = FastAPI(
        title=settings.APP_NAME,
        version=settings.APP_VERSION,
        description="Backend API bridge for the mobile app, Agent 1, Jury Agent, PostgreSQL, and Redis.",
    )

    app.include_router(api_router, prefix=settings.API_V1_PREFIX)

    @app.on_event("startup")
    def on_startup() -> None:
        init_db()

    @app.get("/")
    def root() -> dict[str, str]:
        return {
            "message": "TT Mail Assistant Backend is running",
            "docs": "/docs",
            "health": f"{settings.API_V1_PREFIX}/health",
        }

    return app


app = create_app()
