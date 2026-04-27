defmodule Strangepaths.Repo.Migrations.CreateLibraryFolioTags do
  use Ecto.Migration

  def change do
    create table(:library_folio_tags) do
      add(:folio_id, references(:library_folios, on_delete: :delete_all), null: false)
      add(:tag, :string, null: false)

      timestamps()
    end

    create(unique_index(:library_folio_tags, [:folio_id, :tag]))
    create(index(:library_folio_tags, [:tag]))
  end
end
