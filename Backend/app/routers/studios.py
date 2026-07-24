"""Studio CRUD (Cockpit business data)."""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..db import get_cockpit_session
from ..deps import get_current_user_id
from ..models.cockpit import Studio
from ..schemas import StudioCreate, StudioOut

router = APIRouter(prefix="/studios", tags=["studios"])


@router.post("", response_model=StudioOut, status_code=status.HTTP_201_CREATED)
async def create_studio(
    body: StudioCreate,
    user_id: uuid.UUID = Depends(get_current_user_id),
    session: AsyncSession = Depends(get_cockpit_session),
) -> Studio:
    studio = Studio(user_id=user_id, title=body.title, subject=body.subject)
    session.add(studio)
    await session.commit()
    await session.refresh(studio)
    return studio


@router.get("", response_model=list[StudioOut])
async def list_studios(
    user_id: uuid.UUID = Depends(get_current_user_id),
    session: AsyncSession = Depends(get_cockpit_session),
) -> list[Studio]:
    rows = await session.execute(
        select(Studio).where(Studio.user_id == user_id).order_by(Studio.created_at.desc())
    )
    return list(rows.scalars())


@router.get("/{studio_id}", response_model=StudioOut)
async def get_studio(
    studio_id: uuid.UUID,
    user_id: uuid.UUID = Depends(get_current_user_id),
    session: AsyncSession = Depends(get_cockpit_session),
) -> Studio:
    studio = await session.get(Studio, studio_id)
    if studio is None or studio.user_id != user_id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Studio not found")
    return studio
