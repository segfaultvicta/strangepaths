defmodule Strangepaths.Repo.Migrations.LayoutPreference do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:layout_preference, :string, default: "default", null: false)
    end
  end
end
