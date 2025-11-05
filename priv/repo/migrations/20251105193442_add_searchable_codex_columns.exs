defmodule Strangepaths.Repo.Migrations.AddSearchableCodexColumns do
  use Ecto.Migration

  def up do
    # Add generated columns that automatically strip markdown from Codex content
    execute("""
    ALTER TABLE content_pages
    ADD COLUMN title_stripped text
    GENERATED ALWAYS AS (
      REGEXP_REPLACE(
        REGEXP_REPLACE(
          REGEXP_REPLACE(
            REGEXP_REPLACE(
              REGEXP_REPLACE(
                REGEXP_REPLACE(
                  REGEXP_REPLACE(
                    COALESCE(title, ''),
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
    ALTER TABLE content_pages
    ADD COLUMN body_stripped text
    GENERATED ALWAYS AS (
      REGEXP_REPLACE(
        REGEXP_REPLACE(
          REGEXP_REPLACE(
            REGEXP_REPLACE(
              REGEXP_REPLACE(
                REGEXP_REPLACE(
                  REGEXP_REPLACE(
                    COALESCE(body, ''),
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

    # Drop old GIN trigram indexes on raw content
    execute("DROP INDEX IF EXISTS content_pages_title_trgm_idx")
    execute("DROP INDEX IF EXISTS content_pages_body_trgm_idx")

    # Create new GIN trigram indexes on the stripped columns
    execute("""
    CREATE INDEX content_pages_title_stripped_trgm_idx
    ON content_pages USING GIN (title_stripped gin_trgm_ops)
    """)

    execute("""
    CREATE INDEX content_pages_body_stripped_trgm_idx
    ON content_pages USING GIN (body_stripped gin_trgm_ops)
    """)
  end

  def down do
    # Drop indexes on stripped columns
    execute("DROP INDEX IF EXISTS content_pages_body_stripped_trgm_idx")
    execute("DROP INDEX IF EXISTS content_pages_title_stripped_trgm_idx")

    # Recreate indexes on raw content
    execute("CREATE INDEX content_pages_title_trgm_idx ON content_pages USING GIN (title gin_trgm_ops)")
    execute("CREATE INDEX content_pages_body_trgm_idx ON content_pages USING GIN (body gin_trgm_ops)")

    # Drop columns
    execute("ALTER TABLE content_pages DROP COLUMN IF EXISTS body_stripped")
    execute("ALTER TABLE content_pages DROP COLUMN IF EXISTS title_stripped")
  end
end
