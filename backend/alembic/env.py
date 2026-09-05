"""
Alembic migration environment.

Customizations vs the default alembic init:
  1. DATABASE_URL is loaded from our Pydantic Settings (reads .env automatically).
  2. All models are imported via `app.db.models` so autogenerate can detect all tables.
  3. target_metadata points to our Base.metadata.

To generate a new migration:
    alembic revision --autogenerate -m "describe_your_change"

To apply migrations:
    alembic upgrade head

To roll back one step:
    alembic downgrade -1

Run from the backend/ directory with the .venv activated:
    cd backend/
    .venv\\Scripts\\activate  (Windows)
    alembic upgrade head
"""
from logging.config import fileConfig

from sqlalchemy import create_engine, pool
from alembic import context

# Load our app configuration
from app.core.config import get_settings

# Import ALL models so Base.metadata is fully populated for autogenerate.
# This import triggers all model class definitions in the SQLAlchemy mapper registry.
import app.db.models  # noqa: F401
from app.db.base import Base

# Alembic Config object
config = context.config

# Load settings (do NOT use config.set_main_option for the DB URL:
# URL-encoded passwords contain '%' which conflicts with ConfigParser interpolation)
settings = get_settings()

# Set up logging from alembic.ini
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# This is the metadata that Alembic uses for autogenerate.
target_metadata = Base.metadata


def run_migrations_offline() -> None:
    """
    Run migrations in 'offline' mode.
    Generates SQL script without connecting to the database.
    """
    context.configure(
        url=settings.database_url,  # Use settings directly (avoids ConfigParser % issue)
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        compare_type=True,
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    """
    Run migrations in 'online' mode.
    Connects to the database and applies migrations directly.
    Engine is created directly from settings to avoid ConfigParser % interpolation issue
    with URL-encoded passwords.
    """
    connectable = create_engine(
        settings.database_url,
        poolclass=pool.NullPool,
    )
    with connectable.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
            compare_type=True,  # Detect column type changes
        )
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
