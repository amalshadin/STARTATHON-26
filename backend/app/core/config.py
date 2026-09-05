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

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    # ── Database ──────────────────────────────────────────────────────────────
    # Match the lowercase keys already in the project's .env file.
    user: str = "postgres"
    password: str = ""
    host: str = "localhost"
    port: int = 5432
    dbname: str = "postgres"

    # ── Supabase ──────────────────────────────────────────────────────────────
    # Dashboard → Project Settings → API
    supabase_url: str = ""
    supabase_anon_key: str = ""
    # ⚠️  Server-side ONLY. Never expose to Flutter. Never commit to Git.
    supabase_service_role_key: Optional[str] = None
    # Dashboard → Project Settings → API → JWT Secret (used to verify patient JWTs)
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
    def database_url(self) -> str:
        """
        SQLAlchemy connection string for Supabase PostgreSQL.
        Password is URL-encoded so special characters (^, @, etc.) don't break parsing.
        sslmode=require is mandatory for Supabase.
        """
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
        return f"{self.supabase_url}/auth/v1/admin"

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
