defmodule Strangepaths.Repo.Migrations.CreateBbsThreadReadMarks do
  use Ecto.Migration

  def change do
    create table(:bbs_thread_read_marks) do
      add(:user_id, references(:users, on_delete: :delete_all), null: false)
      add(:thread_id, references(:bbs_threads, on_delete: :delete_all), null: false)
      add(:last_read_post_id, :integer)
      add(:last_read_at, :utc_datetime, null: false)

      timestamps()
    end

    create(unique_index(:bbs_thread_read_marks, [:user_id, :thread_id]))
  end
end
