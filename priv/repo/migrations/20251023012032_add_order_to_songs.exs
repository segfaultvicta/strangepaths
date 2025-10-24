defmodule Strangepaths.Repo.Migrations.AddOrderToSongs do
  use Ecto.Migration

  def change do
    alter table(:songs) do
      add :order, :integer
    end

    # Set initial order values based on current id ordering per disc
    execute """
    UPDATE songs
    SET "order" = subquery.row_num
    FROM (
      SELECT id, ROW_NUMBER() OVER (PARTITION BY disc ORDER BY id) as row_num
      FROM songs
    ) AS subquery
    WHERE songs.id = subquery.id
    """
  end
end
