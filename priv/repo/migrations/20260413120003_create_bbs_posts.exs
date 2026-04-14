defmodule Strangepaths.Repo.Migrations.CreateBbsPosts do
  use Ecto.Migration

  def change do
    create table(:bbs_posts) do
      add :thread_id, references(:bbs_threads, on_delete: :delete_all), null: false
      add :user_id, references(:users), null: false
      add :display_name, :string, null: false
      add :character_name, :string, null: false
      add :content, :text, null: false
      add :posted_at, :utc_datetime, null: false
      add :edited_at, :utc_datetime
      add :edited_by_id, references(:users)

      timestamps()
    end

    create index(:bbs_posts, [:thread_id, :posted_at])
  end
end
