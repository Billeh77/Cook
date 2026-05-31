"""add_albums

Revision ID: e5f3a2b1c8d4
Revises: b3c8e1f24a91
Create Date: 2026-05-30 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = 'e5f3a2b1c8d4'
down_revision: Union[str, Sequence[str], None] = 'da16d2003e30'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'albums',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('user_id', sa.String(), nullable=False),
        sa.Column('name', sa.String(), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_albums_user_id', 'albums', ['user_id'])

    op.create_table(
        'album_recipes',
        sa.Column('album_id', sa.UUID(), nullable=False),
        sa.Column('recipe_id', sa.UUID(), nullable=False),
        sa.Column('added_at', sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(['album_id'], ['albums.id']),
        sa.ForeignKeyConstraint(['recipe_id'], ['recipes.id']),
        sa.PrimaryKeyConstraint('album_id', 'recipe_id'),
    )


def downgrade() -> None:
    op.drop_table('album_recipes')
    op.drop_index('ix_albums_user_id', table_name='albums')
    op.drop_table('albums')
