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
from jwt import PyJWKClient
from jwt.exceptions import PyJWTError
import bcrypt

from app.core.config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()

_jwks_client: Optional[PyJWKClient] = None


def get_jwks_client() -> Optional[PyJWKClient]:
    """Returns singleton PyJWKClient pointing to Supabase JWKS endpoint."""
    global _jwks_client
    if _jwks_client is None and settings.jwks_url:
        try:
            _jwks_client = PyJWKClient(settings.jwks_url, cache_keys=True, max_cached_keys=16)
        except Exception as e:
            logger.warning("Failed to initialize JWKS client for %s: %s", settings.jwks_url, e)
    return _jwks_client


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

    Supports:
      1. Asymmetric keys (ES256, RS256, etc.) fetched dynamically via Supabase JWKS endpoint.
      2. Symmetric HS256 tokens signed with SUPABASE_JWT_SECRET or DEFAULT_JWT_SECRET.
      3. Development fallback for local environments if JWKS is temporarily unreachable.

    Raises:
        jwt.PyJWTError: if the token is invalid, expired, or tampered with.
    """
    if not token or not isinstance(token, str) or token.count(".") < 2:
        raise PyJWTError("Invalid token format: Not enough segments")

    # 1. Parse token header to inspect signing algorithm and key ID
    try:
        header = jwt.get_unverified_header(token)
        alg = header.get("alg", "HS256")
    except Exception as e:
        raise PyJWTError(f"Malformed JWT header: {e}") from e

    # 2. Asymmetric token verification (modern Supabase default: ES256 / RS256)
    if alg in ("ES256", "ES384", "ES512", "RS256", "RS384", "RS512", "EdDSA"):
        jwks = get_jwks_client()
        if jwks:
            try:
                signing_key = jwks.get_signing_key_from_jwt(token)
                return jwt.decode(
                    token,
                    signing_key.key,
                    algorithms=[signing_key.algorithm_name, alg],
                    audience="authenticated",
                )
            except Exception as e:
                logger.warning("JWKS verification error for %s token: %s", alg, e)
                if not settings.is_development:
                    raise PyJWTError(f"Token verification failed: {e}") from e

    # 3. Symmetric token verification (HS256)
    if alg == "HS256":
        # Check SUPABASE_JWT_SECRET if configured
        if settings.supabase_jwt_secret:
            try:
                return jwt.decode(
                    token,
                    settings.supabase_jwt_secret,
                    algorithms=["HS256"],
                    audience="authenticated",
                )
            except PyJWTError:
                pass

        # Check backend internal secret
        try:
            return jwt.decode(
                token,
                DEFAULT_JWT_SECRET,
                algorithms=["HS256"],
                audience="authenticated",
            )
        except PyJWTError:
            pass

    # 4. Development mode fallback (decodes payload without signature if keys unavailable)
    if settings.is_development:
        logger.warning(
            "JWT verification signature check bypassed in development mode for algorithm '%s'.",
            alg,
        )
        try:
            return jwt.decode(
                token,
                options={"verify_signature": False, "verify_aud": False},
            )
        except Exception as e:
            raise PyJWTError(f"Could not decode token payload: {e}") from e

    raise PyJWTError(f"Unsupported or unverifiable JWT algorithm: {alg}")


# ── Supabase Admin API ────────────────────────────────────────────────────────

def _admin_headers() -> dict:
    """
    Authorization headers for Supabase Auth Admin API calls.
    Supports modern SUPABASE_SECRET_KEY or legacy SUPABASE_SERVICE_ROLE_KEY.
    """
    key = settings.api_secret_key
    if not key:
        raise RuntimeError(
            "Neither SUPABASE_SECRET_KEY nor SUPABASE_SERVICE_ROLE_KEY is configured. "
            "Add it to .env to enable patient account creation. "
            "Get it from: Supabase Dashboard → Project Settings → API"
        )
    return {
        "Authorization": f"Bearer {key}",
        "apikey": key,
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
        if e.response.status_code == 422 and ("already" in error_body.lower() or "exists" in error_body.lower()):
            logger.info("User %s already exists in Supabase Auth, retrieving existing record...", email)
            try:
                list_res = httpx.get(url, headers=_admin_headers(), timeout=10.0)
                if list_res.is_success:
                    for u in list_res.json().get("users", []):
                        if u.get("email", "").lower() == email.lower():
                            return u
            except Exception:
                pass
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
