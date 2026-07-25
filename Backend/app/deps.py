"""FastAPI dependencies: DB sessions + current user + service factories."""

from __future__ import annotations

import uuid

from fastapi import Depends, Header, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from .auth import verify_bearer
from .config import get_settings
from .db import get_cockpit_session, get_shared_session, get_vector_session
from .services.credits import CreditsService


async def get_current_user_id(
    authorization: str | None = Header(default=None),
    x_user_id: str | None = Header(default=None, alias="X-User-Id"),
) -> uuid.UUID:
    """Resolve the caller's user id.

    Priority:
      1. `Authorization: Bearer <firebase-id-token>` — verified against
         Octopilot's Firebase project (see app/auth.py). This is real auth.
      2. `X-User-Id` dev header — only when Firebase is off, or when
         ALLOW_DEV_USER_HEADER is on (turn it off in prod).
    """
    settings = get_settings()

    if authorization and authorization.lower().startswith("bearer "):
        token = authorization[7:].strip()
        user = verify_bearer(token)
        if user is not None:
            return user.user_id
        # Firebase is on but the token is invalid → reject.
        if settings.firebase_enabled:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token"
            )

    dev_allowed = settings.allow_dev_user_header or not settings.firebase_enabled
    if x_user_id and dev_allowed:
        try:
            return uuid.UUID(x_user_id)
        except ValueError as exc:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid X-User-Id"
            ) from exc

    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Missing credentials (Authorization: Bearer, or X-User-Id in dev)",
    )


def get_credits(
    shared: AsyncSession | None = Depends(get_shared_session),
) -> CreditsService:
    return CreditsService(shared)


# Re-exported so routers import sessions from one place.
CockpitDep = Depends(get_cockpit_session)
VectorDep = Depends(get_vector_session)
SharedDep = Depends(get_shared_session)
UserDep = Depends(get_current_user_id)
CreditsDep = Depends(get_credits)
