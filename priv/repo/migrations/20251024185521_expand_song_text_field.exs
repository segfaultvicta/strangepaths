defmodule Strangepaths.Repo.Migrations.ExpandSongTextField do
  use Ecto.Migration

  def change do
    alter table(:songs) do
      modify :text, :text
    end
  end
end
