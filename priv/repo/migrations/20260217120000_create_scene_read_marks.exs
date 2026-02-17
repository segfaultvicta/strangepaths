defmodule Strangepaths.Repo.Migrations.CreateSceneReadMarks do
  use Ecto.Migration

  def change do
    create table(:scene_read_marks) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :scene_id, references(:scenes, on_delete: :delete_all), null: false
      add :last_read_at, :utc_datetime, null: false
    end

    create unique_index(:scene_read_marks, [:user_id, :scene_id])
  end
end
