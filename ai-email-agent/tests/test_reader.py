import json
import pytest
from unittest.mock import patch, MagicMock
from gmail.reader import Email


# Fixtures - donnees de test
def make_fake_email(
    email_id="abc123",
    subject="Test Email",
    sender="test@example.com",
    body="This is a test email body.",
    is_read=False,
):
    return Email(
        id=email_id,
        subject=subject,
        sender=sender,
        body=body,
        date="Thu, 03 Jul 2026 10:00:00 +0000",
        is_read=is_read,
    )

# Tests des outils
def test_read_emails_tool_returns_json():
    """read_emails doit retourner un JSON valide."""
    fake_emails = [
        make_fake_email("id1", "Email 1", "db08023@gmail.com"),
        make_fake_email("id2", "Email 2", "b@test.com"),
    ]

    with patch("agent.tools.fetch_emails", return_value=fake_emails):
        from agent.tools import read_emails
        result_str = read_emails.invoke({"query": "is:unread", "max_results": 5})
        result = json.loads(result_str)

        assert result["status"] == "ok"
        assert result["count"] == 2
        assert result["emails"][0]["id"] == "id1"
        assert result["emails"][1]["subject"] == "Email 2"


def test_read_emails_tool_empty():
    """read_emails avec aucun email doit retourner status empty."""
    with patch("agent.tools.fetch_emails", return_value=[]):
        from agent.tools import read_emails
        result_str = read_emails.invoke({"query": "is:unread"})
        result = json.loads(result_str)

        assert result["status"] == "empty"
        assert result["count"] == 0


def test_classify_email_tool_returns_json():
    """classify_email doit retourner categorie et confiance."""
    fake_email = make_fake_email("id1", "Urgent problem", "angry@client.com",
                                  "I have a serious complaint about your service.")

    mock_result = MagicMock()
    mock_result.category   = "RECLAMATION"
    mock_result.confidence = 0.92
    mock_result.reason     = "Customer expressing dissatisfaction"

    with patch("agent.tools.fetch_single_email", return_value=fake_email):
        with patch("agent.tools._chains.classify", return_value=mock_result):
            from agent.tools import classify_email
            result_str = classify_email.invoke({"email_id": "id1"})
            result = json.loads(result_str)

            assert result["category"] == "RECLAMATION"
            assert result["confidence"] == 0.92
            assert result["email_id"] == "id1"


def test_classify_email_rejects_tool_name_as_email_id():
    """classify_email ne doit pas accepter read_emails comme ID Gmail."""
    from agent.tools import classify_email

    result_str = classify_email.invoke({"email_id": "read_emails"})
    result = json.loads(result_str)

    assert "Invalid placeholder email ID" in result["error"]
    assert result["email_id"] == "read_emails"


def test_analyze_latest_emails_returns_full_analysis():
    """analyze_latest_emails doit lire puis analyser sans ID manuel."""
    fake_email = make_fake_email("id1", "Urgent problem", "angry@client.com",
                                  "I have a serious complaint about your service.")

    classification = MagicMock()
    classification.category = "RECLAMATION"
    classification.confidence = 0.92
    classification.reason = "Customer complaint"

    priority = MagicMock()
    priority.priority = "URGENT"
    priority.urgency_score = 9
    priority.reason = "Urgent complaint"

    summary = MagicMock()
    summary.summary = "Customer reports a service problem."
    summary.action_required = "Reply quickly"
    summary.language = "en"

    reply = MagicMock()
    reply.reply_subject = "Re: Urgent problem"
    reply.reply = "We are checking this now."
    reply.tone = "professional"

    with patch("agent.tools.fetch_emails", return_value=[fake_email]):
        with patch("agent.tools._chains.classify", return_value=classification):
            with patch("agent.tools._chains.prioritize", return_value=priority):
                with patch("agent.tools._chains.summarize", return_value=summary):
                    with patch("agent.tools._chains.suggest_reply", return_value=reply):
                        from agent.tools import analyze_latest_emails
                        result_str = analyze_latest_emails.invoke({"query": "", "max_results": 1})
                        result = json.loads(result_str)

    assert result["status"] == "ok"
    assert result["count"] == 1
    assert result["emails"][0]["id"] == "id1"
    assert result["emails"][0]["category"] == "RECLAMATION"
    assert result["emails"][0]["priority"] == "URGENT"
    assert result["emails"][0]["is_urgent"] is True


def test_send_single_email_tool_success():
    """send_single_email doit retourner status sent."""
    mock_send_result = {"id": "msg_abc123"}

    with patch("agent.tools.gmail_send", return_value=mock_send_result):
        from agent.tools import send_single_email
        result_str = send_single_email.invoke({
            "to":      "recipient@test.com",
            "subject": "Test Subject",
            "body":    "Test Body",
            "confirm_send": True,
        })
        result = json.loads(result_str)

        assert result["status"] == "sent"
        assert result["to"] == "recipient@test.com"
        assert result["message_id"] == "msg_abc123"


def test_send_single_email_requires_confirmation():
    """send_single_email ne doit pas envoyer sans confirmation explicite."""
    with patch("agent.tools.gmail_send") as mock_send:
        from agent.tools import send_single_email
        result_str = send_single_email.invoke({
            "to":      "recipient@test.com",
            "subject": "Test Subject",
            "body":    "Test Body",
        })
        result = json.loads(result_str)

        assert result["status"] == "confirmation_required"
        assert result["preview"]["to"] == "recipient@test.com"
        mock_send.assert_not_called()


def test_send_single_email_tool_error():
    """send_single_email doit retourner status error si Gmail echoue."""
    with patch("agent.tools.gmail_send", side_effect=Exception("Gmail API error")):
        from agent.tools import send_single_email
        result_str = send_single_email.invoke({
            "to":      "bad@test.com",
            "subject": "Test",
            "body":    "Body",
            "confirm_send": True,
        })
        result = json.loads(result_str)

        assert result["status"] == "error"
        assert "Gmail API error" in result["error"]


def test_send_bulk_email_tool():
    """send_bulk_email doit envoyer a chaque destinataire."""
    mock_results = [
        {"to": "alice@test.com", "status": "sent",  "id": "id1"},
        {"to": "bob@test.com",   "status": "sent",  "id": "id2"},
        {"to": "bad@test.com",   "status": "error", "error": "failed"},
    ]

    with patch("agent.tools.send_bulk_emails", return_value=mock_results):
        from agent.tools import send_bulk_email
        recipients = json.dumps([
            {"to": "alice@test.com", "subject": "A", "body": "Hello Alice"},
            {"to": "bob@test.com",   "subject": "B", "body": "Hello Bob"},
            {"to": "bad@test.com",   "subject": "C", "body": "Hello Bad"},
        ])
        result_str = send_bulk_email.invoke({
            "recipients_json": recipients,
            "confirm_send": True,
        })
        result = json.loads(result_str)

        assert result["total"]  == 3
        assert result["sent"]   == 2
        assert result["errors"] == 1


def test_send_bulk_email_requires_confirmation():
    """send_bulk_email ne doit pas envoyer sans confirmation explicite."""
    with patch("agent.tools.send_bulk_emails") as mock_send:
        from agent.tools import send_bulk_email
        recipients = json.dumps([
            {"to": "alice@test.com", "subject": "A", "body": "Hello Alice"},
        ])
        result_str = send_bulk_email.invoke({"recipients_json": recipients})
        result = json.loads(result_str)

        assert result["status"] == "confirmation_required"
        assert result["preview"]["total"] == 1
        mock_send.assert_not_called()


def test_all_tools_are_registered():
    """Verifier que tous les outils sont bien dans ALL_TOOLS."""
    from agent.tools import ALL_TOOLS

    tool_names = [t.name for t in ALL_TOOLS]
    expected = [
        "read_emails",
        "analyze_latest_emails",
        "classify_email",
        "prioritize_email",
        "summarize_email",
        "suggest_reply",
        "send_single_email",
        "send_bulk_email",
        "get_urgent_emails",
    ]
    for name in expected:
        assert name in tool_names, f"Tool '{name}' missing from ALL_TOOLS"
