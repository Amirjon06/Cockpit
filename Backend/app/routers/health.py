"""Liveness / readiness."""

from __future__ import annotations

from fastapi import APIRouter
from sqlalchemy import text

from ..config import get_settings
from ..db import cockpit_engine, vector_engine

router = APIRouter(tags=["health"])


@router.get("/health")
async def health() -> dict:
    return {"status": "ok", "env": get_settings().app_env}


@router.get("/ready")
async def ready() -> dict:
    checks: dict[str, str] = {}
    for name, engine in (("cockpit", cockpit_engine), ("vector", vector_engine)):
        try:
            async with engine.connect() as conn:
                await conn.execute(text("SELECT 1"))
            checks[name] = "ok"
        except Exception as exc:  # noqa: BLE001
            checks[name] = f"error: {exc}"
    ok = all(v == "ok" for v in checks.values())
    return {"status": "ok" if ok else "degraded", "checks": checks}
