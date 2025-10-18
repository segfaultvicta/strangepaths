defmodule Strangepaths.Repo.Migrations.CreateSongs do
  use Ecto.Migration

  def change do
    create table(:songs) do
      add(:title, :string)
      add(:text, :string)
      add(:link, :string)
      add(:disc, :integer)
      add(:unlocked, :boolean, default: false, null: false)

      timestamps()
    end
  end
end
