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
    response = client.get("/health", headers={"X-Request-ID": "test-request-1"})

    assert response.status_code == 200
    assert response.json()["api_version"]
    assert response.headers["X-Request-ID"] == "test-request-1"
    assert response.headers["X-Process-Time-Ms"]


def test_root_lists_available_routes():
    from api import app

    client = TestClient(app)
    response = client.get("/")

    assert response.status_code == 200
    data = response.json()
    assert data["service"] == "agent1"
    assert data["docs_url"] == "/docs"
    assert "POST /chat" in data["endpoints"]


def test_ready_returns_dependency_config():
    from api import app

    client = TestClient(app)
    response = client.get("/ready")

    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ready"
    assert data["ollama_model"]
    assert data["gmail_mode"] == "oauth_or_offline_fallback"


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
    response = client.post(
        "/emails/missing-id/analyze",
        headers={"X-Request-ID": "missing-email-test"},
    )

    assert response.status_code == 404
    data = response.json()
    assert data["status"] == "error"
    assert data["error"] == "http_error"
    assert data["request_id"] == "missing-email-test"


def test_unhandled_errors_return_traceable_json(monkeypatch):
    import api

    class BrokenPipeline:
        def analyze(self, email: Email):
            raise RuntimeError("LLM unavailable")

    monkeypatch.setattr(api, "get_pipeline", lambda: BrokenPipeline())

    client = TestClient(api.app, raise_server_exceptions=False)
    response = client.post(
        "/emails/analyze",
        headers={"X-Request-ID": "broken-pipeline-test"},
        json={
            "email": {
                "subject": "Need help",
                "sender": "client@example.com",
                "body": "Please help me.",
            }
        },
    )

    assert response.status_code == 500
    data = response.json()
    assert data["status"] == "error"
    assert data["error"] == "internal_server_error"
    assert data["detail"] == "LLM unavailable"
    assert data["request_id"] == "broken-pipeline-test"
