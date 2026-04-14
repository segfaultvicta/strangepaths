defmodule Strangepaths.Repo.Migrations.CreateBbsBoards do
  use Ecto.Migration

  def change do
    create table(:bbs_boards) do
      add(:name, :string, null: false)
      add(:slug, :string, null: false)
      add(:description, :text)

      timestamps()
    end

    create(unique_index(:bbs_boards, [:slug]))
  end
end
