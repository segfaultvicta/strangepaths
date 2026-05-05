defmodule Strangepaths.Repo.Migrations.AddIsPrivateToLibraryFolios do
  use Ecto.Migration

  def change do
    alter table(:library_folios) do
      add :is_private, :boolean, default: false, null: false
    end
  end
end
