import json
import re
from dataclasses import dataclass
from typing import Any


@dataclass
class _Parser:
    """Small helper to parse structured JSON returned by LLM prompts."""

    def safe_parse(self, raw: Any, default: dict | None = None) -> dict:
        if default is None:
            default = {}

        if raw is None:
            return default

        if isinstance(raw, dict):
            return raw

        if not isinstance(raw, str):
            return default

        text = raw.strip()
        if not text:
            return default

        candidates = [text]
        fenced = re.search(r"```(?:json)?\s*(.*?)\s*```", text, re.DOTALL | re.IGNORECASE)
        if fenced:
            candidates.insert(0, fenced.group(1).strip())

        embedded = re.search(r"\{.*\}", text, re.DOTALL)
        if embedded:
            candidates.insert(0, embedded.group(0).strip())

        for candidate in candidates:
            try:
                parsed = json.loads(candidate)
                if isinstance(parsed, dict):
                    return parsed
            except json.JSONDecodeError:
                continue

        return default


parser = _Parser()


class LLMOutputParser:
    @staticmethod
    def parse(raw: Any, default: dict | None = None) -> dict:
        return parser.safe_parse(raw, default=default)
