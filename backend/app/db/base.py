"""
SQLAlchemy declarative base shared by all models.
All model classes must inherit from Base so Alembic autogenerate
can detect them when imported in alembic/env.py.
"""
from sqlalchemy.orm import DeclarativeBase


class Base(DeclarativeBase):
    pass
