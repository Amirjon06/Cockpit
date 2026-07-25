"""Firebase ID-token verification — reuses Octopilot's Firebase project.

Flow: the Flutter client signs in with Firebase (same project as Octopilot),
gets an ID token, and sends it as `Authorization: Bearer <token>`. Here we
verify it with the Firebase Admin SDK (initialized from the service-account JSON
copied from Octopilot) and derive a stable `user_id`.

When Firebase isn't configured (local dev), verification is disabled and the API
falls back to the `X-User-Id` dev header — so the whole stack still runs offline.

user_id mapping: Firebase `uid` (a string) → a deterministic UUID via uuid5, so
it fits the UUID columns. The refinement, once wired, is to resolve the real
octopilot `users.id` by matching the token's email/uid against the shared DB
(see resolve_user_id note); documents/studios then bind to that canonical id.
"""

from __future__ import annotations

import uuid
from dataclasses import dataclass

from .config import get_settings

# Namespace for deriving a stable UUID from a Firebase uid.
_FIREBASE_NS = uuid.uuid5(uuid.NAMESPACE_URL, "https://cockpit.octopilot.ai/firebase")

_initialized = False


@dataclass
class AuthedUser:
    user_id: uuid.UUID
    firebase_uid: str | None = None
    email: str | None = None


def uid_to_user_id(firebase_uid: str) -> uuid.UUID:
    """Deterministic UUID for a Firebase uid (stable across sessions)."""
    return uuid.uuid5(_FIREBASE_NS, firebase_uid)


def _ensure_initialized() -> bool:
    """Initialize the Firebase Admin app once. Returns True if usable."""
    global _initialized
    settings = get_settings()
    if not settings.firebase_enabled:
        return False
    if _initialized:
        return True
    import firebase_admin
    from firebase_admin import credentials

    if settings.firebase_credentials.strip():
        cred = credentials.Certificate(settings.firebase_credentials.strip())
        firebase_admin.initialize_app(cred)
    else:
        firebase_admin.initialize_app()  # Application Default Credentials
    _initialized = True
    return True


def verify_bearer(token: str) -> AuthedUser | None:
    """Verify a Firebase ID token. Returns the user, or None if Firebase is off
    or the token is invalid."""
    if not _ensure_initialized():
        return None
    from firebase_admin import auth as fb_auth

    try:
        decoded = fb_auth.verify_id_token(token)
    except Exception:  # noqa: BLE001 — any verification failure => unauthenticated
        return None
    fuid = decoded.get("uid") or decoded.get("sub")
    if not fuid:
        return None
    return AuthedUser(
        user_id=uid_to_user_id(fuid),
        firebase_uid=fuid,
        email=decoded.get("email"),
    )
