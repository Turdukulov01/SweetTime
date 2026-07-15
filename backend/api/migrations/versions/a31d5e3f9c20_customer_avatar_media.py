"""customer avatar media

Revision ID: a31d5e3f9c20
Revises: 7c003983b74d
Create Date: 2026-07-15
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "a31d5e3f9c20"
down_revision: Union[str, None] = "7c003983b74d"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "media_files",
        sa.Column("id", sa.String(length=80), nullable=False),
        sa.Column("tenant_id", sa.String(length=64), nullable=False),
        sa.Column("entity_type", sa.String(length=50), nullable=False),
        sa.Column("entity_id", sa.String(length=64), nullable=False),
        sa.Column("storage_key", sa.Text(), nullable=False),
        sa.Column("original_filename", sa.Text(), nullable=True),
        sa.Column("mime_type", sa.String(length=100), nullable=False),
        sa.Column("size_bytes", sa.Integer(), nullable=False),
        sa.Column("width", sa.Integer(), nullable=False),
        sa.Column("height", sa.Integer(), nullable=False),
        sa.Column("variant", sa.String(length=50), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["tenant_id"], ["companies.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("storage_key", name="uq_media_file_storage_key"),
    )
    op.create_index(
        op.f("ix_media_files_tenant_id"), "media_files", ["tenant_id"], unique=False
    )
    op.create_index(
        op.f("ix_media_files_entity_type"),
        "media_files",
        ["entity_type"],
        unique=False,
    )
    op.create_index(
        op.f("ix_media_files_entity_id"), "media_files", ["entity_id"], unique=False
    )
    op.add_column(
        "customers", sa.Column("avatar_storage_key", sa.Text(), nullable=True)
    )


def downgrade() -> None:
    op.drop_column("customers", "avatar_storage_key")
    op.drop_index(op.f("ix_media_files_entity_id"), table_name="media_files")
    op.drop_index(op.f("ix_media_files_entity_type"), table_name="media_files")
    op.drop_index(op.f("ix_media_files_tenant_id"), table_name="media_files")
    op.drop_table("media_files")
