defmodule Strangepaths.Repo.Migrations.RemoveLayoutPrefAndAddActionDefault do
  use Ecto.Migration

  def change do
    alter table(:users) do
      remove(:layout_preference)
      add(:action_default, :string, default: "action")
    end
  end
end
