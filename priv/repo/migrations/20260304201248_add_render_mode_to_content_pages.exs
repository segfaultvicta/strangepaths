defmodule Strangepaths.Repo.Migrations.AddRenderModeToContentPages do
  use Ecto.Migration

  def up do
    # Add render_mode column
    alter table(:content_pages) do
      add :render_mode, :string, null: false, default: "markdown"
    end

    # Drop existing body_stripped generated column and recreate with CASE logic
    execute("ALTER TABLE content_pages DROP COLUMN IF EXISTS body_stripped")

    execute("""
    ALTER TABLE content_pages
    ADD COLUMN body_stripped text
    GENERATED ALWAYS AS (
      CASE render_mode
        WHEN 'html' THEN
          REGEXP_REPLACE(
            COALESCE(body, ''),
            '<[^>]+>', '', 'g'
          )
        ELSE
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
      END
    ) STORED
    """)

    # Recreate the trigram index on body_stripped
    execute("""
    CREATE INDEX content_pages_body_stripped_trgm_idx
    ON content_pages USING GIN (body_stripped gin_trgm_ops)
    """)
  end

  def down do
    # Drop the new body_stripped and recreate the old one without CASE
    execute("DROP INDEX IF EXISTS content_pages_body_stripped_trgm_idx")
    execute("ALTER TABLE content_pages DROP COLUMN IF EXISTS body_stripped")

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

    execute("""
    CREATE INDEX content_pages_body_stripped_trgm_idx
    ON content_pages USING GIN (body_stripped gin_trgm_ops)
    """)

    alter table(:content_pages) do
      remove :render_mode
    end
  end
end
