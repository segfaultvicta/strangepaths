defmodule Strangepaths.Repo.Migrations.AddSlugToScenes do
  use Ecto.Migration

  def change do
    alter table(:scenes) do
      add :slug, :string
    end

    # Add unique constraint on name
    create unique_index(:scenes, [:name])

    # Add unique constraint on slug
    create unique_index(:scenes, [:slug])

    # Backfill slugs for existing scenes
    execute(
      """
      UPDATE scenes
      SET slug = lower(regexp_replace(name, '[^a-zA-Z0-9]+', '-', 'g'))
      WHERE slug IS NULL
      """,
      ""
    )

    # Make slug not null after backfilling
    alter table(:scenes) do
      modify :slug, :string, null: false
    end
  end
end
