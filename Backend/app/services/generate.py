"""Turn a studio's RAG chunks into Study Objects (topics + flashcards + quizzes).

After ingestion, this reads the studio's chunks and asks the LLM (OpenRouter) to
extract a handful of topics, each with explanations, flashcards, and quiz
questions — the structured content the Flutter app renders. Output is TopicDTO-
shaped (camelCase) JSON so `get_studio` can embed it directly.

Without an LLM key it falls back to a deterministic stub (one topic from the
first chunks) so the pipeline still completes offline and in tests.
"""

from __future__ import annotations

import asyncio
import json
import uuid

from sqlalchemy import delete
from sqlalchemy.ext.asyncio import AsyncSession

from ..models.cockpit import GeneratedScenario, GeneratedTopic
from . import llm

# --- Pass 1: outline (one cheap call decides how many lessons) --------------
_OUTLINE_SYSTEM = (
    "You are a curriculum designer. From the study material, produce a lesson "
    "outline as strict JSON. Ground it ONLY in the material — never invent. "
    "Output JSON only: no markdown, no commentary."
)

_OUTLINE_HINT = """
List the lessons this material should be broken into — ONE per distinct concept
or section. Let the material decide the count (don't merge unrelated concepts,
don't cap it): a short note may be 2-3, a chapter 6-12, a full textbook 20+.
Cover the WHOLE material, ordered the way it should be studied.

Return ONLY JSON: an array of {"title": str, "scope": str} where scope is a
one-line note on exactly what that lesson should cover. No prose outside JSON.
""".strip()

# --- Pass 2: one rich call per lesson --------------------------------------
_DETAIL_SYSTEM = (
    "You are an expert tutor writing ONE in-depth study lesson. Use ONLY the "
    "provided material — never invent facts. Be thorough and concrete. Output a "
    "single JSON object only: no markdown, no commentary."
)


def _detail_hint(title: str, scope: str) -> str:
    return f"""
Write a rich, complete lesson on "{title}".
Focus: {scope}

Return ONLY a JSON object:
{{
  "title": "{title}",
  "definition": str,                 // 1-2 precise sentences
  "simpleExplanation": str,          // plain-language, "explain like I'm 10"
  "detailedExplanation": str,        // THOROUGH: multiple paragraphs, mechanisms, how/why it works
  "whyItMatters": str,               // 2-4 sentences on real-world relevance
  "examples": [str, ...],            // 2-4 concrete worked examples
  "commonMistakes": [str, ...],      // 2-4 pitfalls learners hit
  "memoryHooks": [str, ...],         // 1-3 mnemonics / analogies
  "flashcards": [{{"front": str, "back": str}}, ...],   // 6-10
  "quizQuestions": [{{"question": str, "choices": [str], "answer": str, "explanation": str}}, ...],  // 4-6
  "difficulty": 1-5, "importance": 1-5
}}
Base everything ONLY on the provided material.
""".strip()

# How much material to send to the outline pass (chars ~= tokens*4).
_CONTEXT_CHAR_BUDGET = 120_000
_OUTLINE_MAX_TOKENS = 3_000   # outline is small
_DETAIL_MAX_TOKENS = 4_000    # per-lesson rich content
_DETAIL_CONCURRENCY = 8       # parallel lesson calls
_DETAIL_TOP_K = 8            # chunks retrieved per lesson


def _parse_json(text: str):
    """Parse JSON from an LLM reply, tolerating code fences + trailing junk."""
    text = text.strip()
    if text.startswith("```"):
        text = text.split("```", 2)[1].removeprefix("json").strip()
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass
    # Salvage: trim to the outermost bracketed span.
    for open_c, close_c in (("[", "]"), ("{", "}")):
        start, end = text.find(open_c), text.rfind(close_c)
        if start != -1 and end > start:
            try:
                return json.loads(text[start : end + 1])
            except json.JSONDecodeError:
                # array truncated mid-object → close after the last object
                cut = text.rfind("}")
                if open_c == "[" and cut > start:
                    try:
                        return json.loads(text[start : cut + 1] + "]")
                    except json.JSONDecodeError:
                        continue
    return None


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
        "memoryHooks": raw.get("memoryHooks", []),
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


def _material(chunks: list[str]) -> str:
    """Join chunks up to the context budget (whole doc for typical uploads)."""
    out: list[str] = []
    used = 0
    for c in chunks:
        if used + len(c) > _CONTEXT_CHAR_BUDGET:
            break
        out.append(c)
        used += len(c)
    return "\n\n".join(out)


async def _generate_outline(
    *, material: str, api_key: str, model: str
) -> list[dict]:
    """Pass 1 — ask the model how many lessons and what each covers."""
    raw = await llm.generate(
        api_key=api_key,
        model=model,
        system=_OUTLINE_SYSTEM,
        question=_OUTLINE_HINT,
        context=material,
        max_tokens=_OUTLINE_MAX_TOKENS,
    )
    parsed = _parse_json(raw)
    items = parsed if isinstance(parsed, list) else (parsed or {}).get("lessons", [])
    out = []
    for it in items:
        if isinstance(it, dict) and it.get("title"):
            out.append({"title": str(it["title"]), "scope": str(it.get("scope", ""))})
    return out


async def _lesson_context(
    *,
    vector: AsyncSession | None,
    user_id: uuid.UUID | None,
    studio_id_uuid: uuid.UUID | None,
    title: str,
    scope: str,
    fallback: str,
) -> str:
    """Retrieve the chunks most relevant to a lesson (falls back to full material)."""
    if vector is None or user_id is None or studio_id_uuid is None:
        return fallback
    try:
        from .embeddings import get_embedder
        from .vectorstore import hybrid_search

        q = f"{title}. {scope}".strip()
        q_vec = get_embedder().embed([q])[0]
        hits = await hybrid_search(
            vector,
            user_id=user_id,
            studio_id=studio_id_uuid,
            query_text=q,
            query_embedding=q_vec,
            top_k=_DETAIL_TOP_K,
        )
        joined = "\n\n".join(h.content for h in hits)
        return joined or fallback
    except Exception:  # noqa: BLE001 — retrieval optional; use full material
        return fallback


async def generate_topics(
    *,
    chunks: list[str],
    studio_id: str,
    api_key: str,
    model: str,
    user_id: uuid.UUID | None = None,
    vector: AsyncSession | None = None,
) -> list[dict]:
    """Two-pass generation: outline (how many lessons) → one rich call per lesson.

    Each lesson gets its own LLM call grounded in the chunks retrieved for that
    lesson, so content is deep and focused instead of a thin single-call split.
    """
    if not chunks:
        return []
    if not api_key:
        return _stub_topics(chunks, studio_id)

    material = _material(chunks)
    try:
        outline = await _generate_outline(material=material, api_key=api_key, model=model)
    except Exception:  # noqa: BLE001
        outline = []
    if not outline:
        return _stub_topics(chunks, studio_id)

    sid_uuid: uuid.UUID | None
    try:
        sid_uuid = uuid.UUID(studio_id)
    except ValueError:
        sid_uuid = None

    sem = asyncio.Semaphore(_DETAIL_CONCURRENCY)

    async def _detail(item: dict) -> dict | None:
        async with sem:
            context = await _lesson_context(
                vector=vector,
                user_id=user_id,
                studio_id_uuid=sid_uuid,
                title=item["title"],
                scope=item["scope"],
                fallback=material,
            )
            try:
                raw = await llm.generate(
                    api_key=api_key,
                    model=model,
                    system=_DETAIL_SYSTEM,
                    question=_detail_hint(item["title"], item["scope"]),
                    context=context,
                    max_tokens=_DETAIL_MAX_TOKENS,
                )
            except Exception:  # noqa: BLE001
                return None
            obj = _parse_json(raw)
            if not isinstance(obj, dict):
                return None
            obj.setdefault("title", item["title"])
            return _shape_topic(obj, studio_id)

    results = await asyncio.gather(*[_detail(it) for it in outline])
    topics = [r for r in results if isinstance(r, dict)]
    return topics or _stub_topics(chunks, studio_id)


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


# ---------------------------------------------------------------------------
# Scenario Mode — application scenarios (reasoning, not recall)
# ---------------------------------------------------------------------------
_SCENARIO_SYSTEM = (
    "You are an instructional designer building APPLICATION scenarios that test "
    "reasoning, not recall — realistic situations the learner must diagnose. "
    "Ground everything ONLY in the material; never invent facts. Output strict "
    "JSON only: no markdown, no commentary."
)

_SCENARIO_HINT = """
From the material, create realistic application scenarios — situations where the
learner must REASON through a problem, not recall a fact. Make as many as the
material genuinely supports (typically 5-10), ordered easy → hard.

Return ONLY JSON: an array. Each scenario:
{
  "title": str,                    // short case name
  "difficulty": 1-5,
  "estimatedMinutes": int,
  "skills": [str],                 // 2-4 skills being tested
  "aiNote": str,                   // one line, e.g. "Multiple concepts may be required."
  "problem": str,                  // the situation, 2-4 short sentences
  "question": str,                 // what the learner must determine
  "clues": [{"label": str, "detail": str}],  // 3-5 things to investigate + what each reveals
  "options": [str, str, str, str], // 4 candidate first actions (only one is best)
  "correctIndex": 0,               // index (0-3) of the best first action
  "reasoning": str,                // WHY that action is right; rule out the others
  "outcomeLabel": str,             // short result, e.g. "Likely issue: Layer 3"
  "relatedTopics": [str]           // 2-3 related topic titles from the material
}
Base everything ONLY on the provided material. No prose outside the JSON.
""".strip()

_SCENARIO_MAX_TOKENS = 8_000


def _shape_scenario(raw: dict, studio_id: str) -> dict:
    """Normalize an LLM scenario into a full ScenarioDTO dict (camelCase)."""
    sid = f"scn_{uuid.uuid4().hex[:10]}"
    options = [
        {"id": f"opt_{i}", "label": str(o)}
        for i, o in enumerate(raw.get("options") or [])
        if str(o).strip()
    ]
    ci = raw.get("correctIndex", 0)
    ci = ci if isinstance(ci, int) and 0 <= ci < len(options) else 0
    correct_id = options[ci]["id"] if options else "opt_0"
    clues = [
        {
            "id": f"clue_{uuid.uuid4().hex[:6]}",
            "label": c.get("label", ""),
            "detail": c.get("detail", ""),
        }
        for c in (raw.get("clues") or [])
        if isinstance(c, dict) and c.get("label")
    ]
    return {
        "id": sid,
        "studioId": studio_id,
        "title": raw.get("title", "Scenario"),
        "difficulty": int(raw.get("difficulty", 3) or 3),
        "estimatedMinutes": int(raw.get("estimatedMinutes", 6) or 6),
        "skills": [str(s) for s in (raw.get("skills") or [])],
        "aiNote": raw.get("aiNote", ""),
        "problem": raw.get("problem", ""),
        "question": raw.get("question", ""),
        "clues": clues,
        "options": options,
        "correctOptionId": correct_id,
        "reasoning": raw.get("reasoning", ""),
        "outcomeLabel": raw.get("outcomeLabel", ""),
        "relatedTopics": [str(t) for t in (raw.get("relatedTopics") or [])],
    }


async def generate_scenarios(
    *, chunks: list[str], studio_id: str, api_key: str, model: str
) -> list[dict]:
    """One fast LLM call → a set of application scenarios (best-effort)."""
    if not chunks or not api_key:
        return []
    try:
        raw = await llm.generate(
            api_key=api_key,
            model=model,
            system=_SCENARIO_SYSTEM,
            question=_SCENARIO_HINT,
            context=_material(chunks),
            max_tokens=_SCENARIO_MAX_TOKENS,
        )
        parsed = _parse_json(raw)
        items = parsed if isinstance(parsed, list) else (parsed or {}).get("scenarios", [])
        return [
            _shape_scenario(s, studio_id)
            for s in items
            if isinstance(s, dict) and s.get("problem")
        ]
    except Exception:  # noqa: BLE001 — scenarios are optional; never fail ingest
        return []


async def persist_scenarios(
    cockpit: AsyncSession,
    *,
    studio_id: uuid.UUID,
    user_id: uuid.UUID,
    scenarios: list[dict],
) -> int:
    """Replace the studio's generated scenarios."""
    await cockpit.execute(
        delete(GeneratedScenario).where(GeneratedScenario.studio_id == studio_id)
    )
    for i, payload in enumerate(scenarios):
        cockpit.add(
            GeneratedScenario(
                studio_id=studio_id, user_id=user_id, ordinal=i, payload=payload
            )
        )
    await cockpit.commit()
    return len(scenarios)
