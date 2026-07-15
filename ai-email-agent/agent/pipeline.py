from dataclasses import dataclass
from typing import List

from gmail.reader import Email
from agent.chains import (
    EmailChains,
    ClassificationResult,
    PriorityResult,
    SummaryResult,
    ReplyResult,
)


@dataclass
class EmailAnalysisResult:
    email: Email
    classification: ClassificationResult
    priority: PriorityResult
    summary: SummaryResult
    reply: ReplyResult

    def is_urgent(self) -> bool:
        return self.priority.priority == "URGENT" or self.priority.urgency_score >= 8

    def needs_reply(self) -> bool:
        return self.classification.category != "INFORMATION"

    def display_dict(self) -> dict:
        return {
            "subject": self.email.subject,
            "sender": self.email.sender,
            "category": self.classification.category,
            "confidence": self.classification.confidence,
            "priority": self.priority.priority,
            "urgency_score": self.priority.urgency_score,
            "summary": self.summary.summary,
            "action": self.summary.action_required,
            "language": self.summary.language,
            "suggested_reply": self.reply.reply,
            "reply_subject": self.reply.reply_subject,
        }


class EmailPipeline:
    def __init__(self):
        self.chains = EmailChains()

    def analyze(self, email: Email) -> EmailAnalysisResult:
        classification = self.chains.classify(
            subject=email.subject,
            sender=email.sender,
            body=email.body,
        )
        priority = self.chains.prioritize(
            subject=email.subject,
            sender=email.sender,
            body=email.body,
            category=classification.category,
        )
        summary = self.chains.summarize(
            subject=email.subject,
            sender=email.sender,
            body=email.body,
        )
        reply = self.chains.suggest_reply(
            subject=email.subject,
            sender=email.sender,
            body=email.body,
            category=classification.category,
            priority=priority.priority,
            summary=summary.summary,
        )
        return EmailAnalysisResult(
            email=email,
            classification=classification,
            priority=priority,
            summary=summary,
            reply=reply,
        )

    def analyze_batch(self, emails: List[Email]) -> List[EmailAnalysisResult]:
        return [self.analyze(email) for email in emails]
