"""add planned_meals and cooking_logs tables

Revision ID: f2c9d4e7b1a8
Revises: e5f3a2b1c8d4
Create Date: 2026-05-31
"""
from alembic import op
import sqlalchemy as sa

# revision identifiers
revision = 'f2c9d4e7b1a8'
down_revision = 'e5f3a2b1c8d4'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        'planned_meals',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('user_id', sa.String(), nullable=False),
        sa.Column('recipe_id', sa.UUID(), nullable=False),
        sa.Column('added_at', sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(['recipe_id'], ['recipes.id']),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_planned_meals_user_id', 'planned_meals', ['user_id'])

    op.create_table(
        'cooking_logs',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('user_id', sa.String(), nullable=False),
        sa.Column('recipe_id', sa.UUID(), nullable=False),
        sa.Column('dish_name', sa.String(), nullable=False),
        sa.Column('cooked_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('servings', sa.Integer(), nullable=False, server_default='1'),
        sa.ForeignKeyConstraint(['recipe_id'], ['recipes.id']),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_cooking_logs_user_id', 'cooking_logs', ['user_id'])


def downgrade():
    op.drop_index('ix_cooking_logs_user_id', table_name='cooking_logs')
    op.drop_table('cooking_logs')
    op.drop_index('ix_planned_meals_user_id', table_name='planned_meals')
    op.drop_table('planned_meals')
