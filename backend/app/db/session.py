from collections.abc import Generator

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from app.core.config import settings
from app.db.base import Base
from app.db.compat import ensure_email_workflow_schema
from app.repositories.auth_repository import AuthRepository


engine = create_engine(settings.DATABASE_URL, pool_pre_ping=True)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def init_db() -> None:
    import app.models  # noqa: F401

    Base.metadata.create_all(bind=engine)
    ensure_email_workflow_schema(engine)
    seed_admin_dashboard_credentials()


def seed_admin_dashboard_credentials() -> None:
    if not settings.ADMIN_DASHBOARD_USERNAME or not settings.ADMIN_DASHBOARD_PASSWORD:
        return

    db = SessionLocal()
    try:
        AuthRepository(db).upsert_admin_credential(
            username=settings.ADMIN_DASHBOARD_USERNAME,
            password=settings.ADMIN_DASHBOARD_PASSWORD,
            email=(
                settings.ADMIN_DASHBOARD_EMAIL
                or f"{settings.ADMIN_DASHBOARD_USERNAME}@local.admin"
            ),
            display_name=settings.ADMIN_DASHBOARD_DISPLAY_NAME,
        )
    finally:
        db.close()


def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
