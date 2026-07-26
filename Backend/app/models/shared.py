"""Read-mostly mirrors of tables owned by the octopilot service.

These are declared ONLY so Cockpit can read identity, credits config, and the
OpenRouter key from the single source of truth. Cockpit does NOT run migrations
against this database and must not treat these definitions as authoritative — the
octopilot service owns the schema. Columns here are the minimum we read; unknown
columns are simply not mapped.

Credits: `octo_credits` is octopilot's Octocredits balance column (confirmed
against the live schema — the same field the app's Octocredits pill shows).
"""

from __future__ import annotations

import uuid

from sqlalchemy import Integer, String, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from ..db import SharedBase


class User(SharedBase):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True)
    # Firebase uid -> canonical octopilot user (unique, indexed in octopilot).
    firebase_uid: Mapped[str | None] = mapped_column(String(128), nullable=True)
    email: Mapped[str | None] = mapped_column(String(320), nullable=True)
    # Octocredits balance (the pill). octopilot also has word/source/humanizer.
    octo_credits: Mapped[int | None] = mapped_column(Integer, nullable=True)


class ApiKey(SharedBase):
    __tablename__ = "api_keys"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    provider: Mapped[str] = mapped_column(String(64), index=True)
    key: Mapped[str] = mapped_column(Text)


class SystemSetting(SharedBase):
    __tablename__ = "system_settings"

    key: Mapped[str] = mapped_column(String(128), primary_key=True)
    value: Mapped[str | None] = mapped_column(Text, nullable=True)
