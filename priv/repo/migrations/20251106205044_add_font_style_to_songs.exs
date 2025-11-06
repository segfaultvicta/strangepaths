defmodule Strangepaths.Repo.Migrations.AddFontStyleToSongs do
  use Ecto.Migration

  def change do
    alter table(:songs) do
      add :font_style, :string, default: "default", null: false
    end
  end
end
