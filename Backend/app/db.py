"""Async SQLAlchemy engines + session factories.

Three logically separate databases (see README "Database strategy"):

* **cockpit**  — business data we own (studios, documents, ingest jobs).
* **vector**   — RAG chunks + embeddings (pgvector), isolated lifecycle.
* **shared**   — the existing native `octopilot` Postgres: users, credits,
                 api_keys, system_settings. Read-mostly, single source of truth.
                 Only wired when SHARED_DATABASE_URL is set.

Keeping them on separate engines means one connection pool per concern and no
accidental cross-database transactions — the split is explicit, not implied.
"""

from __future__ import annotations

from collections.abc import AsyncIterator

from pgvector.asyncpg import register_vector
from sqlalchemy import event
from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.orm import DeclarativeBase

from .config import get_settings

settings = get_settings()


class CockpitBase(DeclarativeBase):
    """Declarative base for the cockpit business database."""


class VectorBase(DeclarativeBase):
    """Declarative base for the vector database."""


class SharedBase(DeclarativeBase):
    """Declarative base mirroring tables owned by octopilot (read-mostly)."""


def _engine(url: str) -> AsyncEngine:
    return create_async_engine(url, pool_pre_ping=True, future=True)


cockpit_engine = _engine(settings.cockpit_database_url)
vector_engine = _engine(settings.vector_database_url)


async def _register_vector_codec(conn) -> None:
    """Teach asyncpg the pgvector `vector` type so Python lists bind directly.
    Without this, asyncpg has no codec for `vector` and rejects list params.
    Guarded: on a brand-new DB the extension may not exist yet (e.g. during
    `init_databases`, before CREATE EXTENSION) — skip then; real connections in
    the API process come after init, when the type exists."""
    try:
        await register_vector(conn)
    except Exception:  # noqa: BLE001 - extension not present yet; ignore
        pass


@event.listens_for(vector_engine.sync_engine, "connect")
def _on_vector_connect(dbapi_connection, _record) -> None:  # noqa: ANN001
    dbapi_connection.run_async(_register_vector_codec)
shared_engine: AsyncEngine | None = (
    _engine(settings.shared_database_url) if settings.shared_db_enabled else None
)

CockpitSession = async_sessionmaker(cockpit_engine, expire_on_commit=False)
VectorSession = async_sessionmaker(vector_engine, expire_on_commit=False)
SharedSession = (
    async_sessionmaker(shared_engine, expire_on_commit=False)
    if shared_engine is not None
    else None
)


async def get_cockpit_session() -> AsyncIterator[AsyncSession]:
    async with CockpitSession() as session:
        yield session


async def get_vector_session() -> AsyncIterator[AsyncSession]:
    async with VectorSession() as session:
        yield session


async def get_shared_session() -> AsyncIterator[AsyncSession | None]:
    """Yields a shared-DB session, or None when the shared DB is not configured."""
    if SharedSession is None:
        yield None
        return
    async with SharedSession() as session:
        yield session
