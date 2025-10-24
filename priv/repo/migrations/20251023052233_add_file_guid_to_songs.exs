defmodule Strangepaths.Repo.Migrations.AddFileGuidToSongs do
  use Ecto.Migration

  def change do
    alter table(:songs) do
      add :file_guid, :string
    end

    create index(:songs, [:file_guid], unique: true)
  end
end
