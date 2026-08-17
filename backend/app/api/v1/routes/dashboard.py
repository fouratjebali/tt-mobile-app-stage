import os
import tempfile
from datetime import datetime, timezone
from typing import Annotated

from fastapi import APIRouter, Depends, Query
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle
from sqlalchemy.orm import Session

from app.api.dependencies import get_current_user
from app.db.session import get_db
from app.models.auth import User
from app.schemas.dashboard import (
    DashboardExportRequest,
    DashboardExportResponse,
    DashboardStatsResponse,
)
from app.services.agent_bridge import AgentBridge, get_agent_bridge
from app.services.email_cache_service import EmailCacheService


router = APIRouter()


@router.get(
    "/stats",
    response_model=DashboardStatsResponse,
    summary="Get dashboard statistics",
    description=(
        "Builds aggregated email activity statistics for the mobile dashboard."
    ),
)
async def dashboard_stats(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
    refresh: bool = Query(default=False),
) -> DashboardStatsResponse:
    return await EmailCacheService(db).dashboard_stats(user=user, refresh=refresh)


@router.post(
    "/export",
    response_model=DashboardExportResponse,
    summary="Generate dashboard export PDF",
    description=(
        "Generates a PDF report for the selected dashboard period and returns basic "
        "metadata for the mobile app."
    ),
)
async def dashboard_export(
    request: DashboardExportRequest,
    bridge: AgentBridge = Depends(get_agent_bridge),
) -> DashboardExportResponse:
    stats = await bridge.dashboard_stats()
    payload = stats.payload
    period = _normalize_period(request.period)
    generated_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    file_name = f"dashboard_report_{period}_{generated_at.replace(':', '').replace('-', '').replace('T', '_').replace('Z', '')}.pdf"
    target_path = os.path.join(tempfile.gettempdir(), file_name)

    _write_dashboard_report(payload=payload, period=period, output_path=target_path)
    file_size = os.path.getsize(target_path)

    return DashboardExportResponse(
        status="ok",
        message="Dashboard report generated successfully.",
        period=period,
        file_name=file_name,
        file_size_bytes=file_size,
        generated_at=generated_at,
    )


def _write_dashboard_report(*, payload: dict, period: str, output_path: str) -> None:
    styles = getSampleStyleSheet()
    title_style = ParagraphStyle(
        "DashboardTitle",
        parent=styles["Title"],
        fontSize=20,
        leading=24,
        spaceAfter=16,
    )
    subtitle_style = ParagraphStyle(
        "DashboardSubtitle",
        parent=styles["BodyText"],
        fontSize=10,
        textColor=colors.HexColor("#4B5563"),
        spaceAfter=12,
    )

    summary_rows = [
        ["Metric", "Value"],
        ["Processed", str(int(payload.get("processed_count", 0) or 0))],
        ["Urgent", str(int(payload.get("urgent_count", 0) or 0))],
        ["Review", str(int(payload.get("review_count", 0) or 0))],
        ["Sent", str(int(payload.get("sent_count", 0) or 0))],
    ]
    categories = payload.get("categories") or {}
    if isinstance(categories, dict) and categories:
        for key, value in categories.items():
            summary_rows.append([str(key), str(int(value or 0))])

    doc = SimpleDocTemplate(
        output_path,
        pagesize=A4,
        rightMargin=36,
        leftMargin=36,
        topMargin=36,
        bottomMargin=36,
    )
    story = [
        Paragraph("TT Mail Assistant Dashboard", title_style),
        Paragraph(f"Period: {period.upper()} | Generated: {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M UTC')}", subtitle_style),
        Spacer(1, 12),
        Table(summary_rows, colWidths=[220, 140]),
    ]
    table = story[-1]
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#E5E7EB")),
                ("TEXTCOLOR", (0, 0), (-1, 0), colors.black),
                ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
                ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
                ("ALIGN", (1, 1), (-1, -1), "CENTER"),
                ("BOTTOMPADDING", (0, 0), (-1, 0), 8),
                ("TOPPADDING", (0, 0), (-1, 0), 8),
                ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
            ]
        )
    )
    doc.build(story)


def _normalize_period(value: str | None) -> str:
    normalized = str(value or '7d').strip().lower()
    if normalized in {'7d', '7', '7_days', 'week'}:
        return '7d'
    if normalized in {'30d', '30', '30_days', 'month'}:
        return '30d'
    return '7d'


def _to_categories(value) -> dict[str, int]:
    if not isinstance(value, dict):
        return {}

    categories: dict[str, int] = {}
    for key, count in value.items():
        try:
            categories[str(key)] = int(count)
        except (TypeError, ValueError):
            categories[str(key)] = 0

    return categories
