from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Any


RISKY_PHRASES = (
    "guarantee",
    "guaranteed",
    "we will definitely",
    "legal advice",
    "financial advice",
    "password",
    "secret",
    "token",
    "api key",
    "confidential",
    "private data",
)

URGENCY_WORDS = (
    "urgent",
    "immediately",
    "as soon as possible",
    "priority",
    "critical",
    "emergency",
    "important",
    "dans les plus brefs delais",
    "urgence",
    "urgent",
    "prioritaire",
)

POLITE_WORDS = (
    "thank",
    "thanks",
    "please",
    "regards",
    "sincerely",
    "bonjour",
    "merci",
    "cordialement",
    "salutations",
)

STOP_WORDS = {
    "the",
    "and",
    "for",
    "you",
    "your",
    "avec",
    "pour",
    "dans",
    "nous",
    "vous",
    "une",
    "des",
    "les",
    "that",
    "this",
    "from",
    "have",
    "will",
    "not",
}


@dataclass
class RuleResult:
    score: float = 1.0
    reasons: list[str] = field(default_factory=list)
    risk_flags: list[str] = field(default_factory=list)

    def penalize(self, amount: float, reason: str, risk_flag: str | None = None) -> None:
        self.score = max(0.0, self.score - amount)
        self.reasons.append(reason)
        if risk_flag is not None:
            self.risk_flags.append(risk_flag)


def evaluate_rules(
    *,
    email: dict[str, Any],
    analysis: dict[str, Any],
    agent_response: dict[str, Any],
) -> RuleResult:
    result = RuleResult()

    email_text = _email_text(email)
    reply_text = _reply_text(agent_response)

    if not reply_text:
        result.penalize(0.75, "The proposed response is empty.", "empty_response")
        return result

    if len(reply_text.split()) < 12:
        result.penalize(0.25, "The proposed response is too short.", "short_response")

    risky_hits = _contains_any(reply_text, RISKY_PHRASES)
    if risky_hits:
        result.penalize(
            0.45,
            f"The response contains risky wording: {', '.join(risky_hits)}.",
            "risky_language",
        )

    if _is_urgent(analysis, email_text) and not _contains_any(reply_text, URGENCY_WORDS):
        result.penalize(
            0.18,
            "The email is urgent but the response does not acknowledge urgency.",
            "urgency_not_acknowledged",
        )

    if _requires_action(analysis) and not _has_action_signal(reply_text):
        result.penalize(
            0.18,
            "The analysis indicates required action, but the response is vague.",
            "missing_action",
        )

    relevance = _token_overlap(email_text, reply_text)
    if relevance < 0.08:
        result.penalize(
            0.35,
            "The response appears weakly related to the email context.",
            "low_relevance",
        )
    elif relevance < 0.16:
        result.penalize(
            0.15,
            "The response only partially covers the email context.",
            "partial_relevance",
        )

    if not _contains_any(reply_text, POLITE_WORDS):
        result.penalize(
            0.10,
            "The response lacks a clear professional courtesy marker.",
            "tone_uncertain",
        )

    if _language_mismatch(email_text, reply_text):
        result.penalize(
            0.15,
            "The response language seems different from the email language.",
            "language_mismatch",
        )

    if not result.reasons:
        result.reasons.append("The response is relevant, safe and professional.")

    return result


def _email_text(email: dict[str, Any]) -> str:
    return " ".join(
        str(email.get(key, ""))
        for key in ("subject", "sender", "body", "body_preview", "summary")
    )


def _reply_text(agent_response: dict[str, Any]) -> str:
    return str(
        agent_response.get("reply_body")
        or agent_response.get("body")
        or agent_response.get("reply")
        or agent_response.get("suggested_reply")
        or ""
    ).strip()


def _contains_any(text: str, phrases: tuple[str, ...]) -> list[str]:
    lowered = text.lower()
    return [phrase for phrase in phrases if phrase in lowered]


def _is_urgent(analysis: dict[str, Any], email_text: str) -> bool:
    priority = str(analysis.get("priority", "")).upper()
    urgency_score = _number(analysis.get("urgency_score"))
    return (
        priority == "URGENT"
        or urgency_score >= 8
        or bool(_contains_any(email_text, URGENCY_WORDS))
    )


def _requires_action(analysis: dict[str, Any]) -> bool:
    action = str(analysis.get("action_required", "")).strip().lower()
    return bool(action and action not in {"none", "no", "false", "n/a"})


def _has_action_signal(text: str) -> bool:
    lowered = text.lower()
    return any(
        phrase in lowered
        for phrase in (
            "we will",
            "i will",
            "we are",
            "i am",
            "please",
            "nous allons",
            "nous sommes",
            "je vais",
            "veuillez",
            "merci de",
        )
    )


def _token_overlap(left: str, right: str) -> float:
    left_tokens = _tokens(left)
    right_tokens = _tokens(right)
    if not left_tokens or not right_tokens:
        return 0.0

    return len(left_tokens & right_tokens) / max(len(left_tokens), 1)


def _tokens(text: str) -> set[str]:
    return {
        token
        for token in re.findall(r"[a-zA-Z]{4,}", text.lower())
        if token not in STOP_WORDS
    }


def _language_mismatch(email_text: str, reply_text: str) -> bool:
    email_fr = _looks_french(email_text)
    reply_fr = _looks_french(reply_text)
    email_en = _looks_english(email_text)
    reply_en = _looks_english(reply_text)

    return (email_fr and reply_en and not reply_fr) or (email_en and reply_fr and not reply_en)


def _looks_french(text: str) -> bool:
    lowered = text.lower()
    return any(word in lowered for word in ("bonjour", "merci", "veuillez", "nous", "votre"))


def _looks_english(text: str) -> bool:
    lowered = text.lower()
    return any(word in lowered for word in ("hello", "thank", "please", "regards", "your"))


def _number(value: Any) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return 0.0
