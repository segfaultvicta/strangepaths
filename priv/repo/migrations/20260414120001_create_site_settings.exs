defmodule Strangepaths.Repo.Migrations.CreateSiteSettings do
  use Ecto.Migration

  def up do
    create table(:site_settings) do
      add :bbs_enabled, :boolean, default: false, null: false
    end

    execute "INSERT INTO site_settings (bbs_enabled) VALUES (false)"
  end

  def down do
    drop table(:site_settings)
  end
end
