"""
Application configuration loaded from .env via Pydantic Settings.

Key design decisions:
  - Lowercase .env keys match the existing .env file format (user, password, host, etc.)
  - DATABASE_URL is constructed from components (handles special chars in password via quote_plus)
  - SUPABASE_SERVICE_ROLE_KEY is Optional — if absent, the Supabase user-creation flow is
    skipped and a warning is logged. This allows local dev without full Supabase setup.
  - All secrets must live in .env, never in source code or Git.
"""
from __future__ import annotations

from functools import lru_cache
from typing import Optional
from urllib.parse import quote_plus

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    # ── Database ──────────────────────────────────────────────────────────────
    # Allows direct DATABASE_URL=... in .env or separate components
    database_url_env: Optional[str] = Field(None, validation_alias="database_url")
    user: str = "postgres"
    password: str = ""
    host: str = "localhost"
    port: int = 5432
    dbname: str = "postgres"

    # ── Supabase ──────────────────────────────────────────────────────────────
    # Dashboard → Project Settings → API
    supabase_url: str = ""
    supabase_anon_key: str = ""
    # Modern secret key format: SUPABASE_SECRET_KEY=sb_secret_...
    supabase_secret_key: Optional[str] = None
    # Legacy service-role key: SUPABASE_SERVICE_ROLE_KEY=...
    supabase_service_role_key: Optional[str] = None
    # Optional shared secret if project uses legacy HS256 symmetric signing
    supabase_jwt_secret: str = ""

    # ── Application ───────────────────────────────────────────────────────────
    environment: str = "development"
    # Comma-separated CORS origins, e.g. "https://app.hapticsync.com,http://localhost"
    cors_origins: str = "*"

    # ── PIN Onboarding ────────────────────────────────────────────────────────
    pin_expiry_hours: int = 24
    pin_max_attempts: int = 5

    # ── Computed Properties ───────────────────────────────────────────────────

    @property
    def effective_supabase_url(self) -> str:
        """Returns configured supabase_url or infers from project ref in user setting."""
        if self.supabase_url:
            return self.supabase_url.rstrip("/")
        # Infer from pooler username (e.g. postgres.qjgyjlkrxxlcbobcjmdd)
        if "." in self.user:
            ref = self.user.split(".")[1].strip()
            if ref:
                return f"https://{ref}.supabase.co"
        return ""

    @property
    def jwks_url(self) -> str:
        """Supabase public JWKS endpoint for asymmetric JWT verification."""
        base = self.effective_supabase_url
        return f"{base}/auth/v1/.well-known/jwks.json" if base else ""

    @property
    def api_secret_key(self) -> Optional[str]:
        """Returns modern SUPABASE_SECRET_KEY or legacy SUPABASE_SERVICE_ROLE_KEY."""
        return self.supabase_secret_key or self.supabase_service_role_key

    @property
    def database_url(self) -> str:
        """
        SQLAlchemy connection string for Supabase PostgreSQL.
        Uses DATABASE_URL if present, otherwise constructs from components.
        """
        if self.database_url_env:
            return self.database_url_env

        encoded_pw = quote_plus(self.password)
        return (
            f"postgresql+psycopg2://{self.user}:{encoded_pw}"
            f"@{self.host}:{self.port}/{self.dbname}?sslmode=require"
        )

    @property
    def cors_origins_list(self) -> list[str]:
        if self.cors_origins == "*":
            return ["*"]
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]

    @property
    def is_development(self) -> bool:
        return self.environment == "development"

    @property
    def supabase_admin_api_url(self) -> str:
        """Base URL for Supabase Auth Admin API calls."""
        base = self.effective_supabase_url
        return f"{base}/auth/v1/admin"

    model_config = SettingsConfigDict(
        env_file=".env",
        case_sensitive=False,  # .env uses lowercase keys
        extra="ignore",         # Silently ignore unknown .env keys
    )


@lru_cache
def get_settings() -> Settings:
    """
    Returns the cached Settings singleton.
    Use this everywhere instead of constructing Settings() directly.
    The lru_cache ensures .env is only parsed once per process.
    """
    return Settings()
