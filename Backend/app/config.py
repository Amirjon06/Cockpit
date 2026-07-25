"""Typed settings loaded from environment / `.env`."""

from __future__ import annotations

from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env", env_file_encoding="utf-8", extra="ignore"
    )

    # API
    app_env: str = "dev"
    api_host: str = "0.0.0.0"
    api_port: int = 8100
    cors_origins: str = "http://localhost:8765"

    # Databases
    cockpit_database_url: str = (
        "postgresql+asyncpg://cockpit:cockpit@cockpit-db:5432/cockpit"
    )
    vector_database_url: str = (
        "postgresql+asyncpg://vector:vector@cockpit-vectordb:5432/vector"
    )
    embedding_dim: int = 1024
    # Shared identity/credits DB (the native octopilot Postgres). Blank => off.
    shared_database_url: str = ""

    # Object storage
    object_store_endpoint: str = "http://cockpit-minio:9000"
    object_store_region: str = "us-east-1"
    object_store_bucket: str = "cockpit-rag"
    object_store_access_key: str = "minioadmin"
    object_store_secret_key: str = "minioadmin"
    object_store_force_path_style: bool = True

    # Embeddings
    embeddings_backend: str = "fallback"  # sentence-transformers | fallback
    embeddings_model: str = "BAAI/bge-m3"

    # Auth (Firebase — reuse Octopilot's Firebase project)
    # Path to the Firebase service-account JSON (copy from octopilot on the
    # server). Blank => Firebase verification off; the API falls back to the
    # X-User-Id dev header. Also honors GOOGLE_APPLICATION_CREDENTIALS (ADC).
    firebase_credentials: str = ""
    firebase_project_id: str = ""
    # Allow the X-User-Id dev header even when Firebase is on (turn off in prod).
    allow_dev_user_header: bool = True

    # LLM (OpenRouter)
    openrouter_api_key: str = ""
    openrouter_base_url: str = "https://openrouter.ai/api/v1"
    openrouter_model: str = "anthropic/claude-opus-4.6"

    # RAG
    rag_chunk_tokens: int = 512
    rag_chunk_overlap: int = 64
    rag_top_k: int = 8
    rag_context_k: int = 5

    @property
    def cors_origin_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]

    @property
    def shared_db_enabled(self) -> bool:
        return bool(self.shared_database_url.strip())

    @property
    def firebase_enabled(self) -> bool:
        import os

        return bool(
            self.firebase_credentials.strip()
            or os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")
        )


@lru_cache
def get_settings() -> Settings:
    return Settings()
