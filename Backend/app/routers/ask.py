"""Ask AI — RAG query endpoint (Screen 14 backend)."""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from ..config import get_settings
from ..db import get_cockpit_session, get_shared_session, get_vector_session
from ..deps import get_credits, get_current_user_id
from ..models.cockpit import Studio
from ..schemas import AskRequest, AskResponse, Citation
from ..services import rag
from ..services.credits import CreditsService

router = APIRouter(prefix="/ask", tags=["ask"])


@router.post("", response_model=AskResponse)
async def ask(
    body: AskRequest,
    user_id: uuid.UUID = Depends(get_current_user_id),
    cockpit: AsyncSession = Depends(get_cockpit_session),
    vector: AsyncSession = Depends(get_vector_session),
    shared: AsyncSession | None = Depends(get_shared_session),
    credits: CreditsService = Depends(get_credits),
) -> AskResponse:
    settings = get_settings()

    # Ownership: the studio must belong to the caller.
    studio = await cockpit.get(Studio, body.studio_id)
    if studio is None or studio.user_id != user_id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Studio not found")

    if not await credits.check(user_id, cost=1):
        raise HTTPException(status.HTTP_402_PAYMENT_REQUIRED, "Insufficient credits")

    answer, hits, model = await rag.answer_question(
        vector=vector,
        shared=shared,
        user_id=user_id,
        studio_id=body.studio_id,
        question=body.question,
        top_k=body.top_k or settings.rag_top_k,
    )

    await credits.debit(user_id, cost=1)  # no-op until the ledger is confirmed

    citations = [
        Citation(
            chunk_id=h.chunk_id,
            document_id=h.document_id,
            ordinal=h.ordinal,
            score=round(h.score, 4),
            snippet=h.content[:280],
        )
        for h in hits
    ]
    return AskResponse(answer=answer, citations=citations, model=model)
