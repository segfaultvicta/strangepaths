defmodule Strangepaths.Repo.Migrations.AddSearchableContentColumns do
  use Ecto.Migration

  def up do
    # Add generated columns that automatically strip markdown from content
    execute("""
    ALTER TABLE scene_posts
    ADD COLUMN content_stripped text
    GENERATED ALWAYS AS (
      REGEXP_REPLACE(
        REGEXP_REPLACE(
          REGEXP_REPLACE(
            REGEXP_REPLACE(
              REGEXP_REPLACE(
                REGEXP_REPLACE(
                  REGEXP_REPLACE(
                    COALESCE(content, ''),
                    '\\*\\*(.+?)\\*\\*', '\\1', 'g'
                  ),
                  '__(.+?)__', '\\1', 'g'
                ),
                '\\*([^*]+?)\\*', '\\1', 'g'
              ),
              '_([^_]+?)_', '\\1', 'g'
            ),
            '~~(.+?)~~', '\\1', 'g'
          ),
          '`+(.+?)`+', '\\1', 'g'
        ),
        '\\[(.+?)\\]\\(.+?\\)', '\\1', 'g'
      )
    ) STORED
    """)

    execute("""
    ALTER TABLE scene_posts
    ADD COLUMN ooc_content_stripped text
    GENERATED ALWAYS AS (
      REGEXP_REPLACE(
        REGEXP_REPLACE(
          REGEXP_REPLACE(
            REGEXP_REPLACE(
              REGEXP_REPLACE(
                REGEXP_REPLACE(
                  REGEXP_REPLACE(
                    COALESCE(ooc_content, ''),
                    '\\*\\*(.+?)\\*\\*', '\\1', 'g'
                  ),
                  '__(.+?)__', '\\1', 'g'
                ),
                '\\*([^*]+?)\\*', '\\1', 'g'
              ),
              '_([^_]+?)_', '\\1', 'g'
            ),
            '~~(.+?)~~', '\\1', 'g'
          ),
          '`+(.+?)`+', '\\1', 'g'
        ),
        '\\[(.+?)\\]\\(.+?\\)', '\\1', 'g'
      )
    ) STORED
    """)

    # Create GIN trigram indexes on the stripped columns
    execute("""
    CREATE INDEX scene_posts_content_stripped_trgm_idx
    ON scene_posts USING GIN (content_stripped gin_trgm_ops)
    """)

    execute("""
    CREATE INDEX scene_posts_ooc_content_stripped_trgm_idx
    ON scene_posts USING GIN (ooc_content_stripped gin_trgm_ops)
    """)
  end

  def down do
    # Drop indexes
    execute("DROP INDEX IF EXISTS scene_posts_ooc_content_stripped_trgm_idx")
    execute("DROP INDEX IF EXISTS scene_posts_content_stripped_trgm_idx")

    # Drop columns
    execute("ALTER TABLE scene_posts DROP COLUMN IF EXISTS ooc_content_stripped")
    execute("ALTER TABLE scene_posts DROP COLUMN IF EXISTS content_stripped")
  end
end
