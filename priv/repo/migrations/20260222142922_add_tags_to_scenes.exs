defmodule Strangepaths.Repo.Migrations.AddTagsToScenes do
  use Ecto.Migration

  def change do
    alter table(:scenes) do
      add :tags, {:array, :string}, default: [], null: false
    end

    create index(:scenes, [:tags], using: :gin)
  end
end
