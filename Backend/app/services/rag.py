"""RAG orchestration: text extraction, chunking, ingestion, and answering.

Ingestion pipeline (async, kicked off after upload):
    object storage -> extract text -> chunk -> embed (local) -> pgvector

Answering pipeline:
    embed question -> hybrid search (tenant-scoped) -> build context -> OpenRouter
"""

from __future__ import annotations

import base64
import uuid

import httpx
from sqlalchemy import update
from sqlalchemy.ext.asyncio import AsyncSession

from ..config import get_settings
from ..models.cockpit import Document, IngestJob
from . import generate, llm, vectorstore
from .embeddings import get_embedder
from .objectstore import get_object_store


# ---------------------------------------------------------------------------
# Text extraction
# ---------------------------------------------------------------------------
_HIRARA_TIMEOUT = 120.0
_OFFICE_EXT = (".docx", ".doc", ".pptx", ".ppt", ".xlsx", ".xls")
_IMAGE_EXT = (".png", ".jpg", ".jpeg", ".webp", ".tif", ".tiff", ".bmp", ".gif")
_AV_EXT = (".mp3", ".wav", ".m4a", ".flac", ".ogg", ".mp4", ".mov", ".mkv", ".webm")


async def _hirara_call(tool: str, arguments: dict) -> dict:
    """Invoke one Hirara hub tool over its `POST /call` gateway."""
    settings = get_settings()
    headers = {"Content-Type": "application/json"}
    if settings.hirara_hub_token:
        headers["Authorization"] = f"Bearer {settings.hirara_hub_token}"
    async with httpx.AsyncClient(timeout=_HIRARA_TIMEOUT) as client:
        resp = await client.post(
            f"{settings.hirara_hub_url}/call",
            json={"name": tool, "arguments": arguments},
            headers=headers,
        )
        resp.raise_for_status()
        return resp.json()


async def extract_text(filename: str, mime: str, data: bytes) -> str:
    """Extract plain text from an uploaded file.

    Text/markdown decode directly (fast path, no network). Everything else is
    handled by the Hirara hub: PDFs via `pdf_read` (with an `ocr_read` fallback
    for scanned/no-text-layer PDFs), Office docs via `office_read` (Markdown),
    and images via `ocr_read`. Audio/video (STT) is not enabled yet.
    """
    name = filename.lower()
    mime = mime or ""

    # Fast path: plain text / markdown.
    if mime.startswith("text/") or name.endswith((".txt", ".md", ".markdown")):
        return data.decode("utf-8", errors="replace")

    b64 = base64.b64encode(data).decode()

    # PDF — embedded text layer first, OCR fallback when it comes back empty.
    if mime == "application/pdf" or name.endswith(".pdf"):
        res = await _hirara_call("pdf_read", {"pdf_base64": b64})
        text = (res.get("text") or "").strip()
        if len(text) >= 20:
            return text
        ocr = await _hirara_call(
            "ocr_read", {"file_base64": b64, "languages": ["en"]}
        )
        return (ocr.get("text") or ocr.get("markdown") or text).strip()

    # Office documents → Markdown.
    if name.endswith(_OFFICE_EXT) or "officedocument" in mime or "msword" in mime \
            or "ms-powerpoint" in mime or "ms-excel" in mime:
        res = await _hirara_call(
            "office_read", {"file_base64": b64, "filename": filename}
        )
        return (res.get("markdown") or res.get("text") or "").strip()

    # Images → OCR.
    if mime.startswith("image/") or name.endswith(_IMAGE_EXT):
        res = await _hirara_call(
            "ocr_read", {"file_base64": b64, "languages": ["en"]}
        )
        return (res.get("text") or res.get("markdown") or "").strip()

    # Audio / video — STT service not deployed yet (Hirara Phase 2).
    if mime.startswith(("audio/", "video/")) or name.endswith(_AV_EXT):
        raise NotImplementedError(
            "Audio/video transcription (speech-to-text) is not enabled yet."
        )

    raise NotImplementedError(f"No text extractor for mime={mime!r} ({filename}).")


# ---------------------------------------------------------------------------
# Chunking (word-approx tokens with overlap)
# ---------------------------------------------------------------------------
def chunk_text(text: str, *, size: int, overlap: int) -> list[str]:
    words = text.split()
    if not words:
        return []
    step = max(size - overlap, 1)
    chunks: list[str] = []
    for start in range(0, len(words), step):
        window = words[start : start + size]
        if window:
            chunks.append(" ".join(window))
        if start + size >= len(words):
            break
    return chunks


# ---------------------------------------------------------------------------
# Ingestion
# ---------------------------------------------------------------------------
async def run_ingest(
    *,
    cockpit: AsyncSession,
    vector: AsyncSession,
    job_id: uuid.UUID,
    document: Document,
) -> None:
    settings = get_settings()
    await _set_job(cockpit, job_id, status="running")
    try:
        raw = get_object_store().get(document.object_key)
        text = await extract_text(document.filename, document.mime, raw)
        pieces = chunk_text(
            text, size=settings.rag_chunk_tokens, overlap=settings.rag_chunk_overlap
        )
        embedder = get_embedder()
        vectors = embedder.embed(pieces) if pieces else []

        rows = [
            {
                "id": uuid.uuid4(),
                "document_id": document.id,
                "studio_id": document.studio_id,
                "user_id": document.user_id,
                "ordinal": i,
                "content": piece,
                "embedding": vectors[i],
            }
            for i, piece in enumerate(pieces)
        ]
        written = await vectorstore.insert_chunks(vector, rows=rows)

        # Generate Study Objects (topics/flashcards/quizzes) from the chunks.
        # Resolve the real OpenRouter key/model from the shared octopilot DB
        # (same as /ask) so generation uses the LLM, not the offline stub. Falls
        # back to env, then to the deterministic stub. Best-effort — never fails
        # the ingest job.
        try:
            from ..db import SharedSession

            api_key = settings.openrouter_api_key
            model = settings.openrouter_model
            if SharedSession is not None:
                async with SharedSession() as shared:
                    api_key, primary = await llm.resolve_credentials(shared)
                    # Use the FAST secondary model for bulk generation (many
                    # per-lesson calls); the primary stays for interactive /ask.
                    model = await llm.get_setting(shared, "secondary_model", primary)

            topics = await generate.generate_topics(
                chunks=pieces,
                studio_id=str(document.studio_id),
                api_key=api_key,
                model=model,
                user_id=document.user_id,
                vector=vector,
            )
            await generate.persist_topics(
                cockpit,
                studio_id=document.studio_id,
                user_id=document.user_id,
                topics=topics,
            )

            # Scenario Mode — application scenarios (best-effort, own try below).
            scenarios = await generate.generate_scenarios(
                chunks=pieces,
                studio_id=str(document.studio_id),
                api_key=api_key,
                model=model,
            )
            await generate.persist_scenarios(
                cockpit,
                studio_id=document.studio_id,
                user_id=document.user_id,
                scenarios=scenarios,
            )
        except Exception:  # noqa: BLE001 — generation is best-effort
            pass

        await _set_job(cockpit, job_id, status="done", chunks_written=written)
        await cockpit.execute(
            update(Document).where(Document.id == document.id).values(status="ready")
        )
        await cockpit.commit()
    except Exception as exc:  # noqa: BLE001 — record the failure on the job
        await _set_job(cockpit, job_id, status="failed", error=str(exc))
        await cockpit.execute(
            update(Document).where(Document.id == document.id).values(status="failed")
        )
        await cockpit.commit()


async def _set_job(session: AsyncSession, job_id: uuid.UUID, **values) -> None:
    await session.execute(update(IngestJob).where(IngestJob.id == job_id).values(**values))
    await session.commit()


# ---------------------------------------------------------------------------
# Answering
# ---------------------------------------------------------------------------
async def answer_question(
    *,
    vector: AsyncSession,
    shared: AsyncSession | None,
    user_id: uuid.UUID,
    studio_id: uuid.UUID,
    question: str,
    top_k: int,
) -> tuple[str, list[vectorstore.Retrieved], str]:
    settings = get_settings()
    embedder = get_embedder()
    q_vec = embedder.embed([question])[0]

    hits = await vectorstore.hybrid_search(
        vector,
        user_id=user_id,
        studio_id=studio_id,
        query_text=question,
        query_embedding=q_vec,
        top_k=top_k,
    )
    context_hits = hits[: settings.rag_context_k]
    context = llm.build_context_block([h.content for h in context_hits])

    api_key, model = await llm.resolve_credentials(shared)
    answer = await llm.generate(
        api_key=api_key, model=model, question=question, context=context
    )
    return answer, context_hits, model
