from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.auth import User
from app.repositories.email_workflow_repository import EmailWorkflowRepository
from app.schemas.email import (
    EmailDetailResponse,
    EmailListResponse,
    SendEmailResponse,
)
from app.services.agent_bridge import AgentBridge
from app.services.email_cache_service import EmailCacheService
from app.services.outlook_graph_service import OutlookGraphService


class EmailPipelineService:
    def __init__(self, db: Session, bridge: AgentBridge | None = None) -> None:
        self._repository = EmailWorkflowRepository(db)
        self._bridge = bridge or AgentBridge()
        self._cache = EmailCacheService(db, self._bridge)
        self._outlook = OutlookGraphService(db)

    async def today_emails(
        self,
        *,
        user: User,
        max_results: int,
        refresh: bool = False,
    ) -> EmailListResponse:
        return await self._cache.today_emails(
            user=user,
            max_results=max_results,
            refresh=refresh,
        )

    async def review_emails(
        self,
        *,
        user: User,
        max_results: int,
        refresh: bool = False,
    ) -> EmailListResponse:
        return await self._cache.review_emails(
            user=user,
            max_results=max_results,
            refresh=refresh,
        )

    async def email_detail(
        self,
        *,
        user: User,
        email_id: str,
        refresh: bool = False,
    ) -> EmailDetailResponse:
        return await self._cache.email_detail(
            user=user,
            email_id=email_id,
            refresh=refresh,
        )

    async def analyze_and_verify(
        self,
        *,
        user: User,
        email_id: str,
    ) -> EmailDetailResponse:
        return await self._cache.email_detail(
            user=user,
            email_id=email_id,
            refresh=True,
        )

    async def verify_then_send_reply(
        self,
        *,
        user: User,
        email_id: str,
        body: str,
    ) -> SendEmailResponse:
        email = self._repository.get_email_by_gmail_id(
            user=user,
            gmail_message_id=email_id,
        )
        if email is None:
            email = self._repository.upsert_email(
                user=user,
                gmail_message_id=email_id,
                payload={"id": email_id, "sender": "", "status": "draft"},
            )

        latest_response = self._repository.get_latest_response(email)
        response = self._repository.upsert_draft_response(
            email=email,
            subject=latest_response.subject if latest_response else f"Re: {email.subject}",
            body=body,
            tone=latest_response.tone if latest_response else "professional",
            payload={"reply_body": body},
        )
        verdict = self._repository.get_latest_jury_verdict(email)

        send_result = await self._outlook.send_reply(
            user=user,
            message_id=email_id,
            body=body,
        )
        send_status = str(send_result.get("status", "")).lower()
        message_id = str(send_result.get("message_id") or "").strip()
        if send_status != "sent" or not message_id:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Outlook did not confirm that the reply was sent.",
            )

        self._repository.update_statuses(
            email=email,
            response=response,
            email_status="DONE",
            response_status="sent",
            sent_message_id=message_id,
        )
        return SendEmailResponse(
            status=str(send_result.get("status", "sent")),
            message_id=message_id,
            jury_verdict=verdict.raw_payload if verdict is not None else None,
            raw_result=None,
        )

    async def reject_email(
        self,
        *,
        user: User,
        email_id: str,
    ) -> SendEmailResponse:
        email = self._repository.get_email_by_gmail_id(
            user=user,
            gmail_message_id=email_id,
        )
        if email is None:
            email = self._repository.upsert_email(
                user=user,
                gmail_message_id=email_id,
                payload={"id": email_id, "sender": "", "status": "needs_review"},
            )

        self._repository.update_statuses(
            email=email,
            response=None,
            email_status="DONE",
        )
        return SendEmailResponse(status="ignored", raw_result=None)
