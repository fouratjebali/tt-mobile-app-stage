import json
import pytest
from unittest.mock import patch, MagicMock
from gmail.reader import Email
from agent.chains import (
    ClassificationResult,
    PriorityResult,
    SummaryResult,
    ReplyResult,
)
from agent.pipeline import EmailPipeline, EmailAnalysisResult


def make_email(subject="Test", sender="test@example.com",
               body="Test body content."):
    return Email(
        id="test_id_123",
        subject=subject,
        sender=sender,
        body=body,
        date="2026-07-06T10:00:00",
        is_read=False,
    )


def make_mock_chains():
    """Crée des chains mockées avec des résultats réalistes."""
    mock = MagicMock()
    mock.classify.return_value = ClassificationResult(
        category="SUPPORT", confidence=0.91, reason="Asks for help"
    )
    mock.prioritize.return_value = PriorityResult(
        priority="NORMAL", urgency_score=5, reason="Standard request"
    )
    mock.summarize.return_value = SummaryResult(
        summary="User needs technical help.",
        action_required="Respond with solution",
        language="en",
    )
    mock.suggest_reply.return_value = ReplyResult(
        reply="Thank you for contacting us. We will help you shortly.",
        reply_subject="Re: Test",
        tone="professional",
    )
    return mock


# ----------------------------------------------------------
# Tests pipeline
# ----------------------------------------------------------

def test_pipeline_analyze_returns_complete_result():
    """Le pipeline doit retourner un EmailAnalysisResult complet."""
    email = make_email("Help needed", "user@test.com", "I need assistance.")

    with patch.object(
        EmailPipeline, '__init__',
        lambda self: setattr(self, 'chains', make_mock_chains())
    ):
        pipeline = EmailPipeline.__new__(EmailPipeline)
        pipeline.chains = make_mock_chains()
        result = pipeline.analyze(email)

    assert isinstance(result, EmailAnalysisResult)
    assert result.classification.category    == "SUPPORT"
    assert result.priority.priority          == "NORMAL"
    assert result.summary.action_required    == "Respond with solution"
    assert "Thank you" in result.reply.reply


def test_pipeline_is_urgent_false():
    """Email NORMAL ne doit pas être urgent."""
    email = make_email()

    with patch.object(
        EmailPipeline, '__init__',
        lambda self: None
    ):
        pipeline = EmailPipeline.__new__(EmailPipeline)
        pipeline.chains = make_mock_chains()
        result = pipeline.analyze(email)

    assert result.is_urgent()    is False
    assert result.needs_reply()  is True


def test_pipeline_is_urgent_true():
    """Email URGENT doit être détecté comme urgent."""
    email = make_email(
        "URGENT: Server down",
        "cto@company.com",
        "Production server is down immediately fix it."
    )

    mock_chains = make_mock_chains()
    mock_chains.prioritize.return_value = PriorityResult(
        priority="URGENT", urgency_score=10, reason="Server down"
    )

    with patch.object(EmailPipeline, '__init__', lambda self: None):
        pipeline = EmailPipeline.__new__(EmailPipeline)
        pipeline.chains = mock_chains
        result = pipeline.analyze(email)

    assert result.is_urgent() is True


def test_pipeline_information_needs_no_reply():
    """Email INFORMATION ne nécessite pas de réponse."""
    email = make_email("Newsletter", "news@co.com", "Monthly news.")

    mock_chains = make_mock_chains()
    mock_chains.classify.return_value = ClassificationResult(
        category="INFORMATION", confidence=0.95, reason="Newsletter"
    )
    mock_chains.prioritize.return_value = PriorityResult(
        priority="LOW", urgency_score=1, reason="Newsletter"
    )

    with patch.object(EmailPipeline, '__init__', lambda self: None):
        pipeline = EmailPipeline.__new__(EmailPipeline)
        pipeline.chains = mock_chains
        result = pipeline.analyze(email)

    assert result.needs_reply()  is False
    assert result.is_urgent()    is False


def test_pipeline_analyze_batch():
    """analyze_batch doit traiter tous les emails."""
    emails = [
        make_email(f"Email {i}", f"user{i}@test.com", f"Body {i}")
        for i in range(3)
    ]

    with patch.object(EmailPipeline, '__init__', lambda self: None):
        pipeline = EmailPipeline.__new__(EmailPipeline)
        pipeline.chains = make_mock_chains()
        results = pipeline.analyze_batch(emails)

    assert len(results) == 3
    assert all(isinstance(r, EmailAnalysisResult) for r in results)


def test_display_dict_has_all_keys():
    """display_dict doit contenir toutes les clés attendues."""
    email = make_email()

    with patch.object(EmailPipeline, '__init__', lambda self: None):
        pipeline = EmailPipeline.__new__(EmailPipeline)
        pipeline.chains = make_mock_chains()
        result = pipeline.analyze(email)

    d = result.display_dict()
    expected_keys = [
        "subject", "sender", "category", "confidence",
        "priority", "urgency_score", "summary",
        "action", "language", "suggested_reply", "reply_subject",
    ]
    for key in expected_keys:
        assert key in d, f"Key '{key}' missing from display_dict"


# ----------------------------------------------------------
# Tests parser (robustesse)
# ----------------------------------------------------------

def test_parser_handles_nested_json():
    """Le parser doit gérer du JSON imbriqué."""
    from agent.parser import LLMOutputParser
    raw = '{"category": "SUPPORT", "data": {"key": "value"}}'
    result = LLMOutputParser.parse(raw)
    assert result["category"] == "SUPPORT"


def test_parser_handles_unicode():
    """Le parser doit gérer les caractères Unicode."""
    from agent.parser import LLMOutputParser
    raw = '{"summary": "Email en français avec accents éàü"}'
    result = LLMOutputParser.parse(raw)
    assert "français" in result["summary"]


def test_parser_extracts_from_long_text():
    """Le parser doit extraire le JSON d'un texte long."""
    from agent.parser import LLMOutputParser
    raw = (
        "Here is my detailed analysis of the email:\n\n"
        "The email seems to be a support request.\n\n"
        '{"category": "SUPPORT", "confidence": 0.88}\n\n'
        "I hope this helps with the classification."
    )
    result = LLMOutputParser.parse(raw)
    assert result["category"]   == "SUPPORT"
    assert result["confidence"] == 0.88