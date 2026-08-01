from collections.abc import AsyncIterator
from typing import Any

import httpx
from fastapi import HTTPException, status

from app.core.config import settings


class AgentBridge:
    def __init__(self) -> None:
        self._agent_url = settings.AGENT1_URL.rstrip("/")
        self._jury_url = settings.AGENT2_URL.rstrip("/")
        self._sentiment_url = settings.SENTIMENT_AGENT_URL.rstrip("/")
        self._timeout = settings.HTTP_TIMEOUT_SECONDS

    async def chat(self, message: str) -> str:
        payload = await self._post(
            service_name="Email Agent",
            url=f"{self._agent_url}/chat",
            json={"message": message},
        )
        return str(payload.get("response", ""))

    async def stream_chat(self, message: str) -> AsyncIterator[str]:
        response = await self.chat(message)
        yield response

    async def confirm_action(self, action: str, payload: dict[str, Any]) -> str:
        return await self.chat(
            "Confirm and execute this email action. "
            "Return a concise JSON-like result for the mobile app.\n"
            f"Action: {action}\n"
            f"Payload: {payload}"
        )

    async def verify_with_jury(
        self,
        *,
        email: dict[str, Any],
        analysis: dict[str, Any],
        agent_response: dict[str, Any],
    ) -> dict[str, Any]:
        return await self._post(
            service_name="Jury Agent",
            url=f"{self._jury_url}/verify",
            json={
                "email": email,
                "analysis": analysis,
                "agent_response": agent_response,
            },
        )

    async def analyze_sentiment(self, text: str) -> dict[str, Any]:
        return await self._post(
            service_name="Sentiment Agent",
            url=f"{self._sentiment_url}/sentiment/analyze",
            json={"text": text},
        )

    async def read_today_emails(self, max_results: int = 10) -> str:
        return await self.chat(
            "Read today's Gmail inbox messages using read_emails. "
            "Return only structured JSON with id, subject, sender, date, "
            "is_read and body_preview.\n"
            f"max_results={max_results}"
        )

    async def read_review_emails(self, max_results: int = 10) -> str:
        return await self.chat(
            "Find emails that need user review. Use get_urgent_emails first. "
            "Return only structured JSON for the mobile review screen.\n"
            f"max_results={max_results}"
        )

    async def get_email_detail(self, email_id: str) -> str:
        return await self.chat(
            "Analyze this Gmail message for the mobile detail screen. "
            "Use classify_email, prioritize_email, summarize_email and "
            "suggest_reply. Return only structured JSON.\n"
            f"email_id={email_id}"
        )

    async def send_email_reply(self, email_id: str, body: str) -> str:
        return await self.chat(
            "Send the following reply for the selected Gmail message. "
            "Use the email id to identify the recipient if needed, then send "
            "with send_single_email. Return only structured JSON.\n"
            f"email_id={email_id}\n"
            f"body={body}"
        )

    async def generate_bulk(
        self,
        *,
        recipients: list[dict[str, Any]],
        topic: str,
        instructions: str = "",
    ) -> str:
        return await self.chat(
            "Generate personalized bulk emails for preview only. "
            "Use generate_and_send_bulk_emails with dry_run=true. "
            "Return only structured JSON.\n"
            f"recipients={recipients}\n"
            f"topic={topic}\n"
            f"instructions={instructions}"
        )

    async def send_bulk(
        self,
        *,
        recipients: list[dict[str, Any]],
        topic: str,
        instructions: str = "",
    ) -> str:
        return await self.chat(
            "Generate and send personalized bulk emails. "
            "Use generate_and_send_bulk_emails with dry_run=false. "
            "Return only structured JSON.\n"
            f"recipients={recipients}\n"
            f"topic={topic}\n"
            f"instructions={instructions}"
        )

    async def dashboard_stats(self) -> str:
        return await self.chat(
            "Build dashboard stats from recent Gmail activity. "
            "Return only structured JSON with processed_count, urgent_count, "
            "review_count, sent_count and categories."
        )

    async def _post(
        self,
        *,
        service_name: str,
        url: str,
        json: dict[str, Any],
    ) -> dict[str, Any]:
        try:
            async with httpx.AsyncClient(timeout=self._timeout) as client:
                response = await client.post(url, json=json)
                response.raise_for_status()
        except httpx.HTTPStatusError as exc:
            raise HTTPException(
                status_code=exc.response.status_code,
                detail=exc.response.text,
            ) from exc
        except httpx.HTTPError as exc:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"{service_name} is unavailable: {exc}",
            ) from exc

        payload = response.json()
        if not isinstance(payload, dict):
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"{service_name} returned an invalid response.",
            )

        return payload


def get_agent_bridge() -> AgentBridge:
    return AgentBridge()
