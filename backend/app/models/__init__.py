"""SQLAlchemy models will live here."""

from app.models.auth import AuthSession, User
from app.models.email import Email
from app.models.email_analysis import EmailAnalysis
from app.models.dashboard_stats import DashboardStats
from app.models.app_settings import AppSettings

__all__ = [
    "AuthSession",
    "User",
    "Email",
    "EmailAnalysis",
    "DashboardStats",
    "AppSettings",
]
