defmodule Strangepaths.Repo.Migrations.AddLastReadPostIdToSceneReadMarks do
  use Ecto.Migration

  def change do
    alter table(:scene_read_marks) do
      add :last_read_post_id, :bigint, null: true
    end
  end
end
