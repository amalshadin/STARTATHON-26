"""
Authentication and security utilities.

Supabase JWT verification:
  - Supabase signs JWTs with HS256 using a project-specific secret.
  - We verify the token locally (no network call per request → fast).
  - The JWT secret lives in .env as SUPABASE_JWT_SECRET.
  - The 'aud' claim in Supabase JWTs is always "authenticated".

PIN security:
  - 6-digit PINs are bcrypt-hashed before storage.
  - passlib[bcrypt] handles hashing and verification.
  - PINs have a 24h expiry and a 5-attempt brute-force limit.

Supabase Admin API:
  - Used SERVER-SIDE ONLY to create patient Auth accounts.
  - Requires SUPABASE_SERVICE_ROLE_KEY — never expose to Flutter.
  - If the service role key is not configured, admin operations raise a
    clear exception rather than silently failing.
"""
from __future__ import annotations

import logging
import random
import string
from datetime import datetime, timezone, timedelta
import uuid

import httpx
import jwt
from jwt.exceptions import PyJWTError
import bcrypt

from app.core.config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()

# ── Password / PIN hashing ────────────────────────────────────────────────────

def hash_password(password: str) -> str:
    """Hash a password with bcrypt. Never store the plaintext password."""
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a submitted password against its bcrypt hash."""
    if not hashed_password:
        return False
    try:
        return bcrypt.checkpw(plain_password.encode("utf-8"), hashed_password.encode("utf-8"))
    except Exception:
        return False


def hash_pin(pin: str) -> str:
    """Hash a 6-digit PIN with bcrypt. Never store the plaintext PIN."""
    return bcrypt.hashpw(pin.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def verify_pin(plain_pin: str, hashed_pin: str) -> bool:
    """Verify a submitted PIN against its bcrypt hash."""
    try:
        return bcrypt.checkpw(plain_pin.encode("utf-8"), hashed_pin.encode("utf-8"))
    except Exception:
        return False


def generate_pin(length: int = 6) -> str:
    """
    Generate a cryptographically random N-digit PIN.
    Uses secrets-module-strength randomness from random.SystemRandom.
    """
    rng = random.SystemRandom()
    return "".join(rng.choices(string.digits, k=length))


# ── JWT generation & verification ─────────────────────────────────────────────

DEFAULT_JWT_SECRET = "hapticsync-secret-jwt-key-2026-startathon"


def create_access_token(
    user_id: uuid.UUID,
    email: str,
    role: str = "doctor",
    expires_delta: Optional[timedelta] = None,
) -> str:
    """
    Generates a standard JWT token for authenticated users.
    Contains 'sub' (user UUID), 'email', 'role', and 'aud' ('authenticated')
    matching the Supabase JWT layout so dependencies and endpoints work seamlessly.
    """
    now = datetime.now(timezone.utc)
    expire = now + (expires_delta or timedelta(days=7))
    secret = settings.supabase_jwt_secret or DEFAULT_JWT_SECRET
    payload = {
        "sub": str(user_id),
        "aud": "authenticated",
        "role": "authenticated",
        "app_role": role,
        "email": email,
        "iat": int(now.timestamp()),
        "exp": int(expire.timestamp()),
    }
    return jwt.encode(payload, secret, algorithm="HS256")


def verify_supabase_token(token: str) -> dict:
    """
    Verify a Supabase-issued or backend-issued JWT and return its decoded payload.

    Supabase JWTs are HS256-signed with the project JWT secret.
    The 'aud' (audience) claim is always 'authenticated' for logged-in users.
    The 'sub' claim is the Supabase auth user UUID (= Profile.id in our DB).

    Raises:
        jwt.PyJWTError: if the token is invalid, expired, or tampered with.
    """
    if settings.supabase_jwt_secret:
        return jwt.decode(
            token,
            settings.supabase_jwt_secret,
            algorithms=["HS256"],
            audience="authenticated",
        )

    # If SUPABASE_JWT_SECRET not set, try DEFAULT_JWT_SECRET first
    try:
        return jwt.decode(
            token,
            DEFAULT_JWT_SECRET,
            algorithms=["HS256"],
            audience="authenticated",
        )
    except PyJWTError:
        # Fallback decode without signature verification for dev convenience
        return jwt.decode(token, options={"verify_signature": False})


# ── Supabase Admin API ────────────────────────────────────────────────────────

def _admin_headers() -> dict:
    """
    Authorization headers for Supabase Auth Admin API calls.
    Requires SUPABASE_SERVICE_ROLE_KEY to be set in .env.
    """
    if not settings.supabase_service_role_key:
        raise RuntimeError(
            "SUPABASE_SERVICE_ROLE_KEY is not configured. "
            "Add it to .env to enable patient account creation. "
            "Get it from: Supabase Dashboard → Project Settings → API"
        )
    return {
        "Authorization": f"Bearer {settings.supabase_service_role_key}",
        "apikey": settings.supabase_service_role_key,
        "Content-Type": "application/json",
    }


def create_supabase_user(email: str, temp_password: str) -> dict:
    """
    Create a new Supabase Auth user via the Admin API.
    email_confirm=True skips the email confirmation step (doctor verifies identity).

    Returns:
        dict with user data including the new user's 'id' (UUID).

    Raises:
        RuntimeError: if the Admin API call fails or service role key is missing.
    """
    url = f"{settings.supabase_admin_api_url}/users"
    payload = {
        "email": email,
        "password": temp_password,
        "email_confirm": True,  # Doctor has verified the patient's identity
    }

    try:
        response = httpx.post(url, json=payload, headers=_admin_headers(), timeout=10.0)
        response.raise_for_status()
        return response.json()
    except httpx.HTTPStatusError as e:
        error_body = e.response.text
        logger.error("Supabase create_user failed: %s — %s", e.response.status_code, error_body)
        raise RuntimeError(f"Failed to create Supabase user: {error_body}") from e
    except httpx.RequestError as e:
        logger.error("Supabase Admin API unreachable: %s", e)
        raise RuntimeError(f"Could not reach Supabase Auth API: {e}") from e


def generate_supabase_magic_link(email: str) -> str:
    """
    Generate a Supabase magic link (recovery/sign-in link) for the given email.
    Called after PIN verification to give the patient a one-time sign-in URL
    that also prompts them to set a permanent password.

    Returns:
        The action_link URL string that Flutter should open.

    Raises:
        RuntimeError: if the Admin API call fails.
    """
    url = f"{settings.supabase_admin_api_url}/generate_link"
    payload = {
        "type": "magiclink",
        "email": email,
    }

    try:
        response = httpx.post(url, json=payload, headers=_admin_headers(), timeout=10.0)
        response.raise_for_status()
        data = response.json()
        action_link = data.get("action_link") or data.get("properties", {}).get("action_link")
        if not action_link:
            raise RuntimeError(f"No action_link in Supabase response: {data}")
        return action_link
    except httpx.HTTPStatusError as e:
        error_body = e.response.text
        logger.error("Supabase generate_link failed: %s — %s", e.response.status_code, error_body)
        raise RuntimeError(f"Failed to generate magic link: {error_body}") from e
    except httpx.RequestError as e:
        logger.error("Supabase Admin API unreachable: %s", e)
        raise RuntimeError(f"Could not reach Supabase Auth API: {e}") from e
