defmodule Strangepaths.Repo.Migrations.CreateRumorConnections do
  use Ecto.Migration

  def change do
    create table(:rumor_connections) do
      add :label, :string
      add :line_style, :map, default: %{}
      add :from_node_id, references(:rumor_nodes, on_delete: :delete_all), null: false
      add :to_node_id, references(:rumor_nodes, on_delete: :delete_all), null: false
      add :created_by_id, references(:users, on_delete: :nilify_all)

      timestamps()
    end

    create index(:rumor_connections, [:from_node_id])
    create index(:rumor_connections, [:to_node_id])
    create index(:rumor_connections, [:created_by_id])
  end
end
