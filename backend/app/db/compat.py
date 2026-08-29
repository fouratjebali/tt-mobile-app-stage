from sqlalchemy import inspect, text
from sqlalchemy.engine import Engine


def ensure_email_workflow_schema(engine: Engine) -> None:
    inspector = inspect(engine)
    if "emails" not in inspector.get_table_names():
        return

    columns = {column["name"]: column for column in inspector.get_columns("emails")}
    with engine.begin() as connection:
        if "gmail_id" in columns and "gmail_message_id" not in columns:
            connection.execute(
                text("ALTER TABLE emails RENAME COLUMN gmail_id TO gmail_message_id")
            )
        if "body_text" in columns and "body" not in columns:
            connection.execute(
                text("ALTER TABLE emails RENAME COLUMN body_text TO body")
            )

        connection.execute(
            text("ALTER TABLE emails ADD COLUMN IF NOT EXISTS user_id VARCHAR(36)")
        )
        connection.execute(
            text("ALTER TABLE emails ADD COLUMN IF NOT EXISTS thread_id VARCHAR(255)")
        )
        connection.execute(
            text("ALTER TABLE emails ADD COLUMN IF NOT EXISTS body_preview TEXT")
        )
        connection.execute(
            text(
                "ALTER TABLE emails ADD COLUMN IF NOT EXISTS "
                "created_at TIMESTAMPTZ NOT NULL DEFAULT now()"
            )
        )
        connection.execute(
            text(
                "ALTER TABLE emails ADD COLUMN IF NOT EXISTS "
                "updated_at TIMESTAMPTZ NOT NULL DEFAULT now()"
            )
        )

        connection.execute(
            text(
                "ALTER TABLE emails ALTER COLUMN status TYPE VARCHAR(50) "
                "USING status::text"
            )
        )
        connection.execute(
            text(
                "ALTER TABLE emails ALTER COLUMN status "
                "SET DEFAULT 'PENDING_ANALYSIS'"
            )
        )
        connection.execute(text("ALTER TABLE emails ALTER COLUMN subject TYPE TEXT"))
        connection.execute(text("ALTER TABLE emails ALTER COLUMN sender DROP NOT NULL"))
        connection.execute(
            text("ALTER TABLE emails ALTER COLUMN recipients DROP NOT NULL")
        )
        connection.execute(
            text("ALTER TABLE emails ALTER COLUMN body DROP NOT NULL")
        )
        connection.execute(
            text("ALTER TABLE emails ALTER COLUMN received_at DROP NOT NULL")
        )

        recipients_type = str(columns.get("recipients", {}).get("type", "")).lower()
        if "json" not in recipients_type:
            connection.execute(
                text(
                    "ALTER TABLE emails ALTER COLUMN recipients TYPE JSONB "
                    "USING CASE "
                    "WHEN recipients IS NULL OR recipients = '' THEN NULL "
                    "ELSE to_jsonb(string_to_array(recipients, ',')) "
                    "END"
                )
            )

        connection.execute(text("DROP INDEX IF EXISTS ix_emails_gmail_id"))
        connection.execute(
            text(
                "CREATE INDEX IF NOT EXISTS ix_emails_gmail_message_id "
                "ON emails (gmail_message_id)"
            )
        )
        connection.execute(
            text("CREATE INDEX IF NOT EXISTS ix_emails_user_id ON emails (user_id)")
        )
        connection.execute(
            text("CREATE INDEX IF NOT EXISTS ix_emails_status ON emails (status)")
        )
        connection.execute(
            text("CREATE INDEX IF NOT EXISTS ix_emails_sender ON emails (sender)")
        )
        connection.execute(
            text(
                "CREATE INDEX IF NOT EXISTS ix_emails_received_at "
                "ON emails (received_at)"
            )
        )
