defmodule Strangepaths.Repo.Migrations.CreateScenePosts do
  use Ecto.Migration

  def change do
    create table(:scene_posts) do
      add :scene_id, references(:scenes, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :nilify_all)
      add :avatar_id, references(:avatars, on_delete: :nilify_all)
      add :content, :text, null: false
      add :ooc_content, :text
      add :post_type, :string, null: false, default: "character"
      add :narrative_author_name, :string
      add :posted_at, :utc_datetime, null: false

      timestamps()
    end

    create index(:scene_posts, [:scene_id, :posted_at])
    create index(:scene_posts, [:scene_id])
    create index(:scene_posts, [:user_id])
  end
end
