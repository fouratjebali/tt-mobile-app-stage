import asyncio

from fastapi import FastAPI

from app.api.v1.router import api_router
from app.core.config import settings
from app.db.session import init_db
from app.services.email_background_pipeline import pipeline_loop


def create_app() -> FastAPI:
    app = FastAPI(
        title=settings.APP_NAME,
        version=settings.APP_VERSION,
        description=(
            "REST API for TT Mail Assistant. It connects the Flutter mobile app "
            "to Google OAuth, PostgreSQL, Redis, the email AI agent, the jury "
            "agent, and the social sentiment agent."
        ),
        openapi_tags=[
            {
                "name": "health",
                "description": "Backend and infrastructure readiness checks.",
            },
            {
                "name": "auth",
                "description": "Google OAuth 2.0 login, session validation, refresh and logout.",
            },
            {
                "name": "email",
                "description": "Mobile email workflows: today inbox, review queue, details and replies.",
            },
            {
                "name": "agent",
                "description": "Conversational bridge to the email AI agent and action confirmation.",
            },
            {
                "name": "jury",
                "description": "Independent verification of AI analyses and generated responses.",
            },
            {
                "name": "sentiment",
                "description": "Text sentiment analysis through the social sentiment agent.",
            },
            {
                "name": "bulk",
                "description": "Bulk email generation and sending workflows.",
            },
            {
                "name": "dashboard",
                "description": "Dashboard statistics and export-oriented endpoints.",
            },
        ],
    )

    app.include_router(api_router, prefix=settings.API_V1_PREFIX)

    @app.on_event("startup")
    async def on_startup() -> None:
        init_db()
        app.state.email_pipeline_stop_event = asyncio.Event()
        app.state.email_pipeline_task = asyncio.create_task(
            pipeline_loop(app.state.email_pipeline_stop_event)
        )

    @app.on_event("shutdown")
    async def on_shutdown() -> None:
        stop_event = getattr(app.state, "email_pipeline_stop_event", None)
        task = getattr(app.state, "email_pipeline_task", None)
        if stop_event is not None:
            stop_event.set()
        if task is not None:
            task.cancel()
            try:
                await task
            except asyncio.CancelledError:
                pass

    @app.get("/")
    def root() -> dict[str, str]:
        return {
            "message": "TT Mail Assistant Backend is running",
            "docs": "/docs",
            "health": f"{settings.API_V1_PREFIX}/health",
        }

    return app


app = create_app()
