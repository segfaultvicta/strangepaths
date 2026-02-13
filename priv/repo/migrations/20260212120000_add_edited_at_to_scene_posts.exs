defmodule Strangepaths.Repo.Migrations.AddEditedAtToScenePosts do
  use Ecto.Migration

  def change do
    alter table(:scene_posts) do
      add :edited_at, :utc_datetime, null: true
    end
  end
end
