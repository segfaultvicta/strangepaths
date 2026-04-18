defmodule Strangepaths.Repo.Migrations.AddPositionToBbsBoards do
  use Ecto.Migration

  def change do
    alter table(:bbs_boards) do
      add :position, :integer
    end

    # Set initial positions based on current name order
    execute(
      """
      UPDATE bbs_boards
      SET position = sub.row_num
      FROM (
        SELECT id, ROW_NUMBER() OVER (ORDER BY name ASC) AS row_num
        FROM bbs_boards
      ) sub
      WHERE bbs_boards.id = sub.id
      """,
      "SELECT 1"
    )

    create index(:bbs_boards, [:position])
  end
end
