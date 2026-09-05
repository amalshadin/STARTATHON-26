"""add_doctor_license_trigger

Revision ID: a1fab574f741
Revises: 6db42d6dfe5a
Create Date: 2026-09-05 21:52:44.456311

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'a1fab574f741'
down_revision: Union[str, Sequence[str], None] = '6db42d6dfe5a'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Creates sequence and trigger to auto-generate doctor license number (e.g. DOC-001001)."""
    # 1. Create sequence for sequential license IDs
    op.execute("CREATE SEQUENCE IF NOT EXISTS doctor_license_seq START WITH 1001;")

    # 2. Create trigger function
    op.execute("""
        CREATE OR REPLACE FUNCTION set_doctor_license_number()
        RETURNS TRIGGER AS $$
        BEGIN
            IF NEW.license_number IS NULL OR TRIM(NEW.license_number) = '' THEN
                NEW.license_number := 'DOC-' || LPAD(nextval('doctor_license_seq')::TEXT, 6, '0');
            END IF;
            RETURN NEW;
        END;
        $$ LANGUAGE plpgsql;
    """)

    # 3. Create trigger on doctors table
    op.execute("""
        DROP TRIGGER IF EXISTS trigger_set_doctor_license_number ON doctors;
        CREATE TRIGGER trigger_set_doctor_license_number
        BEFORE INSERT ON doctors
        FOR EACH ROW
        EXECUTE FUNCTION set_doctor_license_number();
    """)


def downgrade() -> None:
    """Removes trigger, function, and sequence."""
    op.execute("DROP TRIGGER IF EXISTS trigger_set_doctor_license_number ON doctors;")
    op.execute("DROP FUNCTION IF EXISTS set_doctor_license_number();")
    op.execute("DROP SEQUENCE IF EXISTS doctor_license_seq;")
