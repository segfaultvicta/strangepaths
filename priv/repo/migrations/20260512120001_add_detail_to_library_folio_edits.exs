defmodule Strangepaths.Repo.Migrations.AddDetailToLibraryFolioEdits do
  use Ecto.Migration

  def change do
    alter table(:library_folio_edits) do
      add :detail, :text, null: true
    end
  end
end
