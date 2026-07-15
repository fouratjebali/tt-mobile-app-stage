import json
import os
import pytest
import tempfile
from agent.logger import AgentLogger, AnalysisLog


def test_logger_creates_log():
    """Logger doit créer un AnalysisLog correctement."""
    logger = AgentLogger()
    log = logger.log_analysis(
        email_subject="Test subject",
        email_sender="test@example.com",
        email_body="This is a test email body content.",
        predicted_category="SUPPORT",
        predicted_priority="NORMAL",
        confidence=0.88,
        urgency_score=5,
        summary="Test email requiring support.",
        suggested_reply="Thank you for contacting us.",
    )

    assert log.email_subject      == "Test subject"
    assert log.predicted_category == "SUPPORT"
    assert log.predicted_priority == "NORMAL"
    assert log.confidence         == 0.88
    assert log.true_category      is None
    assert log.correct_category   is None


def test_logger_session_stats():
    """get_session_stats doit retourner les bonnes stats."""
    logger = AgentLogger()

    for cat, pri, conf in [
        ("SUPPORT",     "NORMAL", 0.9),
        ("RECLAMATION", "URGENT", 0.85),
        ("INFORMATION", "LOW",    0.95),
        ("SUPPORT",     "NORMAL", 0.75),
    ]:
        logger.log_analysis(
            email_subject="Test", email_sender="a@b.com",
            email_body="body", predicted_category=cat,
            predicted_priority=pri, confidence=conf,
            urgency_score=5, summary="s", suggested_reply="r"
        )

    stats = logger.get_session_stats()
    assert stats["total"]                    == 4
    assert stats["categories"]["SUPPORT"]    == 2
    assert stats["priorities"]["NORMAL"]     == 2
    assert 0.87 < stats["avg_confidence"] < 0.88


def test_logger_export_creates_file():
    """export_for_evaluation doit créer un fichier JSON valide."""
    logger = AgentLogger()
    logger.log_analysis(
        email_subject="Export test", email_sender="x@y.com",
        email_body="body content", predicted_category="COMMERCIAL",
        predicted_priority="LOW", confidence=0.92,
        urgency_score=2, summary="Commercial email.", suggested_reply="reply"
    )

    with tempfile.NamedTemporaryFile(
        suffix=".json", delete=False, mode="w"
    ) as f:
        tmp_path = f.name

    try:
        logger.export_for_evaluation(tmp_path)
        assert os.path.exists(tmp_path)
        with open(tmp_path, "r") as f:
            data = json.load(f)
        assert len(data)                    == 1
        assert data[0]["email_subject"]     == "Export test"
        assert data[0]["predicted_category"]== "COMMERCIAL"
        assert data[0]["true_category"]     is None
    finally:
        os.remove(tmp_path)


def test_metrics_calculation():
    """Test du calcul des métriques avec données connues."""
    annotated = [
        {"predicted_category": "SUPPORT",     "true_category": "SUPPORT",
         "predicted_priority": "NORMAL",      "true_priority": "NORMAL"},
        {"predicted_category": "RECLAMATION", "true_category": "RECLAMATION",
         "predicted_priority": "URGENT",      "true_priority": "URGENT"},
        {"predicted_category": "INFORMATION", "true_category": "INFORMATION",
         "predicted_priority": "LOW",         "true_priority": "LOW"},
        {"predicted_category": "COMMERCIAL",  "true_category": "SUPPORT",
         "predicted_priority": "NORMAL",      "true_priority": "NORMAL"},
        {"predicted_category": "SUPPORT",     "true_category": "SUPPORT",
         "predicted_priority": "URGENT",      "true_priority": "NORMAL"},
    ]

    cat_correct = sum(
        1 for d in annotated
        if d["predicted_category"] == d["true_category"]
    )
    pri_correct = sum(
        1 for d in annotated
        if d["predicted_priority"] == d["true_priority"]
    )

    cat_accuracy = cat_correct / len(annotated)
    pri_accuracy = pri_correct / len(annotated)

    assert cat_accuracy == 0.8   # 4/5 correct
    assert pri_accuracy == 0.8   # 4/5 correct