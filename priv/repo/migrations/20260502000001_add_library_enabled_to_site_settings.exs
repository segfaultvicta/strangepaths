defmodule Strangepaths.Repo.Migrations.AddLibraryEnabledToSiteSettings do
  use Ecto.Migration

  def change do
    alter table(:site_settings) do
      add :library_enabled, :boolean, default: false, null: false
    end
  end
end
