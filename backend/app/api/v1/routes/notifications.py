from typing import Annotated

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from app.api.dependencies import get_current_user
from app.db.session import get_db
from app.models.auth import User
from app.models.notification import UserNotification
from app.repositories.email_workflow_repository import EmailWorkflowRepository
from app.schemas.notification import NotificationListResponse, NotificationResponse


router = APIRouter()


@router.get("", response_model=NotificationListResponse)
async def list_notifications(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
    limit: int = Query(default=50, ge=1, le=100),
    unread_only: bool = Query(default=False),
) -> NotificationListResponse:
    repository = EmailWorkflowRepository(db)
    notifications = repository.list_notifications(
        user=user,
        limit=limit,
        unread_only=unread_only,
    )
    return NotificationListResponse(
        count=len(notifications),
        unread_count=repository.unread_notification_count(user=user),
        notifications=[_to_response(notification) for notification in notifications],
    )


@router.post("/{notification_id}/read", status_code=status.HTTP_204_NO_CONTENT)
async def mark_notification_read(
    notification_id: str,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
) -> None:
    EmailWorkflowRepository(db).mark_notification_read(
        user=user,
        notification_id=notification_id,
    )


def _to_response(notification: UserNotification) -> NotificationResponse:
    return NotificationResponse(
        id=notification.id,
        email_id=notification.email.gmail_message_id if notification.email else None,
        kind=notification.kind,
        title=notification.title,
        body=notification.body,
        data=notification.data,
        created_at=notification.created_at,
        read_at=notification.read_at,
    )
