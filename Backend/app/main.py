"""FastAPI application entrypoint."""

from __future__ import annotations

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from . import __version__
from .config import get_settings
from .routers import ask, documents, health, studios
from .services.objectstore import get_object_store

logger = logging.getLogger("cockpit")
logging.basicConfig(level=logging.INFO)


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings = get_settings()
    # Ensure the object-storage bucket exists (best-effort; storage may boot late).
    try:
        get_object_store().ensure_bucket()
    except Exception as exc:  # noqa: BLE001
        logger.warning("Object store not ready at startup: %s", exc)
    logger.info("Cockpit backend %s started (env=%s)", __version__, settings.app_env)
    yield


def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(
        title="Cockpit Backend",
        version=__version__,
        summary="Study Studio API + RAG",
        lifespan=lifespan,
    )
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origin_list,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    app.include_router(health.router)
    app.include_router(studios.router)
    app.include_router(documents.router)
    app.include_router(ask.router)
    return app


app = create_app()
