"""Credit checks against the shared octopilot DB.

⚠️ IMPORTANT — verify before enabling enforcement.
The exact credit/ledger model in octopilot was not confirmed (candidates seen in
the schema: `purchase_history`, `promo_redemptions`, `referral_redemptions`, and
possibly a balance column on `users`). This service is written defensively:

* When the shared DB is off (dev), it is a no-op that always allows.
* When on, `check` reads a best-effort balance and `debit` is intentionally a
  NO-OP with a TODO — we do NOT mutate real financial tables until the Lead
  confirms the correct ledger table and debit semantics.

Wiring the real debit is a deliberate, reviewed step — not something to guess.
"""

from __future__ import annotations

import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..models.shared import User


class CreditsService:
    def __init__(self, shared: AsyncSession | None) -> None:
        self._shared = shared

    @property
    def enabled(self) -> bool:
        return self._shared is not None

    async def balance(self, user_id: uuid.UUID) -> int | None:
        if self._shared is None:
            return None
        row = await self._shared.execute(select(User.credits).where(User.id == user_id))
        return row.scalar_one_or_none()

    async def check(self, user_id: uuid.UUID, cost: int = 1) -> bool:
        """True if the user may proceed. Fails open in dev (shared DB off)."""
        if self._shared is None:
            return True
        bal = await self.balance(user_id)
        return bal is None or bal >= cost

    async def debit(self, user_id: uuid.UUID, cost: int = 1) -> None:
        """TODO(lead): implement against the confirmed octopilot ledger table.
        Left as a no-op so this service never mutates real financial data by
        guessing the schema."""
        return None
