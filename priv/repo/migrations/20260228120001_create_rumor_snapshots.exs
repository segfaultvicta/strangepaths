defmodule Strangepaths.Repo.Migrations.CreateRumorSnapshots do
  use Ecto.Migration

  def change do
    create table(:rumor_snapshots) do
      add :label, :string
      add :taken_by_id, references(:users, on_delete: :nilify_all)
      add :nodes_data, :map, null: false
      add :connections_data, :map, null: false

      timestamps()
    end

    create index(:rumor_snapshots, [:taken_by_id])
    create index(:rumor_snapshots, [:inserted_at])
  end
end
