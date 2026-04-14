defmodule Strangepaths.Repo.Migrations.CreateBbsUserThreadStickies do
  use Ecto.Migration

  def change do
    create table(:bbs_user_thread_stickies) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :thread_id, references(:bbs_threads, on_delete: :delete_all), null: false

      timestamps(updated_at: false)
    end

    create unique_index(:bbs_user_thread_stickies, [:user_id, :thread_id])
  end
end
