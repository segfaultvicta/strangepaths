defmodule Strangepaths.Repo.Migrations.CreateLibraryFolioEdits do
  use Ecto.Migration

  def change do
    create table(:library_folio_edits) do
      add :folio_id, references(:library_folios, on_delete: :delete_all), null: false
      add :editor_id, references(:users, on_delete: :nothing), null: false
      add :kind, :string, null: false
      add :summary, :text
      add :inserted_at, :naive_datetime, null: false
    end

    create index(:library_folio_edits, [:inserted_at], comment: "activity feed ordering")
    create index(:library_folio_edits, [:folio_id])
  end
end
