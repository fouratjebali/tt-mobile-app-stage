from fastapi import APIRouter, Depends

from app.api.dependencies import get_current_user
from app.api.v1.routes import (
    agent,
    auth,
    bulk,
    dashboard,
    email,
    health,
    jury,
    notifications,
    planning,
    sentiment,
)


api_router = APIRouter()
api_router.include_router(health.router, tags=["health"])
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(
    email.router,
    prefix="/email",
    tags=["email"],
    dependencies=[Depends(get_current_user)],
)
api_router.include_router(
    agent.router,
    prefix="/agent",
    tags=["agent"],
    dependencies=[Depends(get_current_user)],
)
api_router.include_router(
    jury.router,
    prefix="/jury",
    tags=["jury"],
    dependencies=[Depends(get_current_user)],
)
api_router.include_router(
    sentiment.router,
    prefix="/sentiment",
    tags=["sentiment"],
    dependencies=[Depends(get_current_user)],
)
api_router.include_router(
    bulk.router,
    prefix="/bulk",
    tags=["bulk"],
    dependencies=[Depends(get_current_user)],
)
api_router.include_router(
    planning.router,
    prefix="/planning",
    tags=["planning"],
    dependencies=[Depends(get_current_user)],
)
api_router.include_router(
    dashboard.router,
    prefix="/dashboard",
    tags=["dashboard"],
    dependencies=[Depends(get_current_user)],
)
api_router.include_router(
    notifications.router,
    prefix="/notifications",
    tags=["notifications"],
    dependencies=[Depends(get_current_user)],
)
