defmodule Strangepaths.Repo.Migrations.CreateScenes do
  use Ecto.Migration

  def change do
    create table(:scenes) do
      add :name, :string, null: false
      add :owner_id, references(:users, on_delete: :restrict), null: false
      add :status, :string, null: false, default: "active"
      add :locked_to_users, {:array, :integer}, default: []
      add :is_elsewhere, :boolean, default: false, null: false
      add :archived_at, :utc_datetime

      timestamps()
    end

    create index(:scenes, [:owner_id])
    create index(:scenes, [:status])
    create index(:scenes, [:is_elsewhere])
    create unique_index(:scenes, [:is_elsewhere], where: "is_elsewhere = true", name: :only_one_elsewhere)
  end
end
