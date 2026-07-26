"""Firebase ID-token verification — reuses Octopilot's Firebase project.

Flow: the Flutter client signs in with Firebase (project `octopilot-ai-7b29e`,
the same one octopilot uses), gets an ID token, and sends it as
`Authorization: Bearer <token>`. We verify it exactly the way octopilot's own
`auth.py` does — against Google's public signing keys, checking the RS256
signature, the `aud` (= project id) and the `iss` — so **no service-account JSON
is required** (octopilot doesn't have one either). Only the project id is needed.

When Firebase isn't configured (local dev), verification is disabled and the API
falls back to the `X-User-Id` dev header, so the whole stack still runs offline.

The token gives us the Firebase `uid` + email. Mapping that to the canonical
octopilot `users.id` (via `users.firebase_uid`) happens in `deps.py` when the
shared DB is wired; here we also expose a deterministic uuid5 fallback for when
it isn't.
"""

from __future__ import annotations

import uuid
from dataclasses import dataclass

import jwt
from jwt import PyJWKClient

from .config import get_settings

# Namespace for deriving a stable UUID from a Firebase uid (fallback only).
_FIREBASE_NS = uuid.uuid5(uuid.NAMESPACE_URL, "https://cockpit.octopilot.ai/firebase")

# Google's JWKS for Firebase secure tokens (JSON Web Key Set form).
_JWKS_URL = (
    "https://www.googleapis.com/service_accounts/v1/jwk/"
    "securetoken@system.gserviceaccount.com"
)

# PyJWKClient caches keys and refreshes on cache miss (new `kid`).
_jwk_client: PyJWKClient | None = None


@dataclass
class AuthedUser:
    user_id: uuid.UUID  # deterministic fallback; deps may replace with octopilot id
    firebase_uid: str | None = None
    email: str | None = None


def uid_to_user_id(firebase_uid: str) -> uuid.UUID:
    """Deterministic UUID for a Firebase uid (stable across sessions)."""
    return uuid.uuid5(_FIREBASE_NS, firebase_uid)


def _client() -> PyJWKClient:
    global _jwk_client
    if _jwk_client is None:
        # lifespan=... keeps keys cached; PyJWKClient re-fetches on unknown kid.
        _jwk_client = PyJWKClient(_JWKS_URL, cache_keys=True, lifespan=3600)
    return _jwk_client


def verify_bearer(token: str) -> AuthedUser | None:
    """Verify a Firebase ID token. Returns the user, or None if Firebase is off
    or the token is invalid/expired."""
    settings = get_settings()
    project_id = settings.firebase_project_id.strip()
    if not project_id:
        return None

    try:
        signing_key = _client().get_signing_key_from_jwt(token)
        payload = jwt.decode(
            token,
            signing_key.key,
            algorithms=["RS256"],
            audience=project_id,
            issuer=f"https://securetoken.google.com/{project_id}",
        )
    except Exception:  # noqa: BLE001 — any verification failure => unauthenticated
        return None

    fuid = payload.get("user_id") or payload.get("sub") or payload.get("uid")
    if not fuid:
        return None
    return AuthedUser(
        user_id=uid_to_user_id(fuid),
        firebase_uid=fuid,
        email=payload.get("email"),
    )
