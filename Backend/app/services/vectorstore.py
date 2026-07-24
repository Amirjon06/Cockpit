"""pgvector operations: write chunks and run tenant-scoped hybrid search.

Hybrid = dense (cosine over `embedding`) + lexical (ts_rank over `tsv`), combined
with Reciprocal Rank Fusion (RRF). Every query is filtered by `user_id` (and
`studio_id`) *inside* the SQL, so a user can never retrieve another user's
chunks. RRF avoids having to tune a weight between two different score scales.
"""

from __future__ import annotations

import uuid
from dataclasses import dataclass

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession


@dataclass
class Retrieved:
    chunk_id: uuid.UUID
    document_id: uuid.UUID
    ordinal: int
    content: str
    score: float


async def insert_chunks(
    session: AsyncSession,
    *,
    rows: list[dict],
) -> int:
    """Bulk-insert chunk rows. Each row: id, document_id, studio_id, user_id,
    ordinal, content, embedding (list[float]). `tsv` is computed in SQL."""
    if not rows:
        return 0
    stmt = text(
        """
        INSERT INTO chunks
            (id, document_id, studio_id, user_id, ordinal, content, embedding, tsv)
        VALUES
            (:id, :document_id, :studio_id, :user_id, :ordinal, :content,
             :embedding, to_tsvector('english', :content))
        """
    )
    await session.execute(stmt, rows)
    await session.commit()
    return len(rows)


async def hybrid_search(
    session: AsyncSession,
    *,
    user_id: uuid.UUID,
    studio_id: uuid.UUID,
    query_text: str,
    query_embedding: list[float],
    top_k: int,
) -> list[Retrieved]:
    """Return top_k chunks fused from dense + lexical rankings (RRF, k=60)."""
    stmt = text(
        """
        WITH dense AS (
            SELECT id, document_id, ordinal, content,
                   ROW_NUMBER() OVER (ORDER BY embedding <=> :qvec) AS rnk
            FROM chunks
            WHERE user_id = :user_id AND studio_id = :studio_id
            ORDER BY embedding <=> :qvec
            LIMIT :cand
        ),
        lexical AS (
            SELECT id, document_id, ordinal, content,
                   ROW_NUMBER() OVER (
                       ORDER BY ts_rank(tsv, plainto_tsquery('english', :qtext)) DESC
                   ) AS rnk
            FROM chunks
            WHERE user_id = :user_id AND studio_id = :studio_id
              AND tsv @@ plainto_tsquery('english', :qtext)
            LIMIT :cand
        ),
        fused AS (
            SELECT id, document_id, ordinal, content,
                   SUM(1.0 / (60 + rnk)) AS score
            FROM (
                SELECT * FROM dense
                UNION ALL
                SELECT * FROM lexical
            ) u
            GROUP BY id, document_id, ordinal, content
        )
        SELECT id, document_id, ordinal, content, score
        FROM fused
        ORDER BY score DESC
        LIMIT :top_k
        """
    )
    result = await session.execute(
        stmt,
        {
            "qvec": str(query_embedding),
            "qtext": query_text,
            "user_id": str(user_id),
            "studio_id": str(studio_id),
            "cand": max(top_k * 4, 20),
            "top_k": top_k,
        },
    )
    return [
        Retrieved(
            chunk_id=row.id,
            document_id=row.document_id,
            ordinal=row.ordinal,
            content=row.content,
            score=float(row.score),
        )
        for row in result
    ]
