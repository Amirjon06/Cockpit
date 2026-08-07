"""Mastery tracking — persist per-user topic progress from quizzes and reviews.

Mastery is a rolling value in [0,1]. The deltas mirror the app's in-memory
repository so behaviour is identical online and offline:
    quiz:            correct +0.08 / wrong -0.05
    flashcard grade: quality*0.10 - 0.04   (Again 0.0 .. Easy 1.0)
    mark-reviewed:   +0.03
"""

from __future__ import annotations

import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..models.cockpit import TopicProgress


def _clamp(v: float) -> float:
    return max(0.0, min(1.0, v))


async def _get_or_create(
    cockpit: AsyncSession,
    *,
    user_id: uuid.UUID,
    studio_id: uuid.UUID,
    topic_id: str,
) -> TopicProgress:
    row = (
        await cockpit.execute(
            select(TopicProgress).where(
                TopicProgress.user_id == user_id,
                TopicProgress.topic_id == topic_id,
            )
        )
    ).scalar_one_or_none()
    if row is None:
        # Set counters explicitly — column server-defaults aren't applied to the
        # in-memory object until flush, so they'd be None before the first commit.
        row = TopicProgress(
            user_id=user_id,
            studio_id=studio_id,
            topic_id=topic_id,
            mastery=0.0,
            quiz_attempts=0,
            quiz_correct=0,
            flashcard_reviews=0,
            reviews=0,
        )
        cockpit.add(row)
    return row


async def record_quiz(
    cockpit: AsyncSession,
    *,
    user_id: uuid.UUID,
    studio_id: uuid.UUID,
    topic_id: str,
    correct: bool,
) -> float:
    row = await _get_or_create(
        cockpit, user_id=user_id, studio_id=studio_id, topic_id=topic_id
    )
    row.mastery = _clamp(row.mastery + (0.08 if correct else -0.05))
    row.quiz_attempts += 1
    if correct:
        row.quiz_correct += 1
    await cockpit.commit()
    return row.mastery


async def record_flashcard(
    cockpit: AsyncSession,
    *,
    user_id: uuid.UUID,
    studio_id: uuid.UUID,
    topic_id: str,
    quality: float,
) -> float:
    row = await _get_or_create(
        cockpit, user_id=user_id, studio_id=studio_id, topic_id=topic_id
    )
    row.mastery = _clamp(row.mastery + (quality * 0.10 - 0.04))
    row.flashcard_reviews += 1
    await cockpit.commit()
    return row.mastery


async def record_reviewed(
    cockpit: AsyncSession,
    *,
    user_id: uuid.UUID,
    studio_id: uuid.UUID,
    topic_id: str,
) -> float:
    row = await _get_or_create(
        cockpit, user_id=user_id, studio_id=studio_id, topic_id=topic_id
    )
    row.mastery = _clamp(row.mastery + 0.03)
    row.reviews += 1
    await cockpit.commit()
    return row.mastery


async def mastery_map(
    cockpit: AsyncSession,
    *,
    user_id: uuid.UUID,
    studio_id: uuid.UUID,
) -> dict[str, float]:
    """topic_id -> mastery for a studio, to overlay onto the topics at load."""
    rows = await cockpit.execute(
        select(TopicProgress.topic_id, TopicProgress.mastery).where(
            TopicProgress.user_id == user_id,
            TopicProgress.studio_id == studio_id,
        )
    )
    return {tid: float(m) for tid, m in rows.all()}
