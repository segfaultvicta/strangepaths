defmodule Strangepaths.Repo.Migrations.AddRumorLayers do
  use Ecto.Migration

  def up do
    create table(:rumor_layers) do
      add :name, :string, null: false
      add :sort_order, :integer, default: 0
      add :created_by_id, references(:users, on_delete: :nilify_all)

      timestamps()
    end

    create index(:rumor_layers, [:sort_order, :name])

    # Seed a "Default" layer
    execute """
    INSERT INTO rumor_layers (name, sort_order, inserted_at, updated_at)
    VALUES ('Default', 0, NOW(), NOW())
    """

    # Add layer_id to rumor_nodes
    alter table(:rumor_nodes) do
      add :layer_id, references(:rumor_layers, on_delete: :nilify_all)
    end

    create index(:rumor_nodes, [:layer_id])

    # Backfill all existing nodes to the Default layer
    execute """
    UPDATE rumor_nodes SET layer_id = (SELECT id FROM rumor_layers WHERE name = 'Default' LIMIT 1)
    """
  end

  def down do
    alter table(:rumor_nodes) do
      remove :layer_id
    end

    drop table(:rumor_layers)
  end
end
