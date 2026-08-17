import json
import re
from dataclasses import dataclass, fields

try:
    from langchain_ollama import OllamaLLM
    from .prompts import email_analysis_prompt
except ImportError:
    OllamaLLM = None
    email_analysis_prompt = None


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
    "urgence",
    "asap",
    "immediately",
    "immediatement",
    "immédiatement",
    "critical",
    "critique",
    "emergency",
    "deadline",
    "date limite",
    "delai",
    "délai",
    "aujourd'hui",
    "ce soir",
    "avant midi",
    "dans les plus brefs",
    "des que possible",
    "dès que possible",
    "now",
    "right now",
    "not working",
    "ne fonctionne pas",
    "ne marche pas",
    "panne",
    "incident",
    "indisponible",
    "bloque",
    "bloqué",
    "outage",
    "service down",
)

_COMPLAINT_WORDS = (
    "complaint",
    "complain",
    "reclamation",
    "réclamation",
    "plainte",
    "disappointed",
    "decu",
    "déçu",
    "insatisfait",
    "unacceptable",
    "inadmissible",
    "angry",
    "colere",
    "colère",
    "frustrated",
    "problem",
    "probleme",
    "problème",
    "issue",
    "dysfonctionnement",
    "broken",
    "doesn't work",
    "does not work",
    "not working",
    "ne fonctionne pas",
    "ne marche pas",
    "refund",
    "remboursement",
    "bad experience",
)

_INFORMATION_WORDS = (
    "newsletter",
    "lettre d'information",
    "announcement",
    "annonce",
    "notification",
    "update",
    "mise a jour",
    "mise à jour",
    "fyi",
    "no-reply",
    "noreply",
    "automated",
    "automatique",
    "subscription",
    "abonnement",
    "news",
)

_COMMERCIAL_WORDS = (
    "invoice",
    "facture",
    "order",
    "commande",
    "payment",
    "paiement",
    "promotion",
    "offer",
    "offre",
    "discount",
    "remise",
    "pricing",
    "tarif",
    "prix",
    "contract",
    "contrat",
    "purchase",
    "achat",
    "renewal",
    "renouvellement",
)

_SUPPORT_WORDS = (
    "help",
    "aide",
    "support",
    "question",
    "how to",
    "how do i",
    "cannot",
    "can't",
    "issue",
    "account",
    "compte",
    "setup",
    "configure",
    "configuration",
    "password",
    "mot de passe",
)

_CAREER_WORDS = (
    "job",
    "career",
    "recruit",
    "recruiter",
    "application",
    "internship",
    "stage",
    "candidature",
    "emploi",
    "offre d'emploi",
    "développeur",
    "developpeur",
    "entretien",
    "interview",
    "poste",
    "linkedin jobs",
)

_INVITATION_WORDS = (
    "invitation",
    "invite",
    "inviting you",
    "rsvp",
    "event",
    "meeting",
    "appointment",
    "webinar",
    "conference",
    "summit",
    "camp",
    "evenement",
    "événement",
    "rendez-vous",
    "réunion",
    "reunion",
    "atelier",
    "conférence",
)

_ACTION_WORDS = (
    "please reply",
    "respond",
    "confirm",
    "let me know",
    "send me",
    "can you",
    "could you",
    "reply",
    "répondez",
    "repondez",
    "répondre",
    "repondre",
    "confirmer",
    "confirmez",
    "merci de",
    "veuillez",
    "pouvez-vous",
    "pourriez-vous",
)

_SOCIAL_NOTIFICATION_WORDS = (
    "reacted to",
    "a réagi",
    "a reagi",
    "accepted your invitation",
    "a accepté votre invitation",
    "a accepte votre invitation",
    "commentaires",
    "comments",
    "view profile",
    "découvrez son réseau",
    "decouvrez son reseau",
    "post",
    "linkedin",
)

_FRENCH_MARKERS = (
    " le ",
    " la ",
    " les ",
    " des ",
    " une ",
    "bonjour",
    "merci",
    "cordialement",
    "vous ",
    "votre",
    "nous ",
    "emploi",
    "candidature",
    "réponse",
    "reponse",
    "délai",
    "delai",
)

_ENGLISH_MARKERS = (
    " the ",
    " hello",
    " please",
    " thanks",
    " regards",
    " you ",
    " your ",
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
        cleaned = re.sub(r"https?://\S+", "", text)
        cleaned = re.sub(r"\s+", " ", cleaned).strip()
        if not cleaned:
            return ""
        match = re.split(r"[.!?]\s+", cleaned, maxsplit=1)
        return match[0][:260]

    @staticmethod
    def _detect_language(text: str) -> str:
        low = f" {text.lower()} "
        french_score = sum(1 for marker in _FRENCH_MARKERS if marker in low)
        english_score = sum(1 for marker in _ENGLISH_MARKERS if marker in low)
        if french_score > english_score:
            return "fr"
        if english_score > french_score:
            return "en"
        return "unknown"

    @staticmethod
    def _is_automated_sender(sender: str) -> bool:
        lowered = sender.lower()
        return any(
            token in lowered
            for token in ("no-reply", "noreply", "notifications@", "updates-", "newsletter")
        )

    @classmethod
    def _has_action_request(cls, text: str) -> bool:
        return cls._contains_any(text, _ACTION_WORDS) or "?" in text

    @classmethod
    def _is_career_related(cls, text: str) -> bool:
        return cls._contains_any(text, _CAREER_WORDS)

    @classmethod
    def _is_invitation(cls, text: str) -> bool:
        return cls._contains_any(text, _INVITATION_WORDS)

    @classmethod
    def _is_social_notification(cls, text: str) -> bool:
        return cls._contains_any(text, _SOCIAL_NOTIFICATION_WORDS)

    def _rule_based_classify(self, subject: str, sender: str, body: str):
        text = self._normalize_text(subject, sender, body)

        if self._contains_any(text, _COMPLAINT_WORDS):
            return ClassificationResult(
                category="RECLAMATION",
                confidence=0.92,
                reason="Complaint or dissatisfaction language detected",
            )

        if (
            self._is_automated_sender(sender)
            and self._is_social_notification(text)
            and not self._is_career_related(text)
        ):
            return ClassificationResult(
                category="INFORMATION",
                confidence=0.91,
                reason="Automated social notification with no direct reply required",
            )

        if self._contains_any(text, _COMMERCIAL_WORDS) or self._is_career_related(text):
            return ClassificationResult(
                category="COMMERCIAL",
                confidence=0.86,
                reason="Commercial, opportunity, recruitment, or transactional language detected",
            )

        if self._contains_any(text, _SUPPORT_WORDS) or self._has_action_request(text):
            return ClassificationResult(
                category="SUPPORT",
                confidence=0.86,
                reason="The email asks for help, confirmation, or a direct answer",
            )

        if self._is_invitation(text):
            return ClassificationResult(
                category="SUPPORT",
                confidence=0.82,
                reason="Invitation or meeting context may require a response",
            )

        if self._contains_any(text, _INFORMATION_WORDS):
            return ClassificationResult(
                category="INFORMATION",
                confidence=0.90,
                reason="Automated or informational email detected",
            )

        return ClassificationResult(
            category="INFORMATION",
            confidence=0.60,
            reason="No strong signals, defaulting to informational",
        )

    def _rule_based_priority(self, subject: str, sender: str, body: str, category: str):
        text = self._normalize_text(subject, sender, body)
        urgent_signal = self._contains_any(text, _URGENT_WORDS)
        action_signal = self._has_action_request(text)
        automated_sender = self._is_automated_sender(sender)
        career_signal = self._is_career_related(text)
        invitation_signal = self._is_invitation(text)

        if category == "RECLAMATION":
            if urgent_signal:
                return PriorityResult("URGENT", 9, "Complaint with urgent language")
            return PriorityResult("NORMAL", 7, "Complaint requiring timely response")

        if category == "SUPPORT":
            if urgent_signal:
                return PriorityResult("URGENT", 8, "Support or invitation marked as urgent")
            return PriorityResult("NORMAL", 6, "Support, invitation, or action request")

        if category == "COMMERCIAL":
            if urgent_signal:
                return PriorityResult("URGENT", 8, "Commercial message with deadline or urgency")
            if career_signal:
                return PriorityResult("NORMAL", 5, "Career or opportunity email may require a decision")
            return PriorityResult("NORMAL", 5, "Commercial follow-up")

        if invitation_signal and not automated_sender:
            if urgent_signal:
                return PriorityResult("URGENT", 8, "Direct invitation with urgent timing")
            return PriorityResult("NORMAL", 5, "Direct invitation may require a reply")

        if action_signal and not automated_sender:
            if urgent_signal:
                return PriorityResult("URGENT", 8, "Direct action request with urgency")
            return PriorityResult("NORMAL", 5, "Direct action request")

        return PriorityResult("LOW", 2, "Informational email with no immediate action")

    def _rule_based_summary(self, subject: str, sender: str, body: str):
        text = self._normalize_text(subject, sender, body)
        language = self._detect_language(f"{subject}\n{body}")
        if self._is_career_related(text) and subject:
            summary = (
                f"Opportunité professionnelle à examiner : {subject}"
                if language == "fr"
                else f"Career opportunity to review: {subject}"
            )
        elif self._is_social_notification(text) and subject:
            summary = (
                f"Notification sociale automatisée : {subject}"
                if language == "fr"
                else f"Automated social notification: {subject}"
            )
        else:
            summary = self._first_sentence(body) or self._first_sentence(subject)
        if not summary:
            summary = "Email summary unavailable"

        if self._contains_any(text, _COMPLAINT_WORDS):
            action_required = "Respond to the complaint and propose a resolution"
        elif self._is_career_related(text):
            action_required = "Review the opportunity and decide whether to apply or respond"
        elif self._is_invitation(text):
            action_required = "Decide whether to accept the invitation or ask for more details"
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
            language=language,
        )

    def _rule_based_reply(
        self,
        subject: str,
        sender: str,
        body: str,
        category: str,
        priority: str,
        summary: str,
    ):
        text = self._normalize_text(subject, sender, body)
        language = self._detect_language(f"{subject}\n{body}")
        use_french = language == "fr"
        is_automated = self._is_automated_sender(sender)
        is_career = self._is_career_related(text)
        is_invitation = self._is_invitation(text)
        is_urgent = priority == "URGENT"
        reply_subject = f"Re: {subject}" if subject else "Re: Your message"

        if category == "RECLAMATION":
            reply = (
                "Bonjour,\n\n"
                "Merci pour votre message. Je suis désolé pour le problème rencontré et je vais l'examiner en priorité. "
                "Pouvez-vous me confirmer les détails utiles afin que je puisse avancer rapidement ?\n\n"
                "Cordialement,"
                if use_french
                else "Hello,\n\n"
                "Thank you for letting me know. I am sorry about the issue and I will review it as a priority. "
                "Could you please confirm the key details so I can move this forward quickly?\n\n"
                "Best regards,"
            )
            tone = "professional"
        elif category == "SUPPORT":
            if is_invitation:
                reply = (
                    "Bonjour,\n\n"
                    "Merci pour votre invitation. Je vais vérifier ma disponibilité et revenir vers vous avec une réponse claire. "
                    "Si vous avez un programme ou des détails pratiques à partager, je suis preneur.\n\n"
                    "Cordialement,"
                    if use_french
                    else "Hello,\n\n"
                    "Thank you for the invitation. I will check my availability and get back to you with a clear answer. "
                    "If there is an agenda or any practical detail to share, please feel free to send it over.\n\n"
                    "Best regards,"
                )
            else:
                reply = (
                    "Bonjour,\n\n"
                    "Merci pour votre demande. Je vais vérifier ce point et revenir vers vous avec une réponse précise. "
                    "Si vous avez des informations complémentaires, vous pouvez me les transmettre.\n\n"
                    "Cordialement,"
                    if use_french
                    else "Hello,\n\n"
                    "Thank you for your message. I will review this point and get back to you with a clear answer. "
                    "If you have any additional details, please send them over.\n\n"
                    "Best regards,"
                )
            tone = "helpful"
        elif category == "COMMERCIAL":
            if is_career:
                reply = (
                    "Bonjour,\n\n"
                    "Merci pour cette opportunité. Je vais examiner l'offre et les informations partagées avec attention. "
                    "Je reviendrai vers vous si mon profil correspond ou si j'ai besoin de précisions.\n\n"
                    "Cordialement,"
                    if use_french
                    else "Hello,\n\n"
                    "Thank you for sharing this opportunity. I will review the role and the details carefully. "
                    "I will get back to you if my profile is a good fit or if I need any clarification.\n\n"
                    "Best regards,"
                )
            else:
                timing = (
                    "Je traiterai ce point rapidement compte tenu du délai mentionné. "
                    if use_french and is_urgent
                    else "I will handle this quickly given the timing mentioned. "
                    if is_urgent
                    else ""
                )
                reply = (
                    "Bonjour,\n\n"
                    f"Merci pour ces informations. Je vais examiner les éléments partagés et vous confirmer la suite à donner. {timing}\n\n"
                    "Cordialement,"
                    if use_french
                    else "Hello,\n\n"
                    f"Thank you for the information. I will review the details and confirm the next step. {timing}\n\n"
                    "Best regards,"
                )
            tone = "professional"
        elif is_automated:
            reply = (
                "Bonjour,\n\n"
                "Merci pour cette information. Je vais la consulter et prendre les mesures nécessaires si elle me concerne directement.\n\n"
                "Cordialement,"
                if use_french
                else "Hello,\n\n"
                "Thank you for the update. I will review it and take any necessary action if it directly concerns me.\n\n"
                "Best regards,"
            )
            tone = "courteous"
        else:
            reply = (
                "Bonjour,\n\n"
                "Merci pour votre message. Je prends note des informations transmises et reviendrai vers vous si une action est nécessaire.\n\n"
                "Cordialement,"
                if use_french
                else "Hello,\n\n"
                "Thank you for your message. I have noted the information and will get back to you if any action is needed.\n\n"
                "Best regards,"
            )
            tone = "neutral"

        return ReplyResult(reply=reply, reply_subject=reply_subject, tone=tone)

    def classify(self, subject: str, sender: str, body: str):
        if self.analysis_chain is not None:
            try:
                raw = self.analysis_chain.invoke(
                    {"subject": subject, "sender": sender, "body": body, "category": ""}
                )
                return self._parse_model_result(
                    raw, self._rule_based_classify(subject, sender, body)
                )
            except Exception:
                pass
        return self._rule_based_classify(subject, sender, body)

    def prioritize(self, subject: str, sender: str, body: str, category: str):
        if self.analysis_chain is not None:
            try:
                raw = self.analysis_chain.invoke(
                    {
                        "subject": subject,
                        "sender": sender,
                        "body": body,
                        "category": category,
                    }
                )
                return self._parse_model_result(
                    raw, self._rule_based_priority(subject, sender, body, category)
                )
            except Exception:
                pass
        return self._rule_based_priority(subject, sender, body, category)

    def summarize(self, subject: str, sender: str, body: str):
        if self.analysis_chain is not None:
            try:
                raw = self.analysis_chain.invoke(
                    {"subject": subject, "sender": sender, "body": body, "category": ""}
                )
                return self._parse_model_result(
                    raw, self._rule_based_summary(subject, sender, body)
                )
            except Exception:
                pass
        return self._rule_based_summary(subject, sender, body)

    def suggest_reply(
        self,
        subject: str,
        sender: str,
        body: str,
        category: str,
        priority: str,
        summary: str,
    ):
        if self.analysis_chain is not None:
            try:
                raw = self.analysis_chain.invoke(
                    {
                        "subject": subject,
                        "sender": sender,
                        "body": body,
                        "category": category,
                        "priority": priority,
                        "summary": summary,
                    }
                )
                return self._parse_model_result(
                    raw,
                    self._rule_based_reply(
                        subject, sender, body, category, priority, summary
                    ),
                )
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
                try:
                    payload = json.loads(raw.strip())
                except Exception:
                    payload = {}
        if "reply" not in payload and "suggested_reply" in payload:
            payload["reply"] = payload["suggested_reply"]
        merged = dict(fallback.__dict__)
        merged.update({k: v for k, v in payload.items() if v is not None})
        allowed = {field.name for field in fields(fallback)}
        return type(fallback)(**{key: value for key, value in merged.items() if key in allowed})
