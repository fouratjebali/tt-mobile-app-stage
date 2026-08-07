import json
import re
from typing import Any


def parse_agent_json(raw_result: str) -> dict[str, Any]:
    cleaned = raw_result.strip()
    if not cleaned:
        return {}

    cleaned = _strip_markdown_fence(cleaned)

    try:
        payload = json.loads(cleaned)
    except json.JSONDecodeError:
        payload = _parse_embedded_json(cleaned)

    return payload if isinstance(payload, dict) else {}


def list_from_payload(payload: dict[str, Any], *keys: str) -> list[dict[str, Any]]:
    for key in keys:
        value = payload.get(key)
        if isinstance(value, list):
            return [item for item in value if isinstance(item, dict)]

    return []


def _strip_markdown_fence(value: str) -> str:
    if not value.startswith("```"):
        return value

    lines = value.splitlines()
    if len(lines) >= 3 and lines[-1].strip() == "```":
        return "\n".join(lines[1:-1]).strip()

    return value


def _parse_embedded_json(value: str) -> Any:
    match = re.search(r"(\{.*\})", value, flags=re.DOTALL)
    if not match:
        return {}

    try:
        return json.loads(match.group(1))
    except json.JSONDecodeError:
        return {}
