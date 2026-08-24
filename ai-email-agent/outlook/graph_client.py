from __future__ import annotations

import json
from datetime import datetime, timedelta, timezone
from typing import Any
from urllib import error, parse, request


GRAPH_BASE_URL = "https://graph.microsoft.com/v1.0"


class OutlookGraphError(RuntimeError):
    def __init__(self, message: str, *, status_code: int = 0) -> None:
        super().__init__(message)
        self.status_code = status_code


class OutlookGraphClient:
    def __init__(
        self,
        *,
        graph_base_url: str = GRAPH_BASE_URL,
        tenant_id: str = "common",
        client_id: str = "",
        client_secret: str = "",
    ) -> None:
        self.graph_base_url = graph_base_url.rstrip("/")
        self.tenant_id = tenant_id or "common"
        self.client_id = client_id
        self.client_secret = client_secret

    def get_me(self, access_token: str) -> dict[str, Any]:
        return self._request_json(
            f"{self.graph_base_url}/me",
            access_token=access_token,
            method="GET",
        )

    def send_mail(
        self,
        *,
        access_token: str,
        subject: str,
        body: str,
        html_body: str = "",
        recipients: list[str],
        cc: list[str] | None = None,
        save_to_sent_items: bool = True,
    ) -> dict[str, Any]:
        payload = {
            "message": {
                "subject": subject,
                "body": {
                    "contentType": "HTML" if html_body else "Text",
                    "content": html_body or body,
                },
                "toRecipients": [_recipient(email) for email in recipients],
                "ccRecipients": [_recipient(email) for email in cc or []],
            },
            "saveToSentItems": save_to_sent_items,
        }
        self._request_json(
            f"{self.graph_base_url}/me/sendMail",
            access_token=access_token,
            method="POST",
            body=payload,
            expect_json=False,
            success_codes={202},
        )
        return {
            "provider": "microsoft_graph",
            "status": "accepted",
            "message_id": f"graph-sendmail-{_utc_stamp()}",
        }

    def refresh_access_token(self, refresh_token: str) -> dict[str, Any]:
        if not self.client_id:
            raise OutlookGraphError(
                "Microsoft client id is not configured for token refresh.",
                status_code=500,
            )
        token_url = (
            f"https://login.microsoftonline.com/{self.tenant_id}/oauth2/v2.0/token"
        )
        form = {
            "client_id": self.client_id,
            "grant_type": "refresh_token",
            "refresh_token": refresh_token,
            "scope": "offline_access User.Read Mail.Read Mail.ReadWrite Mail.Send",
        }
        if self.client_secret:
            form["client_secret"] = self.client_secret

        request_body = parse.urlencode(form).encode("utf-8")
        token_request = request.Request(
            token_url,
            data=request_body,
            headers={"Content-Type": "application/x-www-form-urlencoded"},
            method="POST",
        )
        try:
            with request.urlopen(token_request, timeout=30) as response:
                payload = json.loads(response.read().decode("utf-8"))
        except error.HTTPError as exc:
            raise OutlookGraphError(
                _read_error(exc) or "Microsoft token refresh failed.",
                status_code=exc.code,
            ) from exc
        except OSError as exc:
            raise OutlookGraphError(str(exc), status_code=0) from exc

        expires_in = int(payload.get("expires_in") or 3600)
        return {
            "access_token": str(payload.get("access_token") or ""),
            "refresh_token": str(payload.get("refresh_token") or ""),
            "expires_at": (
                datetime.now(timezone.utc)
                .replace(microsecond=0)
                + timedelta(seconds=expires_in)
            ).isoformat(),
        }

    def _request_json(
        self,
        url: str,
        *,
        access_token: str,
        method: str,
        body: dict[str, Any] | None = None,
        expect_json: bool = True,
        success_codes: set[int] | None = None,
    ) -> dict[str, Any]:
        data = json.dumps(body).encode("utf-8") if body is not None else None
        graph_request = request.Request(
            url,
            data=data,
            headers={
                "Authorization": f"Bearer {access_token}",
                "Accept": "application/json",
                "Content-Type": "application/json",
            },
            method=method,
        )
        allowed = success_codes or {200}
        try:
            with request.urlopen(graph_request, timeout=30) as response:
                if response.status not in allowed:
                    raise OutlookGraphError(
                        f"Microsoft Graph returned HTTP {response.status}.",
                        status_code=response.status,
                    )
                raw = response.read()
        except error.HTTPError as exc:
            raise OutlookGraphError(
                _read_error(exc) or "Microsoft Graph request failed.",
                status_code=exc.code,
            ) from exc
        except OSError as exc:
            raise OutlookGraphError(str(exc), status_code=0) from exc

        if not expect_json or not raw:
            return {}
        return json.loads(raw.decode("utf-8"))


def _recipient(email: str) -> dict[str, dict[str, str]]:
    return {"emailAddress": {"address": email}}


def _read_error(exc: error.HTTPError) -> str:
    try:
        raw = exc.read().decode("utf-8")
    except Exception:
        return ""
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError:
        return raw
    message = payload.get("error", {}).get("message")
    if isinstance(message, str):
        return message
    error_description = payload.get("error_description")
    if isinstance(error_description, str):
        return error_description
    return raw


def _utc_stamp() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%d%H%M%S")
