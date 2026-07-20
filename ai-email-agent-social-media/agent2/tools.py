"""
Outils de l'Agent 2, exposés au LLM via le pattern LangChain @tool,
"""

import json
import os

from agent2.sentiment import SentimentAnalyzer, SentimentResult
from agent2.social_reader import fetch_social_events, debug_dump_raw_body, get_social_event_by_id

try:
    from langchain_core.tools import tool
except ImportError:
    class _SimpleTool:
        def __init__(self, func):
            self.func = func
            self.name = func.__name__

        def invoke(self, input_data=None):
            input_data = input_data or {}
            if not isinstance(input_data, dict):
                raise TypeError("Tool input must be a dictionary")
            return self.func(**input_data)

        def __call__(self, *args, **kwargs):
            return self.func(*args, **kwargs)

    def tool(func):
        return _SimpleTool(func)


# Instances partagées (évite de recharger le modèle de sentiment / le LLM à chaque appel)
_sentiment_analyzer = None


def _get_sentiment_analyzer() -> SentimentAnalyzer:
    global _sentiment_analyzer
    if _sentiment_analyzer is None:
        _sentiment_analyzer = SentimentAnalyzer()
    return _sentiment_analyzer


def _analyze_sentiment(text: str) -> SentimentResult:
    if os.getenv("AGENT2_MOCK_SENTIMENT", "").lower() in {"1", "true", "yes"}:
        cleaned = (text or "").strip()
        return SentimentResult(
            text=cleaned,
            label="NEUTRAL",
            score=0.0,
            raw_scores={"mock": 1.0},
        )

    return _get_sentiment_analyzer().analyze(text)


# OUTIL 1 : Analyse de sentiment (bibliothèque dédiée, pas de LLM)
@tool
def analyze_sentiment(text: str) -> str:
    """
    Analyzes the sentiment of a social media comment or message using a
    dedicated sentiment-analysis model (not the LLM).
    Returns POSITIVE, NEUTRAL, or NEGATIVE with a confidence score.

    Args:
        text: the comment/message text to analyze

    Returns:
        JSON string with label, confidence score, and detailed scores per class
    """
    result = _analyze_sentiment(text)
    return json.dumps({
        "text": result.text[:200],
        "label": result.label,
        "score": result.score,
        "raw_scores": result.raw_scores,
    }, ensure_ascii=False)


# OUTIL 2 : Lire les notifications de réseaux sociaux dans Gmail
@tool
def read_social_notifications(
    query: str = "(facebook OR instagram OR linkedin OR tiktok) newer_than:7d",
    max_results: int = 20,
) -> str:
    """
    Reads Gmail notification emails about social media comments/likes and
    extracts structured info (platform, author, comment text, event type).
    Requires the admin to have configured email notifications for social
    platforms (Facebook, Instagram, LinkedIn, etc.) beforehand.

    Args:
        query: Gmail search query to find social media notification emails
        max_results: max number of notifications to fetch

    Returns:
        JSON string with the list of detected social events
    """
    events = fetch_social_events(query=query, max_results=max_results)
    return json.dumps({
        "count": len(events),
        "events": [
            {
                "email_id": e.email_id,
                "platform": e.platform,
                "event_type": e.event_type,
                "author": e.author,
                "text": e.text,
                "post_url": e.post_url,
                "date": e.date,
            }
            for e in events
        ],
    }, ensure_ascii=False)



    try:
        issues = json.loads(issues_found_json) if issues_found_json else []
    except json.JSONDecodeError:
        issues = []

    try:
        result = send_approval_request(
            original_subject=original_subject,
            original_sender=original_sender,
            original_body=original_body,
            reply_subject=reply_subject,
            reply_body=reply_body,
            verdict=verdict,
            issues_found=issues,
            explanation=explanation,
            sentiment_label=sentiment_label or None,
            sentiment_score=sentiment_score or None,
        )
        return json.dumps({
            "status": "sent",
            "message_id": result.get("id", "unknown"),
        }, ensure_ascii=False)
    except Exception as e:
        return json.dumps({"status": "error", "error": str(e)}, ensure_ascii=False)


# OUTIL 5 : Debug — voir le contenu brut d'un e-mail de notification
@tool
def debug_raw_email(email_id: str) -> str:
    """
    Shows the raw subject and body of a specific email, by its Gmail message ID.
    Useful for debugging why a social media notification wasn't parsed correctly
    (wrong platform detected, event type "unknown", missing author/text, etc.).
    Get the email_id from a previous read_social_notifications call.

    Args:
        email_id: the exact Gmail message ID (from read_social_notifications output)

    Returns:
        The raw subject and body text of that email
    """
    return debug_dump_raw_body(email_id)


# OUTIL 6 : Analyser le sentiment d'UN commentaire directement par son email_id
# (évite que le LLM doive recopier lui-même le texte, ce qui est peu fiable
#  avec des emojis ou caractères spéciaux)
@tool
def analyze_notification_sentiment(email_id: str) -> str:
    """
    Fetches a specific social media notification by its email_id, and analyzes
    the sentiment of its comment text directly (the exact text is read from
    Gmail by the code, not retyped by you). Use this INSTEAD OF analyze_sentiment
    whenever you already have an email_id from read_social_notifications — it is
    more reliable, especially for comments containing emojis or special characters.

    Args:
        email_id: the exact Gmail message ID (from read_social_notifications output)

    Returns:
        JSON string with the event details and its sentiment analysis
    """
    event = get_social_event_by_id(email_id)
    if event is None:
        return json.dumps({"error": f"Email {email_id} not found", "email_id": email_id}, ensure_ascii=False)

    if not event.text:
        return json.dumps({
            "email_id": email_id,
            "error": "No comment text could be extracted for this event; nothing to analyze.",
        }, ensure_ascii=False)

    result = _analyze_sentiment(event.text)
    return json.dumps({
        "email_id": email_id,
        "platform": event.platform,
        "author": event.author,
        "text": result.text,
        "sentiment_label": result.label,
        "sentiment_score": result.score,
    }, ensure_ascii=False)


ALL_TOOLS_AGENT2 = [
    analyze_sentiment,
    analyze_notification_sentiment,
    read_social_notifications,
    debug_raw_email,
]
