"""LLM generation via OpenRouter (OpenAI-compatible chat completions).

Key + model resolution order (prod reuses what octopilot already has):
  1. If the shared DB is configured, read the OpenRouter key from `api_keys`
     (provider='openrouter') and the model from `system_settings.primary_model`.
  2. Otherwise fall back to OPENROUTER_API_KEY / OPENROUTER_MODEL from env.

Citations are prompt-driven: chunks are numbered [1..n] and the model is asked to
cite those numbers. We do not rely on any provider-native citation feature.
"""

from __future__ import annotations

import httpx
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from tenacity import retry, stop_after_attempt, wait_exponential

from ..config import get_settings
from ..models.shared import ApiKey, SystemSetting

SYSTEM_PROMPT = (
    "You are the Study Studio tutor. Answer ONLY from the provided context. "
    "Cite the sources you use with bracketed numbers like [1], [2] that match "
    "the context blocks. If the context does not contain the answer, say you "
    "don't have enough material on that topic yet — do not invent facts."
)


async def resolve_credentials(shared: AsyncSession | None) -> tuple[str, str]:
    """Return (api_key, model). Reads from shared DB when available."""
    settings = get_settings()
    api_key = settings.openrouter_api_key
    model = settings.openrouter_model

    if shared is not None:
        row = await shared.execute(
            select(ApiKey.key).where(ApiKey.provider == "openrouter").limit(1)
        )
        found = row.scalar_one_or_none()
        if found:
            api_key = found
        setting = await shared.execute(
            select(SystemSetting.value).where(SystemSetting.key == "primary_model")
        )
        model_val = setting.scalar_one_or_none()
        if model_val:
            model = model_val

    return api_key, model


def build_context_block(chunks: list[str]) -> str:
    return "\n\n".join(f"[{i + 1}] {c}" for i, c in enumerate(chunks))


@retry(stop=stop_after_attempt(3), wait=wait_exponential(min=1, max=8))
async def generate(*, api_key: str, model: str, question: str, context: str) -> str:
    settings = get_settings()
    if not api_key:
        raise RuntimeError(
            "No OpenRouter API key. Set OPENROUTER_API_KEY or configure "
            "SHARED_DATABASE_URL so the key can be read from api_keys."
        )
    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {
                "role": "user",
                "content": f"Context:\n{context}\n\nQuestion: {question}",
            },
        ],
        "temperature": 0.2,
    }
    async with httpx.AsyncClient(timeout=60) as client:
        resp = await client.post(
            f"{settings.openrouter_base_url}/chat/completions",
            headers={
                "Authorization": f"Bearer {api_key}",
                "HTTP-Referer": "https://cockpit.octopilot.ai",
                "X-Title": "Cockpit Study Studio",
            },
            json=payload,
        )
        resp.raise_for_status()
        data = resp.json()
    return data["choices"][0]["message"]["content"]
