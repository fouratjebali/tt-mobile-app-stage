from collections.abc import AsyncIterator
from dataclasses import dataclass
from typing import Any

import httpx
from fastapi import HTTPException, status

from app.core.config import settings
from app.utils.json_tools import parse_agent_json


@dataclass(frozen=True)
class AgentBridgeResult:
    payload: dict[str, Any]
    raw_result: str


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

    async def read_today_emails(self, max_results: int = 10) -> AgentBridgeResult:
        return await self._get_agent_json(
            path="/emails/unread",
            params={"max_results": max_results},
        )

    async def read_review_emails(self, max_results: int = 10) -> AgentBridgeResult:
        return await self._get_agent_json(
            path="/emails/review",
            params={"max_results": max_results},
        )

    async def get_email_detail(self, email_id: str) -> AgentBridgeResult:
        return await self._get_agent_json(
            path=f"/emails/{email_id}",
            params=None,
        )

    async def send_email_reply(self, email_id: str, body: str) -> AgentBridgeResult:
        return await self._chat_json(
            task=(
                "Send the following reply for the selected Gmail message. "
                "Use the email id to identify the recipient if needed, then send "
                "with send_single_email.\n"
                f"email_id={email_id}\n"
                f"body={body}"
            ),
            expected_schema='{"status":"sent","message_id":""}',
        )

    async def generate_bulk(
        self,
        *,
        recipients: list[dict[str, Any]],
        topic: str,
        instructions: str = "",
    ) -> AgentBridgeResult:
        return await self._chat_json(
            task=(
                "Generate personalized bulk emails for preview only. "
                "Use generate_and_send_bulk_emails with dry_run=true.\n"
                f"recipients={recipients}\n"
                f"topic={topic}\n"
                f"instructions={instructions}"
            ),
            expected_schema=(
                '{"status":"ok","total":0,"sent":0,"errors":0,'
                '"details":[{"to":"","subject":"","body":"","status":"draft"}]}'
            ),
        )

    async def send_bulk(
        self,
        *,
        recipients: list[dict[str, Any]],
        topic: str,
        instructions: str = "",
    ) -> AgentBridgeResult:
        return await self._chat_json(
            task=(
                "Generate and send personalized bulk emails. "
                "Use generate_and_send_bulk_emails with dry_run=false.\n"
                f"recipients={recipients}\n"
                f"topic={topic}\n"
                f"instructions={instructions}"
            ),
            expected_schema=(
                '{"status":"ok","total":0,"sent":0,"errors":0,'
                '"details":[{"to":"","subject":"","status":"sent","message_id":""}]}'
            ),
        )

    async def dashboard_stats(self) -> AgentBridgeResult:
        return await self._get_agent_json(
            path="/dashboard/stats",
            params=None,
        )

    async def _get_agent_json(
        self,
        *,
        path: str,
        params: dict[str, Any] | None,
    ) -> AgentBridgeResult:
        payload = await self._get(
            service_name="Email Agent",
            url=f"{self._agent_url}{path}",
            params=params,
        )
        return AgentBridgeResult(payload=payload, raw_result="")

    async def _chat_json(self, *, task: str, expected_schema: str) -> AgentBridgeResult:
        raw_result = await self.chat(
            "You are serving a mobile REST API. Return ONLY valid JSON. "
            "Do not include markdown fences, commentary, explanations, or prose. "
            "Use this exact shape when possible:\n"
            f"{expected_schema}\n\n"
            f"Task:\n{task}"
        )
        return AgentBridgeResult(
            payload=parse_agent_json(raw_result),
            raw_result=raw_result,
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

    async def _get(
        self,
        *,
        service_name: str,
        url: str,
        params: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        try:
            async with httpx.AsyncClient(timeout=self._timeout) as client:
                response = await client.get(url, params=params)
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
