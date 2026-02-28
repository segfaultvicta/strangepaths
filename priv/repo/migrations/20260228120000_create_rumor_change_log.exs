defmodule Strangepaths.Repo.Migrations.CreateRumorChangeLog do
  use Ecto.Migration

  def change do
    create table(:rumor_change_log) do
      add :action, :string, null: false
      add :actor_id, references(:users, on_delete: :nilify_all)
      add :node_id, :integer
      add :connection_id, :integer
      add :node_title, :string
      add :details, :map, default: %{}

      timestamps(updated_at: false)
    end

    create index(:rumor_change_log, [:actor_id])
    create index(:rumor_change_log, [:action])
    create index(:rumor_change_log, [:inserted_at])
  end
end
