"""Company logo and configurable application background.

Revision ID: b84c1a7e2d90
Revises: a62f1c9d4e30
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "b84c1a7e2d90"
down_revision: Union[str, None] = "a62f1c9d4e30"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


# Do not embed JSON containing ``:0.12`` or ``:null`` in ``sa.text`` here.
# SQLAlchemy treats those fragments as bind parameters and renders NULL into
# the DDL.  Building the document on the PostgreSQL side keeps the migration
# literal-free and produces valid JSON for every existing company row.
BACKGROUND_SERVER_DEFAULT = sa.text(
    "json_build_object("
    "'kind', 'plain', "
    "'preset', 'none', "
    "'lightBase', '#FFFAF0', "
    "'darkBase', '#161215', "
    "'patternOpacity', 0.12, "
    "'imageUrl', NULL, "
    "'thumbnailUrl', NULL"
    ")"
)


def upgrade() -> None:
    op.add_column("companies", sa.Column("logo_url", sa.Text(), nullable=True))
    op.add_column(
        "companies", sa.Column("logo_thumbnail_url", sa.Text(), nullable=True)
    )
    op.add_column(
        "companies",
        sa.Column(
            "background",
            sa.JSON(),
            nullable=False,
            server_default=BACKGROUND_SERVER_DEFAULT,
        ),
    )
    op.alter_column("companies", "background", server_default=None)


def downgrade() -> None:
    op.drop_column("companies", "background")
    op.drop_column("companies", "logo_thumbnail_url")
    op.drop_column("companies", "logo_url")
