from datetime import datetime

from sqlalchemy import desc, select
from sqlalchemy.orm import Session

from app.models.auth import AuthSession, User


class AuthRepository:
    def __init__(self, db: Session) -> None:
        self._db = db

    def upsert_user(
        self,
        *,
        google_sub: str,
        email: str,
        display_name: str | None,
        photo_url: str | None,
    ) -> User:
        user = self._db.scalar(select(User).where(User.google_sub == google_sub))

        if user is None:
            user = self._db.scalar(select(User).where(User.email == email))
            if user is None:
                user = User(google_sub=google_sub, email=email)
                self._db.add(user)
            else:
                user.google_sub = google_sub

        user.email = email
        user.display_name = display_name
        user.photo_url = photo_url
        self._db.commit()
        self._db.refresh(user)
        return user

    def create_session(
        self,
        *,
        user: User,
        session_token_hash: str,
        google_access_token: str,
        google_id_token: str | None,
        google_refresh_token: str | None,
        expires_at: datetime | None,
    ) -> AuthSession:
        session = AuthSession(
            user_id=user.id,
            session_token_hash=session_token_hash,
            google_access_token=google_access_token,
            google_id_token=google_id_token,
            google_refresh_token=google_refresh_token,
            expires_at=expires_at,
        )
        self._db.add(session)
        self._db.commit()
        self._db.refresh(session)
        return session

    def get_user_by_session_hash(self, session_token_hash: str) -> User | None:
        session = self._db.scalar(
            select(AuthSession).where(
                AuthSession.session_token_hash == session_token_hash
            )
        )
        return session.user if session is not None else None

    def get_latest_session_for_user(self, user: User) -> AuthSession | None:
        return self._db.scalar(
            select(AuthSession)
            .where(AuthSession.user_id == user.id)
            .order_by(desc(AuthSession.created_at))
        )

    def delete_session(self, session_token_hash: str) -> None:
        session = self._db.scalar(
            select(AuthSession).where(
                AuthSession.session_token_hash == session_token_hash
            )
        )
        if session is None:
            return

        self._db.delete(session)
        self._db.commit()
