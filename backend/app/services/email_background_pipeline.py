import asyncio
import logging
from contextlib import suppress
from typing import Any

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.core.config import settings
from app.db.session import SessionLocal
from app.models.auth import User
from app.models.email import Email, EmailAnalysis, EmailResponse
from app.repositories.email_workflow_repository import EmailWorkflowRepository
from app.services.agent_bridge import AgentBridge
from app.services.email_cache_service import EmailCacheService


logger = logging.getLogger(__name__)


class EmailBackgroundPipeline:
    def __init__(self, db: Session, bridge: AgentBridge | None = None) -> None:
        self._db = db
        self._repository = EmailWorkflowRepository(db)
        self._bridge = bridge or AgentBridge()
        self._cache = EmailCacheService(db, self._bridge)

    async def run_once_for_all_users(self) -> dict[str, int]:
        totals = {"users": 0, "synced": 0, "treated": 0, "notified": 0}
        for user in self._repository.list_users():
            totals["users"] += 1
            try:
                result = await self.run_once_for_user(user=user)
            except HTTPException as error:
                if error.status_code == 401:
                    logger.info(
                        "Skipping email pipeline for user %s: %s",
                        user.id,
                        error.detail,
                    )
                    continue
                raise
            totals["synced"] += result["synced"]
            totals["treated"] += result["treated"]
            totals["notified"] += result["notified"]
        return totals

    async def run_once_for_user(self, *, user: User) -> dict[str, int]:
        synced = await self._sync_user_unread(user)
        treated, notified = await self._treat_pending_user_emails(user)
        return {"synced": synced, "treated": treated, "notified": notified}

    async def _sync_user_unread(self, user: User) -> int:
        before = len(
            self._repository.list_recent_emails(
                user=user,
                limit=settings.EMAIL_PIPELINE_MAX_EMAILS,
                unread_only=True,
            )
        )
        await self._cache.sync_unread(
            user=user,
            max_results=settings.EMAIL_PIPELINE_MAX_EMAILS,
        )
        after = len(
            self._repository.list_recent_emails(
                user=user,
                limit=settings.EMAIL_PIPELINE_MAX_EMAILS,
                unread_only=True,
            )
        )
        return max(after - before, 0)

    async def _treat_pending_user_emails(self, user: User) -> tuple[int, int]:
        treated = 0
        notified = 0
        candidates = self._repository.list_pipeline_candidates(
            user=user,
            limit=settings.EMAIL_PIPELINE_MAX_EMAILS,
        )

        for email in candidates:
            if email.status == "DONE" or self._repository.has_sent_response(email):
                continue

            analysis = self._repository.get_latest_analysis(email)
            response = self._repository.get_latest_response(email)
            if analysis is None or response is None:
                continue
            if (
                response.status == "sent"
                or response.sent_at is not None
                or response.gmail_message_id is not None
            ):
                continue

            verdict = self._repository.get_latest_jury_verdict(email)
            if verdict is None:
                verdict_payload = await self._verify_with_jury(
                    email=email,
                    analysis=analysis,
                    response=response,
                )
                self._repository.create_jury_verdict(
                    email=email,
                    analysis=analysis,
                    response=response,
                    verdict_payload=verdict_payload,
                )
                treated += 1

            self._repository.update_statuses(
                email=email,
                response=response,
                email_status="PENDING_USER_REVIEW",
                response_status="PENDING_USER_REVIEW",
            )
            _, notification_created = self._repository.create_notification_once(
                user=user,
                email=email,
                kind="email_treated",
                title="Email ready for review",
                body=f"{email.subject or 'New email'} has a suggested reply.",
                data={
                    "email_id": email.gmail_message_id,
                    "subject": email.subject,
                    "sender": email.sender,
                },
            )
            if notification_created:
                notified += 1

        return treated, notified

    async def _verify_with_jury(
        self,
        *,
        email: Email,
        analysis: EmailAnalysis,
        response: EmailResponse,
    ) -> dict[str, Any]:
        return await self._bridge.verify_with_jury(
            email={
                "id": email.gmail_message_id,
                "subject": email.subject,
                "sender": email.sender,
                "body": email.body,
                "body_preview": email.body_preview,
                "status": email.status,
            },
            analysis={
                "category": analysis.category,
                "confidence": analysis.classification_confidence,
                "priority": analysis.priority,
                "urgency_score": analysis.urgency_score,
                "summary": analysis.summary,
                "action_required": analysis.action_required,
            },
            agent_response={
                "reply_subject": response.subject,
                "reply_body": response.body,
                "tone": response.tone,
            },
        )


async def pipeline_loop(stop_event: asyncio.Event) -> None:
    if not settings.EMAIL_PIPELINE_ENABLED:
        logger.info("Email background pipeline is disabled.")
        return

    await _run_pipeline_once()
    while not stop_event.is_set():
        with suppress(asyncio.TimeoutError):
            await asyncio.wait_for(
                stop_event.wait(),
                timeout=settings.EMAIL_PIPELINE_INTERVAL_SECONDS,
            )
        if stop_event.is_set():
            break
        await _run_pipeline_once()


async def _run_pipeline_once() -> None:
    db = SessionLocal()
    try:
        result = await EmailBackgroundPipeline(db).run_once_for_all_users()
        logger.info("Email background pipeline result: %s", result)
        print(f"Email background pipeline result: {result}", flush=True)
    except Exception:
        logger.exception("Email background pipeline failed.")
        print("Email background pipeline failed. Check backend logs.", flush=True)
    finally:
        db.close()
