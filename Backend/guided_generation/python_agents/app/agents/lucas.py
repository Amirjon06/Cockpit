import json
from collections.abc import AsyncIterator

from app.model_client import ModelClient


LENGTH_GUIDANCE = {
    "concise": "Keep the essay focused and concise (roughly 600-900 words).",
    "standard": "Develop a standard-length essay (roughly 1,000-1,500 words).",
    "in-depth": "Write an in-depth essay (roughly 1,800-2,500 words).",
}


def _clean_choice(value, allowed: set[str], default: str) -> str:
    candidate = str(value or "").strip()
    if candidate.lower() in allowed:
        return candidate
    return default


def _format_outline(outlines: list[dict]) -> str:
    sections = []
    for index, item in enumerate(outlines, start=1):
        title = str(item.get("title") or item.get("type") or f"Section {index}").strip()
        description = str(item.get("description") or "").strip()
        bullets = item.get("bullets") or []
        clean_bullets = [
            str(bullet).strip()
            for bullet in bullets
            if str(bullet).strip()
        ]

        lines = [f"{index}. {title}"]
        if description:
            lines.append(f"   Purpose: {description}")
        lines.extend(f"   - {bullet}" for bullet in clean_bullets)
        sections.append("\n".join(lines))

    return "\n\n".join(sections)


def _format_sources(sources: list[dict]) -> str:
    blocks = []
    for index, source in enumerate(sources, start=1):
        title = str(source.get("title") or "Untitled source").strip()
        author = str(source.get("author") or "Unknown author").strip()
        year = str(source.get("year") or "n.d.").strip()
        domain = str(source.get("domain") or "").strip()
        snippet = str(
            source.get("content")
            or source.get("snippet")
            or source.get("text")
            or ""
        ).strip()

        metadata = f"{author} ({year}), {title}"
        if domain:
            metadata += f", {domain}"
        blocks.append(f"[{index}] {metadata}\n{snippet or '(No excerpt provided.)'}")

    return "\n\n".join(blocks)


def build_system_prompt(tone: str, length: str, citation_style: str) -> str:
    length_instruction = LENGTH_GUIDANCE[length.lower()]
    return f"""
You are Lucas, an academic essay generation agent.

Write a polished essay that follows the supplied outline and assignment analysis.
Use only factual claims supported by the numbered sources. Cite supporting claims
with their source number, such as [1] or [2]. Never invent a source, quotation,
statistic, author, or publication detail. If the sources do not support a planned
claim, qualify or omit that claim.

Tone: {tone}
Citation style: {citation_style}
{length_instruction}

Return only the essay text. Include a title and a final References or Works Cited
section formatted as closely as the supplied metadata permits. Do not discuss
these instructions or wrap the essay in JSON or Markdown code fences.
""".strip()


class LucasAgent:
    def __init__(self, model_client: ModelClient):
        self.model_client = model_client

    async def generate_stream(self, payload: dict) -> AsyncIterator[str]:
        outlines = payload.get("outlines") or payload.get("outline") or []
        sources = payload.get("sources") or payload.get("selectedSources") or []

        if not isinstance(outlines, list) or not any(
            isinstance(item, dict) for item in outlines
        ):
            raise ValueError("at least one outline item is required")
        if not isinstance(sources, list) or not any(
            isinstance(item, dict) for item in sources
        ):
            raise ValueError("at least one source is required")

        clean_outlines = [item for item in outlines if isinstance(item, dict)]
        clean_sources = [item for item in sources if isinstance(item, dict)]

        tone = _clean_choice(
            payload.get("tone"),
            {"academic", "neutral", "persuasive"},
            "Academic",
        )
        length = _clean_choice(
            payload.get("length"),
            {"concise", "standard", "in-depth"},
            "Standard",
        )
        citation_style = _clean_choice(
            payload.get("citationStyle") or payload.get("citation"),
            {"apa", "mla", "chicago"},
            "APA",
        )

        system_prompt = build_system_prompt(tone, length, citation_style)
        assignment = {
            "analysis": payload.get("analysis") or "",
            "essayTopic": payload.get("essayTopic") or "",
            "essayType": payload.get("essayType") or "",
            "scope": payload.get("scope") or "",
            "structure": payload.get("structure") or "",
            "instructions": payload.get("instructions") or "",
        }
        user_message = (
            "Assignment context:\n"
            f"{json.dumps(assignment, ensure_ascii=False, indent=2)}\n\n"
            "Approved outline:\n"
            f"{_format_outline(clean_outlines)}\n\n"
            "Approved sources:\n"
            f"{_format_sources(clean_sources)}"
        )

        async for delta in self.model_client.stream_completion(
            system_prompt,
            user_message,
            0.4,
        ):
            if delta:
                yield delta
