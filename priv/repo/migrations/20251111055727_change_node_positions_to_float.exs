defmodule Strangepaths.Repo.Migrations.ChangeNodePositionsToInteger do
  use Ecto.Migration

  def change do
    alter table(:rumor_nodes) do
      modify :x, :integer
      modify :y, :integer
    end
  end
end
