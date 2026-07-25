"""SSE-first API — every endpoint streams `text/event-stream`.

Reads are served from the seed studios (see app/seed.py) so the Flutter app
renders real data over the wire today; `/ask` streams answer deltas + citations
from the RAG pipeline (or a graceful stub when no LLM key is set). Write
endpoints acknowledge over SSE for a uniform client.
"""

from __future__ import annotations

import asyncio
import uuid
from collections.abc import AsyncIterator

from fastapi import APIRouter, Body, Depends, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sse_starlette.sse import EventSourceResponse

from ..config import get_settings
from ..db import get_cockpit_session, get_shared_session, get_vector_session
from ..deps import get_current_user_id
from ..dto import AskCitationDTO, MeDTO, StudioDTO, TopicDTO
from ..models.cockpit import GeneratedTopic, IngestJob, Studio
from ..seed import seed_studios
from ..services import llm, rag
from ..sse import done, error, event

router = APIRouter(tags=["sse"])
_STUDIOS = seed_studios()


async def _load_topics(cockpit: AsyncSession, studio_id: uuid.UUID) -> list[TopicDTO]:
    """Load the studio's generated Study Objects (topics/flashcards/quizzes)."""
    try:
        rows = await cockpit.execute(
            select(GeneratedTopic)
            .where(GeneratedTopic.studio_id == studio_id)
            .order_by(GeneratedTopic.ordinal)
        )
        return [TopicDTO.model_validate(r.payload) for r in rows.scalars()]
    except Exception:  # noqa: BLE001
        return []


def _db_studio_to_dto(row: Studio, topics: list[TopicDTO] | None = None) -> StudioDTO:
    """Map a persisted studio to the wire DTO (topics filled after generation)."""
    return StudioDTO(
        id=str(row.id),
        title=row.title,
        subject=row.subject or "",
        created_at=row.created_at,
        updated_at=row.updated_at,
        topics=topics or [],
    )


async def _db_studios_for(cockpit: AsyncSession, user_id: uuid.UUID) -> list[StudioDTO]:
    """User's persisted studios (best-effort — empty if the DB is unavailable)."""
    try:
        rows = await cockpit.execute(
            select(Studio).where(Studio.user_id == user_id).order_by(Studio.created_at.desc())
        )
        out = []
        for r in rows.scalars():
            out.append(_db_studio_to_dto(r, await _load_topics(cockpit, r.id)))
        return out
    except Exception:  # noqa: BLE001 — DB down in local/seed mode
        return []


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
async def list_studios(
    user_id: uuid.UUID = Depends(get_current_user_id),
    cockpit: AsyncSession = Depends(get_cockpit_session),
) -> EventSourceResponse:
    async def gen() -> AsyncIterator[dict]:
        # The user's own (persisted) studios first, then the seed demos.
        for studio in await _db_studios_for(cockpit, user_id):
            yield event("item", studio)
        for studio in _STUDIOS.values():
            yield event("item", studio)
        yield done()

    return EventSourceResponse(gen())


@router.post("/studios")
async def create_studio(
    body: dict = Body(...),
    user_id: uuid.UUID = Depends(get_current_user_id),
    cockpit: AsyncSession = Depends(get_cockpit_session),
) -> EventSourceResponse:
    title = (body.get("title") or "").strip() or "Untitled Studio"
    subject = (body.get("subject") or "").strip() or None

    async def gen() -> AsyncIterator[dict]:
        try:
            studio = Studio(user_id=user_id, title=title, subject=subject)
            cockpit.add(studio)
            await cockpit.commit()
            await cockpit.refresh(studio)
            yield event("data", _db_studio_to_dto(studio))
            yield done()
        except Exception as exc:  # noqa: BLE001
            yield error(f"Could not create studio: {exc}")

    return EventSourceResponse(gen())


@router.get("/studios/{studio_id}")
async def get_studio(
    studio_id: str,
    user_id: uuid.UUID = Depends(get_current_user_id),
    cockpit: AsyncSession = Depends(get_cockpit_session),
) -> EventSourceResponse:
    async def gen() -> AsyncIterator[dict]:
        # Persisted studio (owned by the user) first, then the seed demos.
        try:
            sid = uuid.UUID(studio_id)
            row = await cockpit.get(Studio, sid)
            if row is not None and row.user_id == user_id:
                topics = await _load_topics(cockpit, sid)
                yield event("data", _db_studio_to_dto(row, topics))
                yield done()
                return
        except Exception:  # noqa: BLE001 — non-UUID id (seed) or DB down
            pass
        studio = _STUDIOS.get(studio_id)
        if studio is None:
            yield error(f"Studio {studio_id} not found")
            return
        yield event("data", studio)
        yield done()

    return EventSourceResponse(gen())


@router.get("/studios/{studio_id}/build/{job_id}")
async def build_progress(
    studio_id: str,
    job_id: uuid.UUID,
    user_id: uuid.UUID = Depends(get_current_user_id),
    cockpit: AsyncSession = Depends(get_cockpit_session),
) -> EventSourceResponse:
    """Stream an ingestion job's progress (queued → running → done/failed)."""

    async def gen() -> AsyncIterator[dict]:
        last = None
        for _ in range(600):  # ~5 min ceiling at 0.5s
            job = await cockpit.get(IngestJob, job_id)
            if job is None or job.user_id != user_id:
                yield error("Job not found")
                return
            if job.status != last:
                last = job.status
                yield event(
                    "progress",
                    {"status": job.status, "chunks": job.chunks_written},
                )
            if job.status in ("done", "failed"):
                if job.status == "failed":
                    yield error(job.error or "Ingestion failed")
                else:
                    yield done()
                return
            await asyncio.sleep(0.5)
            cockpit.expire_all()  # re-read on next get
        yield error("Ingestion timed out")

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
