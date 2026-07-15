"""Content V2: stories, collections, feed posts and video metadata

Revision ID: e73c8f2a1b04
Revises: b91e7c4a2d10
Create Date: 2026-07-15
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "e73c8f2a1b04"
down_revision: Union[str, None] = "b91e7c4a2d10"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "story_collections",
        sa.Column("id", sa.String(length=64), nullable=False),
        sa.Column("company_id", sa.String(length=64), nullable=False),
        sa.Column("name", sa.JSON(), nullable=False),
        sa.Column("description", sa.JSON(), nullable=True),
        sa.Column("accent_color", sa.String(length=7), nullable=False),
        sa.Column("visual", sa.String(length=32), nullable=False),
        sa.Column("sort_order", sa.Integer(), nullable=False),
        sa.Column("is_published", sa.Boolean(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.ForeignKeyConstraint(["company_id"], ["companies.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_story_collections_company_id", "story_collections", ["company_id"]
    )
    op.create_index(
        "ix_story_collections_is_published", "story_collections", ["is_published"]
    )
    op.create_index(
        "ix_story_collections_sort_order", "story_collections", ["sort_order"]
    )
    op.create_index(
        "ix_story_collections_public_order",
        "story_collections",
        ["company_id", "is_published", "sort_order", "id"],
    )

    # Every legacy tenant receives one stable compatibility collection. Empty
    # KY/EN deliberately remain visible to admin as translation debt; public
    # V2 responses apply the documented RU fallback.
    op.execute(
        """
        INSERT INTO story_collections
          (id, company_id, name, description, accent_color, visual,
           sort_order, is_published, created_at, updated_at)
        SELECT LEFT('collection-' || md5(id), 64), id,
               '{"ru":"Новости","ky":"","en":""}'::json,
               NULL, accent_color, 'sparkle', 0, TRUE, NOW(), NOW()
        FROM companies
        """
    )

    op.create_table(
        "news_posts",
        sa.Column("id", sa.String(length=64), nullable=False),
        sa.Column("company_id", sa.String(length=64), nullable=False),
        sa.Column("title", sa.JSON(), nullable=False),
        sa.Column("summary", sa.JSON(), nullable=False),
        sa.Column("body", sa.JSON(), nullable=False),
        sa.Column("is_published", sa.Boolean(), nullable=False),
        sa.Column("published_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("media_type", sa.String(length=16), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.ForeignKeyConstraint(["company_id"], ["companies.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_news_posts_company_id", "news_posts", ["company_id"])
    op.create_index("ix_news_posts_is_published", "news_posts", ["is_published"])
    op.create_index("ix_news_posts_published_at", "news_posts", ["published_at"])
    op.create_index(
        "ix_news_posts_public_feed",
        "news_posts",
        ["company_id", "is_published", "published_at", "id"],
    )

    op.add_column("news", sa.Column("collection_id", sa.String(length=64), nullable=True))
    op.add_column(
        "news",
        sa.Column("show_on_home", sa.Boolean(), nullable=False, server_default=sa.true()),
    )
    op.add_column(
        "news",
        sa.Column("is_pinned", sa.Boolean(), nullable=False, server_default=sa.false()),
    )
    op.add_column(
        "news",
        sa.Column("media_type", sa.String(length=16), nullable=False, server_default="none"),
    )
    op.add_column(
        "news",
        sa.Column(
            "created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()
        ),
    )
    op.add_column(
        "news",
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()
        ),
    )
    op.alter_column(
        "news",
        "published_at",
        existing_type=sa.String(),
        type_=sa.DateTime(timezone=True),
        existing_nullable=False,
        postgresql_using="published_at::timestamptz",
    )
    op.alter_column(
        "news",
        "expires_at",
        existing_type=sa.String(),
        type_=sa.DateTime(timezone=True),
        existing_nullable=True,
        postgresql_using="NULLIF(expires_at, '')::timestamptz",
    )
    op.execute(
        """
        UPDATE news AS n
        SET collection_id = LEFT('collection-' || md5(n.company_id), 64),
            media_type = CASE WHEN image_url IS NULL OR image_url = ''
                              THEN 'none' ELSE 'image' END,
            created_at = n.published_at,
            updated_at = NOW()
        """
    )
    op.create_foreign_key(
        "news_collection_id_fkey",
        "news",
        "story_collections",
        ["collection_id"],
        ["id"],
        ondelete="SET NULL",
    )
    op.create_index("ix_news_collection_id", "news", ["collection_id"])
    op.create_index("ix_news_show_on_home", "news", ["show_on_home"])
    op.create_index("ix_news_is_pinned", "news", ["is_pinned"])
    op.create_index("ix_news_published_at", "news", ["published_at"])
    op.create_index(
        "ix_news_public_home",
        "news",
        ["company_id", "is_published", "show_on_home", "is_pinned", "published_at", "id"],
    )
    op.create_index(
        "ix_news_public_collection",
        "news",
        ["company_id", "collection_id", "is_published", "is_pinned", "published_at", "id"],
    )

    op.add_column("media_files", sa.Column("duration_ms", sa.Integer(), nullable=True))
    op.add_column(
        "media_files", sa.Column("checksum_sha256", sa.String(length=64), nullable=True)
    )
    op.create_unique_constraint(
        "uq_media_file_entity_variant",
        "media_files",
        ["tenant_id", "entity_type", "entity_id", "variant"],
    )
    op.create_index(
        "ix_media_files_tenant_entity",
        "media_files",
        ["tenant_id", "entity_type", "entity_id"],
    )


def downgrade() -> None:
    op.drop_index("ix_media_files_tenant_entity", table_name="media_files")
    op.drop_constraint(
        "uq_media_file_entity_variant", "media_files", type_="unique"
    )
    op.drop_column("media_files", "checksum_sha256")
    op.drop_column("media_files", "duration_ms")

    op.drop_index("ix_news_public_collection", table_name="news")
    op.drop_index("ix_news_public_home", table_name="news")
    op.drop_index("ix_news_published_at", table_name="news")
    op.drop_index("ix_news_is_pinned", table_name="news")
    op.drop_index("ix_news_show_on_home", table_name="news")
    op.drop_index("ix_news_collection_id", table_name="news")
    op.drop_constraint("news_collection_id_fkey", "news", type_="foreignkey")
    op.alter_column(
        "news",
        "expires_at",
        existing_type=sa.DateTime(timezone=True),
        type_=sa.String(),
        existing_nullable=True,
        postgresql_using="expires_at::text",
    )
    op.alter_column(
        "news",
        "published_at",
        existing_type=sa.DateTime(timezone=True),
        type_=sa.String(),
        existing_nullable=False,
        postgresql_using="published_at::text",
    )
    op.drop_column("news", "updated_at")
    op.drop_column("news", "created_at")
    op.drop_column("news", "media_type")
    op.drop_column("news", "is_pinned")
    op.drop_column("news", "show_on_home")
    op.drop_column("news", "collection_id")

    op.drop_index("ix_news_posts_public_feed", table_name="news_posts")
    op.drop_index("ix_news_posts_published_at", table_name="news_posts")
    op.drop_index("ix_news_posts_is_published", table_name="news_posts")
    op.drop_index("ix_news_posts_company_id", table_name="news_posts")
    op.drop_table("news_posts")

    op.drop_index("ix_story_collections_public_order", table_name="story_collections")
    op.drop_index("ix_story_collections_sort_order", table_name="story_collections")
    op.drop_index("ix_story_collections_is_published", table_name="story_collections")
    op.drop_index("ix_story_collections_company_id", table_name="story_collections")
    op.drop_table("story_collections")
