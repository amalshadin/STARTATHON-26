"""add_hashed_password_to_profiles

Revision ID: 8f727054bd70
Revises: a1fab574f741
Create Date: 2026-09-05 22:12:00.343357

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '8f727054bd70'
down_revision: Union[str, Sequence[str], None] = 'a1fab574f741'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Add hashed_password column to profiles table."""
    op.add_column('profiles', sa.Column('hashed_password', sa.String(length=255), nullable=True))


def downgrade() -> None:
    """Remove hashed_password column from profiles table."""
    op.drop_column('profiles', 'hashed_password')
