"""add_meal_type

Revision ID: b3e1f8a2d094
Revises: 4a7471a4841e
Create Date: 2026-05-31 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "b3e1f8a2d094"
down_revision: Union[str, None] = "f2c9d4e7b1a8"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "recipes",
        sa.Column("meal_type", sa.String(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("recipes", "meal_type")
