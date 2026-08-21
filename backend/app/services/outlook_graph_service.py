import re
from html import unescape
from typing import Any
from urllib.parse import quote

import httpx
from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.auth import User
from app.repositories.auth_repository import AuthRepository


class OutlookGraphService:
    def __init__(self, db: Session) -> None:
        self._auth_repository = AuthRepository(db)
        self._base_url = "https://graph.microsoft.com/v1.0"
        self._timeout = settings.HTTP_TIMEOUT_SECONDS

    async def list_unread_messages(
        self,
        *,
        user: User,
        max_results: int,
    ) -> list[dict[str, Any]]:
        payload = await self._request(
            user=user,
            method="GET",
            path="/me/mailFolders/inbox/messages",
            params={
                "$top": max_results,
                "$filter": "isRead eq false",
                "$select": (
                    "id,conversationId,subject,from,bodyPreview,"
                    "receivedDateTime,isRead,body"
                ),
            },
        )
        messages = payload.get("value") if isinstance(payload, dict) else None
        if not isinstance(messages, list):
            return []
        normalized = [self._normalize_message(message) for message in messages]
        normalized.sort(
            key=lambda message: str(message.get("received_at") or ""),
            reverse=True,
        )
        return normalized

    async def get_message(self, *, user: User, message_id: str) -> dict[str, Any] | None:
        try:
            payload = await self._request(
                user=user,
                method="GET",
                path=f"/me/messages/{_message_path_id(message_id)}",
                params={
                    "$select": (
                        "id,conversationId,subject,from,bodyPreview,"
                        "receivedDateTime,isRead,body"
                    ),
                },
            )
        except HTTPException as error:
            if error.status_code == status.HTTP_404_NOT_FOUND:
                return None
            raise
        return self._normalize_message(payload)

    async def send_reply(
        self,
        *,
        user: User,
        message_id: str,
        body: str,
    ) -> dict[str, Any]:
        draft = await self._request(
            user=user,
            method="POST",
            path=f"/me/messages/{_message_path_id(message_id)}/createReply",
            json={},
        )
        draft_id = str(draft.get("id") or "").strip()
        if not draft_id:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Outlook could not create a reply draft.",
            )

        await self._request(
            user=user,
            method="PATCH",
            path=f"/me/messages/{_message_path_id(draft_id)}",
            json={
                "body": {
                    "contentType": "Text",
                    "content": body,
                },
            },
            expect_body=False,
        )
        await self._request(
            user=user,
            method="POST",
            path=f"/me/messages/{_message_path_id(draft_id)}/send",
            json={},
            expect_body=False,
        )
        return {"status": "sent", "message_id": draft_id}

    async def send_mail(
        self,
        *,
        user: User,
        to: str,
        subject: str,
        body: str,
    ) -> dict[str, Any]:
        await self._request(
            user=user,
            method="POST",
            path="/me/sendMail",
            json={
                "message": {
                    "subject": subject,
                    "body": {
                        "contentType": "Text",
                        "content": body,
                    },
                    "toRecipients": [
                        {
                            "emailAddress": {
                                "address": to,
                            },
                        },
                    ],
                },
                "saveToSentItems": True,
            },
            expect_body=False,
        )
        return {"status": "sent", "to": to, "subject": subject}

    async def _request(
        self,
        *,
        user: User,
        method: str,
        path: str,
        params: dict[str, Any] | None = None,
        json: dict[str, Any] | None = None,
        expect_body: bool = True,
    ) -> dict[str, Any]:
        token = self._access_token(user)
        try:
            async with httpx.AsyncClient(timeout=self._timeout) as client:
                response = await client.request(
                    method,
                    f"{self._base_url}{path}",
                    params=params,
                    json=json,
                    headers={"Authorization": f"Bearer {token}"},
                )
                response.raise_for_status()
        except httpx.HTTPStatusError as error:
            detail = _graph_error_detail(error.response)
            status_code = (
                status.HTTP_401_UNAUTHORIZED
                if error.response.status_code in (401, 403)
                else error.response.status_code
            )
            raise HTTPException(status_code=status_code, detail=detail) from error
        except httpx.HTTPError as error:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Outlook mail service is temporarily unavailable.",
            ) from error

        if not expect_body or response.status_code == status.HTTP_202_ACCEPTED:
            return {}
        payload = response.json()
        if not isinstance(payload, dict):
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Outlook returned an invalid mail response.",
            )
        return payload

    def _access_token(self, user: User) -> str:
        session = self._auth_repository.get_latest_session_for_user(user)
        token = session.google_access_token if session is not None else ""
        if not token:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Please reconnect your Outlook account.",
            )
        return token

    def _normalize_message(self, message: dict[str, Any]) -> dict[str, Any]:
        body = message.get("body") if isinstance(message.get("body"), dict) else {}
        body_content = str(body.get("content") or "")
        sender = _sender_text(message.get("from"))
        return {
            "id": str(message.get("id") or ""),
            "thread_id": message.get("conversationId"),
            "subject": str(message.get("subject") or "(no subject)"),
            "sender": sender,
            "body_preview": str(message.get("bodyPreview") or ""),
            "body": _html_to_text(body_content),
            "received_at": message.get("receivedDateTime"),
            "is_read": bool(message.get("isRead", False)),
            "status": "PENDING_ANALYSIS",
        }


def _sender_text(value: object) -> str:
    if not isinstance(value, dict):
        return ""
    address = value.get("emailAddress")
    if not isinstance(address, dict):
        return ""
    name = str(address.get("name") or "").strip()
    email = str(address.get("address") or "").strip()
    if name and email:
        return f"{name} <{email}>"
    return email or name


def _html_to_text(value: str) -> str:
    text = re.sub(r"(?is)<(br|p|div|li|tr)\b[^>]*>", "\n", value)
    text = re.sub(r"(?is)<style.*?</style>|<script.*?</script>", "", text)
    text = re.sub(r"(?s)<[^>]+>", " ", text)
    text = unescape(text)
    text = re.sub(r"[ \t\r\f\v]+", " ", text)
    text = re.sub(r"\n\s+", "\n", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def _message_path_id(value: str) -> str:
    return quote(value, safe="")


def _graph_error_detail(response: httpx.Response) -> str:
    try:
        payload = response.json()
    except ValueError:
        return "Outlook could not complete this mail action."

    error = payload.get("error") if isinstance(payload, dict) else None
    if isinstance(error, dict):
        message = str(error.get("message") or "").strip()
        if message:
            return message
    return "Outlook could not complete this mail action."
