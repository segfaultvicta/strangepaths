defmodule Strangepaths.Repo.Migrations.AddWaypointsToRumorConnections do
  use Ecto.Migration

  def change do
    alter table(:rumor_connections) do
      add :waypoints, {:array, :map}, default: [], null: false
    end
  end
end
