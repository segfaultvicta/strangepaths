defmodule Strangepaths.Repo.Migrations.AddDepthToLibraryMarginalia do
  use Ecto.Migration

  def change do
    alter table(:library_marginalia) do
      add :depth, :integer, null: false, default: 0
    end
  end
end
