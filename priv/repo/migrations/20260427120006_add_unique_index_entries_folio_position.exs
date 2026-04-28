defmodule Strangepaths.Repo.Migrations.AddUniqueIndexEntriesFolioPosition do
  use Ecto.Migration

  def change do
    # Drop the existing non-unique index
    drop index(:library_entries, [:folio_id, :position])
    # Create a unique index to prevent duplicate positions within a folio
    create unique_index(:library_entries, [:folio_id, :position])
  end
end
