"""
SQLAlchemy engine and session factory for HapticSync.

Design decisions:
  - Synchronous SQLAlchemy (not async) — simpler, sufficient for this project.
    Async can be added later with minimal schema changes if throughput demands it.
  - pool_pre_ping=True: Essential for Supabase which closes idle connections.
    Without this, the first request after an idle period would fail.
  - echo=True in development: logs all SQL statements for easy debugging.
  - get_db() is a FastAPI dependency generator used with Depends(get_db).
"""
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session

from app.core.config import get_settings

_settings = get_settings()

engine = create_engine(
    _settings.database_url,
    pool_pre_ping=True,    # Test connections before use (handles Supabase idle timeouts)
    pool_size=5,           # Persistent connections in the pool
    max_overflow=10,       # Extra connections allowed beyond pool_size under load
    echo=_settings.is_development,  # Log SQL in development (disable in production!)
)

SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine,
)


def get_db() -> Session:
    """
    FastAPI dependency. Yields a database session, ensures it is closed after
    each request regardless of success or failure.

    Usage in a route:
        @router.get("/example")
        def example(db: Session = Depends(get_db)):
            result = db.execute(select(SomeModel)).scalars().all()
            return result
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
