"""Create the Cockpit + vector schemas from SQLAlchemy metadata.

    python -m scripts.init_databases

Idempotent bootstrap for dev and first deploy:
  * cockpit DB — studios / documents / ingest_jobs
  * vector DB  — enables the `vector` extension, then creates chunks + indexes

This does NOT touch the shared octopilot database — Cockpit never migrates that.
Move to Alembic when the schema starts to evolve in production.
"""

from __future__ import annotations

import asyncio

from sqlalchemy import text

from app.db import CockpitBase, VectorBase, cockpit_engine, vector_engine

# Import model modules so their tables register on the metadata.
from app.models import cockpit as _cockpit  # noqa: F401
from app.models import vector as _vector  # noqa: F401


async def main() -> None:
    async with cockpit_engine.begin() as conn:
        await conn.run_sync(CockpitBase.metadata.create_all)
    print("cockpit DB ready")

    async with vector_engine.begin() as conn:
        await conn.execute(text("CREATE EXTENSION IF NOT EXISTS vector"))
        await conn.run_sync(VectorBase.metadata.create_all)
    print("vector DB ready (pgvector enabled)")


if __name__ == "__main__":
    asyncio.run(main())
