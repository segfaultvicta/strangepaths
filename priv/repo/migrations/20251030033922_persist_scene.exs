defmodule Strangepaths.Repo.Migrations.PersistScene do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:last_scene_id, :integer)
    end
  end
end
