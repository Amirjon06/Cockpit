"""Turn a studio's RAG chunks into Study Objects (topics + flashcards + quizzes).

After ingestion, this reads the studio's chunks and asks the LLM (OpenRouter) to
extract a handful of topics, each with explanations, flashcards, and quiz
questions — the structured content the Flutter app renders. Output is TopicDTO-
shaped (camelCase) JSON so `get_studio` can embed it directly.

Without an LLM key it falls back to a deterministic stub (one topic from the
first chunks) so the pipeline still completes offline and in tests.
"""

from __future__ import annotations

import json
import uuid

from sqlalchemy import delete
from sqlalchemy.ext.asyncio import AsyncSession

from ..models.cockpit import GeneratedTopic
from . import llm

_SCHEMA_HINT = """
Return ONLY JSON: an array of up to 5 topics. Each topic:
{
  "title": str, "definition": str, "simpleExplanation": str,
  "detailedExplanation": str, "whyItMatters": str,
  "examples": [str], "commonMistakes": [str],
  "flashcards": [{"front": str, "back": str}],
  "quizQuestions": [{"question": str, "choices": [str], "answer": str, "explanation": str}],
  "difficulty": 1-5, "importance": 1-5
}
Base everything ONLY on the provided material. No prose outside the JSON.
""".strip()


def _shape_topic(raw: dict, studio_id: str) -> dict:
    """Normalize an LLM/stub topic into a full TopicDTO dict (camelCase)."""
    topic_id = f"gen_{uuid.uuid4().hex[:10]}"

    def _flashcard(fc: dict) -> dict:
        return {
            "id": f"fc_{uuid.uuid4().hex[:8]}",
            "topicId": topic_id,
            "front": fc.get("front", ""),
            "back": fc.get("back", ""),
            "type": "definition",
            "difficulty": 2,
            "status": "fresh",
        }

    def _quiz(q: dict) -> dict:
        choices = q.get("choices") or []
        return {
            "id": f"q_{uuid.uuid4().hex[:8]}",
            "topicId": topic_id,
            "type": "multipleChoice" if len(choices) > 2 else "trueFalse",
            "question": q.get("question", ""),
            "choices": choices,
            "answer": q.get("answer", ""),
            "explanation": q.get("explanation", ""),
            "difficulty": 2,
        }

    return {
        "id": topic_id,
        "studioId": studio_id,
        "title": raw.get("title", "Untitled Topic"),
        "subject": raw.get("subject", ""),
        "definition": raw.get("definition", ""),
        "simpleExplanation": raw.get("simpleExplanation", ""),
        "detailedExplanation": raw.get("detailedExplanation", ""),
        "whyItMatters": raw.get("whyItMatters", ""),
        "examples": raw.get("examples", []),
        "commonMistakes": raw.get("commonMistakes", []),
        "relatedTopicIds": [],
        "prerequisites": [],
        "memoryHooks": [],
        "sources": [],
        "flashcards": [_flashcard(f) for f in (raw.get("flashcards") or [])],
        "quizQuestions": [_quiz(q) for q in (raw.get("quizQuestions") or [])],
        "difficulty": int(raw.get("difficulty", 3) or 3),
        "importance": int(raw.get("importance", 3) or 3),
        "estimatedStudyTimeMinutes": 12,
        "mastery": 0.0,
    }


def _stub_topics(chunks: list[str], studio_id: str) -> list[dict]:
    """Deterministic offline fallback — one topic summarizing the material."""
    if not chunks:
        return []
    excerpt = " ".join(chunks)[:400]
    return [
        _shape_topic(
            {
                "title": "Overview",
                "definition": excerpt,
                "simpleExplanation": "A summary generated offline (no LLM key set).",
                "detailedExplanation": excerpt,
                "whyItMatters": "Connect an LLM key to generate full study content.",
                "flashcards": [
                    {"front": "What is this studio about?", "back": excerpt[:160]},
                ],
                "quizQuestions": [
                    {
                        "question": "Is this generated from your material?",
                        "choices": ["Yes", "No"],
                        "answer": "Yes",
                        "explanation": "Built from the uploaded document's chunks.",
                    }
                ],
            },
            studio_id,
        )
    ]


async def generate_topics(
    *, chunks: list[str], studio_id: str, api_key: str, model: str
) -> list[dict]:
    if not chunks:
        return []
    if not api_key:
        return _stub_topics(chunks, studio_id)

    context = "\n\n".join(chunks[:40])
    try:
        raw = await llm.generate(
            api_key=api_key,
            model=model,
            question=_SCHEMA_HINT,
            context=context,
        )
        text = raw.strip()
        # Strip ```json fences if present.
        if text.startswith("```"):
            text = text.split("```", 2)[1].removeprefix("json").strip()
        parsed = json.loads(text)
        topics = parsed if isinstance(parsed, list) else parsed.get("topics", [])
        shaped = [_shape_topic(t, studio_id) for t in topics if isinstance(t, dict)]
        return shaped or _stub_topics(chunks, studio_id)
    except Exception:  # noqa: BLE001 — any LLM/parse failure → offline stub
        return _stub_topics(chunks, studio_id)


async def persist_topics(
    cockpit: AsyncSession,
    *,
    studio_id: uuid.UUID,
    user_id: uuid.UUID,
    topics: list[dict],
) -> int:
    """Replace the studio's generated topics."""
    await cockpit.execute(
        delete(GeneratedTopic).where(GeneratedTopic.studio_id == studio_id)
    )
    for i, payload in enumerate(topics):
        cockpit.add(
            GeneratedTopic(
                studio_id=studio_id, user_id=user_id, ordinal=i, payload=payload
            )
        )
    await cockpit.commit()
    return len(topics)
