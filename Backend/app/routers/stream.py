"""SSE-first API — every endpoint streams `text/event-stream`.

Reads are served from the seed studios (see app/seed.py) so the Flutter app
renders real data over the wire today; `/ask` streams answer deltas + citations
from the RAG pipeline (or a graceful stub when no LLM key is set). Write
endpoints acknowledge over SSE for a uniform client.
"""

from __future__ import annotations

import uuid
from collections.abc import AsyncIterator

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sse_starlette.sse import EventSourceResponse

from ..config import get_settings
from ..db import get_shared_session, get_vector_session
from ..deps import get_current_user_id
from ..dto import AskCitationDTO, MeDTO
from ..seed import seed_studios
from ..services import llm, rag
from ..sse import done, error, event

router = APIRouter(tags=["sse"])
_STUDIOS = seed_studios()


@router.get("/me")
async def me(
    user_id: uuid.UUID = Depends(get_current_user_id),
    shared: AsyncSession | None = Depends(get_shared_session),
) -> EventSourceResponse:
    async def gen() -> AsyncIterator[dict]:
        credits = None
        email = None
        if shared is not None:
            from sqlalchemy import select

            from ..models.shared import User

            row = await shared.execute(
                select(User.email, User.credits).where(User.id == user_id)
            )
            found = row.first()
            if found:
                email, credits = found
        yield event("data", MeDTO(id=str(user_id), email=email, credits=credits))
        yield done()

    return EventSourceResponse(gen())


@router.get("/studios")
async def list_studios() -> EventSourceResponse:
    async def gen() -> AsyncIterator[dict]:
        for studio in _STUDIOS.values():
            yield event("item", studio)
        yield done()

    return EventSourceResponse(gen())


@router.get("/studios/{studio_id}")
async def get_studio(studio_id: str) -> EventSourceResponse:
    async def gen() -> AsyncIterator[dict]:
        studio = _STUDIOS.get(studio_id)
        if studio is None:
            yield error(f"Studio {studio_id} not found")
            return
        yield event("data", studio)
        yield done()

    return EventSourceResponse(gen())


@router.get("/studios/{studio_id}/topics/{topic_id}")
async def get_topic(studio_id: str, topic_id: str) -> EventSourceResponse:
    async def gen() -> AsyncIterator[dict]:
        studio = _STUDIOS.get(studio_id)
        topic = (
            next((t for t in studio.topics if t.id == topic_id), None)
            if studio
            else None
        )
        if topic is None:
            yield error(f"Topic {topic_id} not found")
            return
        yield event("data", topic)
        yield done()

    return EventSourceResponse(gen())


@router.get("/ask")
async def ask(
    studio_id: str = Query(...),
    q: str = Query(..., min_length=1),
    user_id: uuid.UUID = Depends(get_current_user_id),
    vector: AsyncSession = Depends(get_vector_session),
    shared: AsyncSession | None = Depends(get_shared_session),
) -> EventSourceResponse:
    settings = get_settings()

    async def gen() -> AsyncIterator[dict]:
        try:
            # Best-effort retrieval (empty until documents are ingested).
            from ..services.embeddings import get_embedder
            from ..services.vectorstore import hybrid_search

            hits = []
            try:
                q_vec = get_embedder().embed([q])[0]
                hits = await hybrid_search(
                    vector,
                    user_id=user_id,
                    studio_id=uuid.uuid5(uuid.NAMESPACE_DNS, studio_id),
                    query_text=q,
                    query_embedding=q_vec,
                    top_k=settings.rag_top_k,
                )
            except Exception:  # noqa: BLE001 — retrieval optional in seed mode
                hits = []

            context = llm.build_context_block([h.content for h in hits])
            api_key, model = await llm.resolve_credentials(shared)

            async for delta in llm.generate_stream(
                api_key=api_key, model=model, question=q, context=context
            ):
                yield event("delta", {"text": delta})

            if hits:
                yield event(
                    "citations",
                    [
                        AskCitationDTO(
                            chunk_id=str(h.chunk_id),
                            document_id=str(h.document_id),
                            ordinal=h.ordinal,
                            score=round(h.score, 4),
                            snippet=h.content[:280],
                        ).model_dump(by_alias=True)
                        for h in hits[: settings.rag_context_k]
                    ],
                )
            yield event("meta", {"model": model})
            yield done()
        except Exception as exc:  # noqa: BLE001
            yield error(str(exc))

    return EventSourceResponse(gen())


def _ack() -> EventSourceResponse:
    async def gen() -> AsyncIterator[dict]:
        yield event("ok", {"ok": True})
        yield done()

    return EventSourceResponse(gen())


@router.post("/studios/{studio_id}/topics/{topic_id}/quiz-result")
async def quiz_result(
    studio_id: str, topic_id: str, correct: bool = Query(...)
) -> EventSourceResponse:
    # TODO: persist mastery for user-owned studios. Seed studios are read-only.
    return _ack()


@router.post("/studios/{studio_id}/topics/{topic_id}/flashcard-review")
async def flashcard_review(
    studio_id: str, topic_id: str, quality: float = Query(..., ge=0.0, le=1.0)
) -> EventSourceResponse:
    return _ack()


@router.post("/studios/{studio_id}/topics/{topic_id}/mark-reviewed")
async def mark_reviewed(studio_id: str, topic_id: str) -> EventSourceResponse:
    return _ack()
