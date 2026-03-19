defmodule Strangepaths.Repo.Migrations.CreateWorldState do
  use Ecto.Migration

  def up do
    create table(:world_state) do
      add :devour_count, :integer, default: 0, null: false
    end

    execute "INSERT INTO world_state (devour_count) VALUES (0)"
  end

  def down do
    drop table(:world_state)
  end
end
