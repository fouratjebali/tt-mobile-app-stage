import os
from datetime import UTC, datetime, timedelta

os.environ.setdefault("DATABASE_URL", "sqlite+pysqlite:///:memory:")

import app.models  # noqa: E402,F401
from app.api.v1.routes.admin import admin_overview  # noqa: E402
from app.db.base import Base  # noqa: E402
from app.models.auth import AuthSession, User, UserRole  # noqa: E402
from app.repositories.auth_repository import AuthRepository  # noqa: E402
from sqlalchemy import create_engine, text  # noqa: E402
from sqlalchemy.orm import sessionmaker  # noqa: E402


def _session():
    engine = create_engine("sqlite+pysqlite:///:memory:")
    Base.metadata.create_all(bind=engine, tables=[User.__table__, AuthSession.__table__])
    with engine.begin() as connection:
        _create_email_workflow_tables(connection)
    session_factory = sessionmaker(bind=engine)
    return session_factory()


def test_admin_overview_counts_backend_workflow_data():
    db = _session()
    try:
        repository = AuthRepository(db)
        admin = repository.upsert_user(
            google_sub="microsoft:admin",
            email="admin@tunisietelecom.tn",
            display_name="Admin",
            photo_url=None,
        )
        reviewer = repository.upsert_user(
            google_sub="microsoft:reviewer",
            email="reviewer@tunisietelecom.tn",
            display_name="Reviewer",
            photo_url=None,
        )
        inactive = repository.upsert_user(
            google_sub="microsoft:inactive",
            email="inactive@tunisietelecom.tn",
            display_name="Inactive",
            photo_url=None,
        )
        repository.update_user_role(user_id=admin.id, role=UserRole.ADMIN)
        repository.update_user_role(user_id=reviewer.id, role=UserRole.REVIEWER)
        repository.update_user_active_state(user_id=inactive.id, is_active=False)

        now = datetime.now(tz=UTC)
        db.execute(
            text(
                """
                INSERT INTO emails (
                    id, user_id, gmail_message_id, subject, sender, received_at,
                    is_read, status, created_at, updated_at
                ) VALUES
                    ('email-review', :admin_id, 'msg-review', 'Urgent mail',
                     'sender@tt.tn', :now, 0, 'REVIEW_REQUIRED', :now, :now),
                    ('email-sent', :admin_id, 'msg-sent', 'Handled mail',
                     'sender@tt.tn', :old, 1, 'DONE', :old, :old),
                    ('email-pending', :admin_id, 'msg-pending', 'Pending mail',
                     'sender@tt.tn', :now, 0, 'PENDING_ANALYSIS', :now, :now)
                """
            ),
            {
                "admin_id": admin.id,
                "now": now,
                "old": now - timedelta(days=9),
            },
        )
        db.execute(
            text(
                """
                INSERT INTO analyses (
                    id, email_id, priority, urgency_score, created_at
                ) VALUES
                    ('analysis-review', 'email-review', 'URGENT', 9, :now),
                    ('analysis-sent', 'email-sent', 'NORMAL', 2, :old)
                """
            ),
            {"now": now, "old": now - timedelta(days=9)},
        )
        db.execute(
            text(
                """
                INSERT INTO responses (
                    id, email_id, subject, body, status, sent_at, created_at, updated_at
                ) VALUES (
                    'response-sent', 'email-sent', 'Re: Handled mail', 'Done',
                    'sent', :now, :now, :now
                )
                """
            ),
            {"now": now},
        )
        db.execute(
            text(
                """
                INSERT INTO notifications (
                    id, user_id, email_id, kind, title, body, read_at, created_at
                ) VALUES
                    ('notification-unread', :admin_id, 'email-review',
                     'email_treated', 'Ready', 'Ready for review', NULL, :now),
                    ('notification-read', :admin_id, 'email-sent',
                     'email_sent', 'Sent', 'Reply sent', :now, :now)
                """
            ),
            {"admin_id": admin.id, "now": now},
        )
        db.commit()

        overview = admin_overview(admin, db)

        assert overview.users.total == 3
        assert overview.users.active == 2
        assert overview.users.inactive == 1
        assert overview.users.admins == 1
        assert overview.users.reviewers == 1
        assert overview.email.total == 3
        assert overview.email.unread == 2
        assert overview.email.awaiting_review == 1
        assert overview.email.urgent == 1
        assert overview.email.analysed == 2
        assert overview.email.pending == 1
        assert overview.email.sent_replies == 1
        assert overview.email.received_today == 2
        assert overview.notifications.total == 2
        assert overview.notifications.unread == 1
        assert overview.training.available is False
        assert overview.system.admin_base_path == "/api/v1/admin"
    finally:
        db.close()


def _create_email_workflow_tables(connection) -> None:
    connection.execute(
        text(
            """
            CREATE TABLE emails (
                id VARCHAR(36) PRIMARY KEY,
                user_id VARCHAR(36),
                gmail_message_id VARCHAR(255),
                thread_id VARCHAR(255),
                subject TEXT,
                sender VARCHAR(320),
                recipients TEXT,
                body_preview TEXT,
                body TEXT,
                received_at DATETIME,
                is_read BOOLEAN DEFAULT 0,
                status VARCHAR(50),
                created_at DATETIME,
                updated_at DATETIME
            )
            """
        )
    )
    connection.execute(
        text(
            """
            CREATE TABLE analyses (
                id VARCHAR(36) PRIMARY KEY,
                email_id VARCHAR(36),
                category VARCHAR(80),
                classification_confidence FLOAT,
                priority VARCHAR(50),
                urgency_score INTEGER,
                summary TEXT,
                action_required TEXT,
                sentiment_label VARCHAR(80),
                sentiment_score FLOAT,
                raw_payload TEXT,
                created_at DATETIME
            )
            """
        )
    )
    connection.execute(
        text(
            """
            CREATE TABLE responses (
                id VARCHAR(36) PRIMARY KEY,
                email_id VARCHAR(36),
                subject TEXT,
                body TEXT,
                tone VARCHAR(80),
                status VARCHAR(50),
                sent_at DATETIME,
                gmail_message_id VARCHAR(255),
                raw_payload TEXT,
                created_at DATETIME,
                updated_at DATETIME
            )
            """
        )
    )
    connection.execute(
        text(
            """
            CREATE TABLE notifications (
                id VARCHAR(36) PRIMARY KEY,
                user_id VARCHAR(36),
                email_id VARCHAR(36),
                kind VARCHAR(80),
                title VARCHAR(255),
                body TEXT,
                data TEXT,
                read_at DATETIME,
                created_at DATETIME
            )
            """
        )
    )
