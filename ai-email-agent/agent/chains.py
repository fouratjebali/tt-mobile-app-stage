import re
from dataclasses import dataclass
from types import SimpleNamespace

try:
    from langchain_ollama import OllamaLLM
    from .prompts import (
        email_analysis_prompt,
        reply_prompt,
        summary_prompt,
        CLASSIFICATION_PROMPT,
        PRIORITY_PROMPT,
        BULK_PERSONALIZED_PROMPT,
        CONVERSATION_SUMMARY_PROMPT,
    )
except ImportError:
    OllamaLLM = None
    email_analysis_prompt = None
    reply_prompt = None
    summary_prompt = None
    CLASSIFICATION_PROMPT = None
    PRIORITY_PROMPT = None
    BULK_PERSONALIZED_PROMPT = None
    CONVERSATION_SUMMARY_PROMPT = None


if OllamaLLM is not None and email_analysis_prompt is not None:
    llm = OllamaLLM(model="llama3")
    analysis_chain = email_analysis_prompt | llm
else:
    llm = None
    analysis_chain = None


@dataclass
class ClassificationResult:
    category: str
    confidence: float
    reason: str


@dataclass
class PriorityResult:
    priority: str
    urgency_score: int
    reason: str


@dataclass
class SummaryResult:
    summary: str
    action_required: str
    language: str


@dataclass
class ReplyResult:
    reply: str
    reply_subject: str
    tone: str


_URGENT_WORDS = (
    "urgent",
    "asap",
    "immediately",
    "critical",
    "emergency",
    "deadline",
    "now",
    "right now",
    "not working",
    "outage",
    "service down",
)

_COMPLAINT_WORDS = (
    "complaint",
    "complain",
    "disappointed",
    "unacceptable",
    "angry",
    "frustrated",
    "problem",
    "issue",
    "broken",
    "doesn't work",
    "does not work",
    "not working",
    "refund",
    "bad experience",
)

_INFORMATION_WORDS = (
    "newsletter",
    "announcement",
    "notification",
    "update",
    "fyi",
    "no-reply",
    "noreply",
    "automated",
    "subscription",
    "news",
)

_COMMERCIAL_WORDS = (
    "invoice",
    "order",
    "payment",
    "promotion",
    "offer",
    "discount",
    "pricing",
    "contract",
    "purchase",
    "renewal",
)

_SUPPORT_WORDS = (
    "help",
    "support",
    "question",
    "how to",
    "how do i",
    "cannot",
    "can't",
    "cannot",
    "issue",
    "account",
    "setup",
    "configure",
    "configuration",
    "password",
)


class EmailChains:
    def __init__(self):
        self.analysis_chain = analysis_chain

    def _missing_dependency(self):
        return False

    @staticmethod
    def _normalize_text(subject: str = "", sender: str = "", body: str = "") -> str:
        return f"{subject}\n{sender}\n{body}".lower()

    @staticmethod
    def _contains_any(text: str, words: tuple[str, ...]) -> bool:
        return any(word in text for word in words)

    @staticmethod
    def _first_sentence(text: str) -> str:
        cleaned = re.sub(r"\s+", " ", text).strip()
        if not cleaned:
            return ""
        match = re.split(r"[.!?]\s+", cleaned, maxsplit=1)
        return match[0][:220]

    @staticmethod
    def _detect_language(text: str) -> str:
        french_markers = (" le ", " la ", " les ", "bonjour", "merci", "cordialement", "vous ")
        english_markers = (" the ", " hello", " please", " thanks", " regards", " you ")
        low = f" {text.lower()} "
        french_score = sum(1 for marker in french_markers if marker in low)
        english_score = sum(1 for marker in english_markers if marker in low)
        if french_score > english_score:
            return "fr"
        if english_score > french_score:
            return "en"
        return "unknown"

    def _rule_based_classify(self, subject: str, sender: str, body: str):
        text = self._normalize_text(subject, sender, body)

        if self._contains_any(text, _COMPLAINT_WORDS):
            return ClassificationResult(
                category="RECLAMATION",
                confidence=0.92,
                reason="Complaint or dissatisfaction language detected",
            )

        if self._contains_any(text, _INFORMATION_WORDS):
            return ClassificationResult(
                category="INFORMATION",
                confidence=0.90,
                reason="Automated or informational email detected",
            )

        if self._contains_any(text, _COMMERCIAL_WORDS):
            return ClassificationResult(
                category="COMMERCIAL",
                confidence=0.88,
                reason="Commercial or transactional language detected",
            )

        if self._contains_any(text, _SUPPORT_WORDS) or "?" in body:
            return ClassificationResult(
                category="SUPPORT",
                confidence=0.84,
                reason="Help request or question detected",
            )

        return ClassificationResult(
            category="INFORMATION",
            confidence=0.60,
            reason="No strong signals, defaulting to informational",
        )

    def _rule_based_priority(self, subject: str, sender: str, body: str, category: str):
        text = self._normalize_text(subject, sender, body)
        urgent_signal = self._contains_any(text, _URGENT_WORDS)

        if category == "RECLAMATION":
            if urgent_signal:
                return PriorityResult(priority="URGENT", urgency_score=9, reason="Complaint with urgent language")
            return PriorityResult(priority="NORMAL", urgency_score=7, reason="Complaint requiring timely response")

        if category == "SUPPORT":
            if urgent_signal:
                return PriorityResult(priority="URGENT", urgency_score=8, reason="Support issue marked as urgent")
            return PriorityResult(priority="NORMAL", urgency_score=6, reason="Standard support request")

        if category == "COMMERCIAL":
            if urgent_signal:
                return PriorityResult(priority="URGENT", urgency_score=8, reason="Commercial message with deadline or urgency")
            return PriorityResult(priority="NORMAL", urgency_score=5, reason="Commercial follow-up")

        return PriorityResult(priority="LOW", urgency_score=2, reason="Informational email with no immediate action")

    def _rule_based_summary(self, subject: str, sender: str, body: str):
        text = self._normalize_text(subject, sender, body)
        summary = self._first_sentence(body) or self._first_sentence(subject)
        if not summary:
            summary = "Email summary unavailable"

        if self._contains_any(text, _COMPLAINT_WORDS):
            action_required = "Respond to the complaint and propose a resolution"
        elif self._contains_any(text, _SUPPORT_WORDS):
            action_required = "Answer the support question"
        elif self._contains_any(text, _COMMERCIAL_WORDS):
            action_required = "Review the commercial details and decide on next steps"
        elif self._contains_any(text, _INFORMATION_WORDS):
            action_required = "No immediate action required"
        else:
            action_required = "Review and decide whether a reply is needed"

        return SummaryResult(
            summary=summary,
            action_required=action_required,
            language=self._detect_language(body or subject),
        )

    def _rule_based_reply(self, subject: str, sender: str, body: str, category: str, priority: str, summary: str):
        text = self._normalize_text(subject, sender, body)

        if category == "RECLAMATION":
            reply_subject = f"Re: {subject}" if subject else "Re: Your message"
            reply = (
                "Bonjour,\n\n"
                "Merci pour votre message et pour avoir signalé ce problème. "
                "Nous sommes désolés pour la gêne occasionnée et nous allons examiner la situation rapidement. "
                "Pouvez-vous nous confirmer les détails nécessaires afin que nous puissions avancer ?\n\n"
                "Cordialement,"
            )
            tone = "professional"
        elif category == "SUPPORT":
            reply_subject = f"Re: {subject}" if subject else "Re: Your question"
            reply = (
                "Bonjour,\n\n"
                "Merci pour votre demande. Nous allons vérifier le point soulevé et revenir vers vous avec une réponse claire. "
                "Si besoin, n'hésitez pas à nous envoyer des informations supplémentaires.\n\n"
                "Cordialement,"
            )
            tone = "helpful"
        elif category == "COMMERCIAL":
            reply_subject = f"Re: {subject}" if subject else "Re: Your message"
            reply = (
                "Bonjour,\n\n"
                "Merci pour ces informations. Nous allons les examiner et vous confirmer la suite donnée dans les meilleurs délais.\n\n"
                "Cordialement,"
            )
            tone = "professional"
        elif self._contains_any(text, ("linkedin", "demande de connexion", "connection request", "invitation")):
            reply_subject = f"Re: {subject}" if subject else "Re: Your invitation"
            reply = (
                "Bonjour,\n\n"
                "Merci pour votre invitation et pour la prise de contact. "
                "Je vais la consulter avec attention et revenir vers vous si nécessaire.\n\n"
                "Cordialement,"
            )
            tone = "courteous"
        else:
            reply_subject = f"Re: {subject}" if subject else "Re: Your message"
            reply = (
                "Bonjour,\n\n"
                "Merci pour votre message. Je prends note de cette information et reviendrai vers vous si une action est nécessaire.\n\n"
                "Cordialement,"
            )
            tone = "neutral"

        return ReplyResult(
            reply_subject=reply_subject,
            reply=reply,
            tone=tone,
        )

    def classify(self, subject: str, sender: str, body: str):
        if self.analysis_chain is not None:
            try:
                raw = self.analysis_chain.invoke({
                    "subject": subject,
                    "sender": sender,
                    "body": body,
                })
                return self._parse_model_result(raw, self._rule_based_classify(subject, sender, body))
            except Exception:
                pass
        return self._rule_based_classify(subject, sender, body)

    def prioritize(self, subject: str, sender: str, body: str, category: str):
        if self.analysis_chain is not None:
            try:
                raw = self.analysis_chain.invoke({
                    "subject": subject,
                    "sender": sender,
                    "body": body,
                    "category": category,
                })
                return self._parse_model_result(raw, self._rule_based_priority(subject, sender, body, category))
            except Exception:
                pass
        return self._rule_based_priority(subject, sender, body, category)

    def summarize(self, subject: str, sender: str, body: str):
        if self.analysis_chain is not None:
            try:
                raw = self.analysis_chain.invoke({
                    "subject": subject,
                    "sender": sender,
                    "body": body,
                })
                return self._parse_model_result(raw, self._rule_based_summary(subject, sender, body))
            except Exception:
                pass
        return self._rule_based_summary(subject, sender, body)

    def suggest_reply(self, subject: str, sender: str, body: str, category: str, priority: str, summary: str):
        if self.analysis_chain is not None:
            try:
                raw = self.analysis_chain.invoke({
                    "subject": subject,
                    "sender": sender,
                    "body": body,
                    "category": category,
                    "priority": priority,
                    "summary": summary,
                })
                return self._parse_model_result(raw, self._rule_based_reply(subject, sender, body, category, priority, summary))
            except Exception:
                pass
        return self._rule_based_reply(subject, sender, body, category, priority, summary)

    @staticmethod
    def _parse_model_result(raw, fallback):
        if isinstance(raw, dict):
            payload = raw
        else:
            payload = {}
            if isinstance(raw, str):
                text = raw.strip()
                try:
                    import json
                    payload = json.loads(text)
                except Exception:
                    payload = {}
        merged = dict(fallback.__dict__)
        merged.update({k: v for k, v in payload.items() if v is not None})
        return type(fallback)(**merged)
