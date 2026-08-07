"""create sprint 4 schema

Revision ID: 20260801_0001
Revises:
Create Date: 2026-08-01
"""
from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision: str = "20260801_0001"
down_revision: str | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("google_sub", sa.String(length=255), nullable=False),
        sa.Column("email", sa.String(length=320), nullable=False),
        sa.Column("display_name", sa.String(length=255), nullable=True),
        sa.Column("photo_url", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_users_email"), "users", ["email"], unique=True)
    op.create_index(op.f("ix_users_google_sub"), "users", ["google_sub"], unique=True)

    op.create_table(
        "auth_sessions",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("user_id", sa.String(length=36), nullable=False),
        sa.Column("session_token_hash", sa.String(length=64), nullable=False),
        sa.Column("google_access_token", sa.Text(), nullable=False),
        sa.Column("google_id_token", sa.Text(), nullable=True),
        sa.Column("google_refresh_token", sa.Text(), nullable=True),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_auth_sessions_session_token_hash"), "auth_sessions", ["session_token_hash"], unique=True)
    op.create_index(op.f("ix_auth_sessions_user_id"), "auth_sessions", ["user_id"], unique=False)

    op.create_table(
        "emails",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("user_id", sa.String(length=36), nullable=False),
        sa.Column("gmail_message_id", sa.String(length=255), nullable=False),
        sa.Column("thread_id", sa.String(length=255), nullable=True),
        sa.Column("subject", sa.Text(), nullable=False),
        sa.Column("sender", sa.String(length=320), nullable=False),
        sa.Column("recipients", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column("body_preview", sa.Text(), nullable=True),
        sa.Column("body", sa.Text(), nullable=True),
        sa.Column("received_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("is_read", sa.Boolean(), nullable=False),
        sa.Column("status", sa.String(length=50), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_emails_gmail_message_id"), "emails", ["gmail_message_id"], unique=False)
    op.create_index(op.f("ix_emails_received_at"), "emails", ["received_at"], unique=False)
    op.create_index(op.f("ix_emails_sender"), "emails", ["sender"], unique=False)
    op.create_index(op.f("ix_emails_status"), "emails", ["status"], unique=False)
    op.create_index(op.f("ix_emails_user_id"), "emails", ["user_id"], unique=False)

    op.create_table(
        "settings",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("user_id", sa.String(length=36), nullable=False),
        sa.Column("auto_reply_enabled", sa.Boolean(), nullable=False),
        sa.Column("require_review_for_urgent", sa.Boolean(), nullable=False),
        sa.Column("urgency_threshold", sa.Integer(), nullable=False),
        sa.Column("preferred_tone", sa.String(length=80), nullable=False),
        sa.Column("language", sa.String(length=20), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_settings_user_id"), "settings", ["user_id"], unique=True)

    op.create_table(
        "stats",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("user_id", sa.String(length=36), nullable=False),
        sa.Column("period", sa.String(length=50), nullable=False),
        sa.Column("processed_count", sa.Integer(), nullable=False),
        sa.Column("urgent_count", sa.Integer(), nullable=False),
        sa.Column("review_count", sa.Integer(), nullable=False),
        sa.Column("sent_count", sa.Integer(), nullable=False),
        sa.Column("categories", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column("generated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_stats_generated_at"), "stats", ["generated_at"], unique=False)
    op.create_index(op.f("ix_stats_period"), "stats", ["period"], unique=False)
    op.create_index(op.f("ix_stats_user_id"), "stats", ["user_id"], unique=False)

    op.create_table(
        "analyses",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("email_id", sa.String(length=36), nullable=False),
        sa.Column("category", sa.String(length=80), nullable=True),
        sa.Column("classification_confidence", sa.Float(), nullable=True),
        sa.Column("priority", sa.String(length=50), nullable=True),
        sa.Column("urgency_score", sa.Integer(), nullable=True),
        sa.Column("summary", sa.Text(), nullable=True),
        sa.Column("action_required", sa.Text(), nullable=True),
        sa.Column("sentiment_label", sa.String(length=80), nullable=True),
        sa.Column("sentiment_score", sa.Float(), nullable=True),
        sa.Column("raw_payload", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["email_id"], ["emails.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_analyses_email_id"), "analyses", ["email_id"], unique=False)

    op.create_table(
        "responses",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("email_id", sa.String(length=36), nullable=False),
        sa.Column("subject", sa.Text(), nullable=False),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column("tone", sa.String(length=80), nullable=True),
        sa.Column("status", sa.String(length=50), nullable=False),
        sa.Column("sent_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("gmail_message_id", sa.String(length=255), nullable=True),
        sa.Column("raw_payload", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["email_id"], ["emails.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_responses_email_id"), "responses", ["email_id"], unique=False)
    op.create_index(op.f("ix_responses_status"), "responses", ["status"], unique=False)

    op.create_table(
        "jury_verdicts",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("email_id", sa.String(length=36), nullable=False),
        sa.Column("analysis_id", sa.String(length=36), nullable=True),
        sa.Column("response_id", sa.String(length=36), nullable=True),
        sa.Column("verdict", sa.String(length=50), nullable=False),
        sa.Column("confidence_score", sa.Float(), nullable=True),
        sa.Column("comment", sa.Text(), nullable=True),
        sa.Column("raw_payload", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["analysis_id"], ["analyses.id"]),
        sa.ForeignKeyConstraint(["email_id"], ["emails.id"]),
        sa.ForeignKeyConstraint(["response_id"], ["responses.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_jury_verdicts_analysis_id"), "jury_verdicts", ["analysis_id"], unique=False)
    op.create_index(op.f("ix_jury_verdicts_email_id"), "jury_verdicts", ["email_id"], unique=False)
    op.create_index(op.f("ix_jury_verdicts_response_id"), "jury_verdicts", ["response_id"], unique=False)
    op.create_index(op.f("ix_jury_verdicts_verdict"), "jury_verdicts", ["verdict"], unique=False)


def downgrade() -> None:
    op.drop_index(op.f("ix_jury_verdicts_verdict"), table_name="jury_verdicts")
    op.drop_index(op.f("ix_jury_verdicts_response_id"), table_name="jury_verdicts")
    op.drop_index(op.f("ix_jury_verdicts_email_id"), table_name="jury_verdicts")
    op.drop_index(op.f("ix_jury_verdicts_analysis_id"), table_name="jury_verdicts")
    op.drop_table("jury_verdicts")

    op.drop_index(op.f("ix_responses_status"), table_name="responses")
    op.drop_index(op.f("ix_responses_email_id"), table_name="responses")
    op.drop_table("responses")

    op.drop_index(op.f("ix_analyses_email_id"), table_name="analyses")
    op.drop_table("analyses")

    op.drop_index(op.f("ix_stats_user_id"), table_name="stats")
    op.drop_index(op.f("ix_stats_period"), table_name="stats")
    op.drop_index(op.f("ix_stats_generated_at"), table_name="stats")
    op.drop_table("stats")

    op.drop_index(op.f("ix_settings_user_id"), table_name="settings")
    op.drop_table("settings")

    op.drop_index(op.f("ix_emails_user_id"), table_name="emails")
    op.drop_index(op.f("ix_emails_status"), table_name="emails")
    op.drop_index(op.f("ix_emails_sender"), table_name="emails")
    op.drop_index(op.f("ix_emails_received_at"), table_name="emails")
    op.drop_index(op.f("ix_emails_gmail_message_id"), table_name="emails")
    op.drop_table("emails")

    op.drop_index(op.f("ix_auth_sessions_user_id"), table_name="auth_sessions")
    op.drop_index(op.f("ix_auth_sessions_session_token_hash"), table_name="auth_sessions")
    op.drop_table("auth_sessions")

    op.drop_index(op.f("ix_users_google_sub"), table_name="users")
    op.drop_index(op.f("ix_users_email"), table_name="users")
    op.drop_table("users")
