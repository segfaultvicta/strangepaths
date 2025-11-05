defmodule Strangepaths.Repo.Migrations.AddPgTrgmSearchIndexes do
  use Ecto.Migration

  def up do
    # Enable pg_trgm extension for fuzzy text search
    execute("CREATE EXTENSION IF NOT EXISTS pg_trgm")

    # Add GIN indexes for trigram search on scenes table
    execute("CREATE INDEX IF NOT EXISTS scenes_name_trgm_idx ON scenes USING GIN (name gin_trgm_ops)")

    # Add GIN indexes for trigram search on scene_posts table (content is IC, ooc_content is OOC)
    execute("CREATE INDEX IF NOT EXISTS scene_posts_content_trgm_idx ON scene_posts USING GIN (content gin_trgm_ops)")
    execute("CREATE INDEX IF NOT EXISTS scene_posts_ooc_content_trgm_idx ON scene_posts USING GIN (ooc_content gin_trgm_ops)")

    # Add GIN indexes for trigram search on content_pages table
    execute("CREATE INDEX IF NOT EXISTS content_pages_title_trgm_idx ON content_pages USING GIN (title gin_trgm_ops)")
    execute("CREATE INDEX IF NOT EXISTS content_pages_body_trgm_idx ON content_pages USING GIN (body gin_trgm_ops)")
  end

  def down do
    # Drop indexes
    execute("DROP INDEX IF EXISTS content_pages_body_trgm_idx")
    execute("DROP INDEX IF EXISTS content_pages_title_trgm_idx")
    execute("DROP INDEX IF EXISTS scene_posts_ooc_content_trgm_idx")
    execute("DROP INDEX IF EXISTS scene_posts_content_trgm_idx")
    execute("DROP INDEX IF EXISTS scenes_name_trgm_idx")

    # Drop pg_trgm extension
    execute("DROP EXTENSION IF EXISTS pg_trgm")
  end
end
