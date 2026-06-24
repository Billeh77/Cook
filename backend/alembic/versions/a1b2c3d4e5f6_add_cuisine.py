"""add cuisine to recipes

Revision ID: a1b2c3d4e5f6
Revises: f2c9d4e7b1a8
Create Date: 2026-06-23
"""
from alembic import op
import sqlalchemy as sa

revision = 'a1b2c3d4e5f6'
down_revision = 'f2c9d4e7b1a8'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column('recipes', sa.Column('cuisine', sa.String(), nullable=True))


def downgrade() -> None:
    op.drop_column('recipes', 'cuisine')
