defmodule Strangepaths.Repo.Migrations.CreateBbsThreads do
  use Ecto.Migration

  def change do
    create table(:bbs_threads) do
      add :board_id, references(:bbs_boards, on_delete: :delete_all), null: false
      add :user_id, references(:users), null: false
      add :title, :string, null: false
      add :is_pinned, :boolean, null: false, default: false
      add :is_locked, :boolean, null: false, default: false
      add :last_post_at, :utc_datetime, null: false
      add :post_count, :integer, null: false, default: 0

      timestamps()
    end

    create index(:bbs_threads, [:board_id, :is_pinned, :last_post_at])
  end
end
