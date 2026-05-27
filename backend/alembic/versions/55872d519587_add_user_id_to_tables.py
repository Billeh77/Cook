"""add_user_id_to_tables

Revision ID: 55872d519587
Revises: 20aeae09ef25
Create Date: 2026-05-26 20:33:13.053738

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
import sqlmodel


# revision identifiers, used by Alembic.
revision: str = '55872d519587'
down_revision: Union[str, Sequence[str], None] = '20aeae09ef25'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

# Sentinel used to tag rows created before auth existed
_ANONYMOUS = "anonymous"


def upgrade() -> None:
    # Add nullable first so existing rows don't violate NOT NULL,
    # then backfill a sentinel value and tighten to NOT NULL.
    for table in ("recipes", "inventory_items", "grocery_list_items"):
        op.add_column(table, sa.Column("user_id", sqlmodel.sql.sqltypes.AutoString(), nullable=True))
        op.execute(f"UPDATE {table} SET user_id = '{_ANONYMOUS}' WHERE user_id IS NULL")
        op.alter_column(table, "user_id", nullable=False)
        op.create_index(op.f(f"ix_{table}_user_id"), table, ["user_id"], unique=False)


def downgrade() -> None:
    for table in ("recipes", "inventory_items", "grocery_list_items"):
        op.drop_index(op.f(f"ix_{table}_user_id"), table_name=table)
        op.drop_column(table, "user_id")
