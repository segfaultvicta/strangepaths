defmodule Strangepaths.Repo.Migrations.AddImageFilenameToBbsBoards do
  use Ecto.Migration

  def change do
    alter table(:bbs_boards) do
      add :image_filename, :string
    end
  end
end
