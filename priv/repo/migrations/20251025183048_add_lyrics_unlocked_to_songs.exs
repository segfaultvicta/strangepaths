defmodule Strangepaths.Repo.Migrations.AddLyricsUnlockedToSongs do
  use Ecto.Migration

  def change do
    alter table(:songs) do
      add :lyrics_unlocked, :boolean, default: false, null: false
    end
  end
end
