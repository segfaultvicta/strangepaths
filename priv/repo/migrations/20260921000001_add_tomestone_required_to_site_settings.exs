defmodule Strangepaths.Repo.Migrations.AddTomestoneRequiredToSiteSettings do
  use Ecto.Migration

  def change do
    alter table(:site_settings) do
      add :tomestone_required, :boolean, default: false, null: false
    end
  end
end
