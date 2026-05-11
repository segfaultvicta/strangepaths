defmodule Strangepaths.Repo.Migrations.AddLastUpdatedByToLibraryFolios do
  use Ecto.Migration

  def change do
    alter table(:library_folios) do
      add :last_updated_by_id, references(:users, on_delete: :nilify_all), null: true
    end
  end
end
