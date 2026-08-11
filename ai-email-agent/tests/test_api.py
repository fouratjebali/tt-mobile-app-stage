from fastapi.testclient import TestClient

from gmail.reader import Email


def make_email(email_id: str = "id1") -> Email:
    return Email(
        id=email_id,
        subject="Urgent support needed",
        sender="client@example.com",
        body="Our service is down and we need help immediately.",
        date="Thu, 03 Jul 2026 10:00:00 +0000",
        is_read=False,
    )


def make_analysis_result(email: Email):
    from agent.chains import ClassificationResult, PriorityResult, ReplyResult, SummaryResult
    from agent.pipeline import EmailAnalysisResult

    return EmailAnalysisResult(
        email=email,
        classification=ClassificationResult(
            category="SUPPORT",
            confidence=0.91,
            reason="The sender asks for technical help.",
        ),
        priority=PriorityResult(
            priority="URGENT",
            urgency_score=9,
            reason="Service is down.",
        ),
        summary=SummaryResult(
            summary="The client reports a service outage.",
            action_required="Investigate and reply quickly.",
            language="en",
        ),
        reply=ReplyResult(
            reply_subject="Re: Urgent support needed",
            reply="We are checking this now and will update you shortly.",
            tone="professional",
        ),
    )


def test_health_includes_api_version():
    from api import app

    client = TestClient(app)
    response = client.get("/health")

    assert response.status_code == 200
    assert response.json()["api_version"]


def test_list_emails_returns_preview(monkeypatch):
    import api

    monkeypatch.setattr(api, "fetch_emails", lambda max_results, query: [make_email()])

    client = TestClient(api.app)
    response = client.get("/emails?query=is:unread&max_results=5")

    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"
    assert data["count"] == 1
    assert data["emails"][0]["id"] == "id1"
    assert "body_preview" in data["emails"][0]


def test_analyze_payload_returns_structured_result(monkeypatch):
    import api

    class FakePipeline:
        def analyze(self, email: Email):
            return make_analysis_result(email)

    api.get_pipeline.cache_clear()
    monkeypatch.setattr(api, "get_pipeline", lambda: FakePipeline())

    client = TestClient(api.app)
    response = client.post(
        "/emails/analyze",
        json={
            "email": {
                "id": "manual-1",
                "subject": "Urgent support needed",
                "sender": "client@example.com",
                "body": "Our service is down and we need help immediately.",
            }
        },
    )

    assert response.status_code == 200
    data = response.json()
    assert data["email_id"] == "manual-1"
    assert data["classification"]["category"] == "SUPPORT"
    assert data["priority"]["priority"] == "URGENT"
    assert data["reply_suggestion"]["subject"] == "Re: Urgent support needed"
    assert data["is_urgent"] is True
    assert data["needs_reply"] is True


def test_analyze_missing_gmail_email_returns_404(monkeypatch):
    import api

    monkeypatch.setattr(api, "fetch_single_email", lambda email_id: None)

    client = TestClient(api.app)
    response = client.post("/emails/missing-id/analyze")

    assert response.status_code == 404
