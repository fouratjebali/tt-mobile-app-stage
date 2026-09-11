from datetime import UTC, datetime
from hashlib import pbkdf2_hmac
from hmac import compare_digest
from secrets import token_bytes

from sqlalchemy import desc, func, or_, select
from sqlalchemy.orm import Session

from app.models.auth import AdminCredential, AuthSession, User, UserRole
from app.models.email import Email, Stat
from app.models.notification import UserNotification


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

    def get_user_by_email(self, email: str) -> User | None:
        return self._db.scalar(select(User).where(User.email == email))

    def get_user_by_id(self, user_id: str) -> User | None:
        return self._db.get(User, user_id)

    def upsert_admin_credential(
        self,
        *,
        username: str,
        password: str,
        email: str,
        display_name: str,
    ) -> AdminCredential:
        cleaned_username = _normalize_username(username)
        if not cleaned_username:
            raise ValueError("Admin username is required.")
        if not password:
            raise ValueError("Admin password is required.")

        cleaned_email = email.strip().lower() or f"{cleaned_username}@local.admin"
        user = self._db.scalar(
            select(User).where(User.google_sub == f"admin:{cleaned_username}")
        )
        if user is None:
            user = self._db.scalar(select(User).where(User.email == cleaned_email))
            if user is None:
                user = User(
                    google_sub=f"admin:{cleaned_username}",
                    email=cleaned_email,
                )
                self._db.add(user)
            else:
                user.google_sub = f"admin:{cleaned_username}"

        user.email = cleaned_email
        user.display_name = display_name.strip() or "Dashboard Admin"
        user.role = UserRole.ADMIN.value
        user.is_active = True
        self._db.flush()

        credential = self._db.scalar(
            select(AdminCredential).where(AdminCredential.username == cleaned_username)
        )
        if credential is None:
            credential = AdminCredential(
                user_id=user.id,
                username=cleaned_username,
                password_hash=_hash_password(password),
                is_active=True,
            )
            self._db.add(credential)
        else:
            credential.user_id = user.id
            credential.password_hash = _hash_password(password)
            credential.is_active = True

        self._db.commit()
        self._db.refresh(credential)
        return credential

    def get_admin_credential(self, username: str) -> AdminCredential | None:
        cleaned_username = _normalize_username(username)
        if not cleaned_username:
            return None
        return self._db.scalar(
            select(AdminCredential).where(AdminCredential.username == cleaned_username)
        )

    def verify_admin_credentials(
        self,
        *,
        username: str,
        password: str,
    ) -> User | None:
        credential = self.get_admin_credential(username)
        if credential is None or not credential.is_active:
            return None
        if not _verify_password(password, credential.password_hash):
            return None
        if credential.user is None or not credential.user.is_active:
            return None

        credential.last_login_at = datetime.now(tz=UTC)
        self._db.commit()
        self._db.refresh(credential.user)
        return credential.user

    def list_users(
        self,
        *,
        search: str | None = None,
        limit: int = 100,
        offset: int = 0,
    ) -> tuple[list[User], int]:
        clauses = []
        if search:
            pattern = f"%{search.strip()}%"
            clauses.append(
                or_(
                    User.email.ilike(pattern),
                    User.display_name.ilike(pattern),
                )
            )

        statement = select(User)
        count_statement = select(func.count(User.id))
        if clauses:
            statement = statement.where(*clauses)
            count_statement = count_statement.where(*clauses)

        total = int(self._db.scalar(count_statement) or 0)
        users = list(
            self._db.scalars(
                statement.order_by(desc(User.created_at)).limit(limit).offset(offset)
            )
        )
        return users, total

    def update_user_role(self, *, user_id: str, role: UserRole) -> User | None:
        user = self.get_user_by_id(user_id)
        if user is None:
            return None

        user.role = role.value
        self._db.commit()
        self._db.refresh(user)
        return user

    def update_user_active_state(self, *, user_id: str, is_active: bool) -> User | None:
        user = self.get_user_by_id(user_id)
        if user is None:
            return None

        user.is_active = is_active
        self._db.commit()
        self._db.refresh(user)
        return user

    def promote_configured_admin(self, user: User, admin_emails: set[str]) -> User:
        if user.email.strip().lower() not in admin_emails:
            return user
        if user.role == UserRole.ADMIN.value and user.is_active:
            return user

        user.role = UserRole.ADMIN.value
        user.is_active = True
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

    def delete_sessions_for_user(self, user: User) -> None:
        sessions = list(
            self._db.scalars(select(AuthSession).where(AuthSession.user_id == user.id))
        )
        for session in sessions:
            self._db.delete(session)
        self._db.commit()

    def clear_mailbox_cache(self, user: User) -> None:
        self._db.query(UserNotification).filter(
            UserNotification.user_id == user.id
        ).delete(synchronize_session=False)
        self._db.query(Stat).filter(Stat.user_id == user.id).delete(
            synchronize_session=False
        )

        emails = list(self._db.scalars(select(Email).where(Email.user_id == user.id)))
        for email in emails:
            self._db.delete(email)
        self._db.commit()

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


def _normalize_username(username: str) -> str:
    return str(username or "").strip().lower()


def _hash_password(password: str) -> str:
    salt = token_bytes(16)
    iterations = 260_000
    digest = pbkdf2_hmac("sha256", password.encode("utf-8"), salt, iterations)
    return f"pbkdf2_sha256${iterations}${salt.hex()}${digest.hex()}"


def _verify_password(password: str, stored_hash: str) -> bool:
    try:
        algorithm, iterations_text, salt_hex, digest_hex = stored_hash.split("$", 3)
        iterations = int(iterations_text)
        salt = bytes.fromhex(salt_hex)
        expected = bytes.fromhex(digest_hex)
    except (ValueError, TypeError):
        return False
    if algorithm != "pbkdf2_sha256":
        return False

    actual = pbkdf2_hmac("sha256", password.encode("utf-8"), salt, iterations)
    return compare_digest(actual, expected)
