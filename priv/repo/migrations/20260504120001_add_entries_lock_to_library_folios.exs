defmodule Strangepaths.Repo.Migrations.AddEntriesLockToLibraryFolios do
  use Ecto.Migration

  def change do
    alter table(:library_folios) do
      add :entries_locked_by_id, references(:users, on_delete: :nilify_all), null: true
      add :entries_locked_at, :utc_datetime, null: true
    end
  end
end
