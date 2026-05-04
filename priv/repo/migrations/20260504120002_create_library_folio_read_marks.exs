defmodule Strangepaths.Repo.Migrations.CreateLibraryFolioReadMarks do
  use Ecto.Migration

  def change do
    create table(:library_folio_read_marks) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :folio_id, references(:library_folios, on_delete: :delete_all), null: false
      add :last_visited_at, :naive_datetime, null: false

      timestamps()
    end

    create unique_index(:library_folio_read_marks, [:user_id, :folio_id])
    create index(:library_folio_read_marks, [:folio_id])
  end
end
