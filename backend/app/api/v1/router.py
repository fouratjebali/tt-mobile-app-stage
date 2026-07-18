from fastapi import APIRouter

from app.api.v1.routes import agent, auth, health, jury


api_router = APIRouter()
api_router.include_router(health.router, tags=["health"])
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(agent.router, prefix="/agent", tags=["agent"])
api_router.include_router(jury.router, prefix="/jury", tags=["jury"])
