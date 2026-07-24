"""FastAPI dependencies: DB sessions + current user + service factories."""

from __future__ import annotations

import uuid

from fastapi import Depends, Header, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from .db import get_cockpit_session, get_shared_session, get_vector_session
from .services.credits import CreditsService


async def get_current_user_id(
    x_user_id: str | None = Header(default=None, alias="X-User-Id"),
) -> uuid.UUID:
    """Resolve the caller's user id.

    TODO(lead): replace header trust with real auth — validate the octopilot
    session token (the shared `sessions` table) or a JWT, and derive user_id
    from it. Header-based identity is a scaffold placeholder ONLY and must not
    reach production as-is.
    """
    if not x_user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing X-User-Id"
        )
    try:
        return uuid.UUID(x_user_id)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid X-User-Id"
        ) from exc


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
