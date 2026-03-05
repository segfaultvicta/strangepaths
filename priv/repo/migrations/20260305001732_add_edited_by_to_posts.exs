defmodule Strangepaths.Repo.Migrations.AddEditedByToPosts do
  use Ecto.Migration

  def change do
    alter table(:scene_posts) do
      add :edited_by_id, references(:users, on_delete: :nilify_all)
    end
  end
end
