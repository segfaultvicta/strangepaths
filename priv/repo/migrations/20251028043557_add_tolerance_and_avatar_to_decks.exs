defmodule Strangepaths.Repo.Migrations.AddToleranceAndAvatarToDecks do
  use Ecto.Migration

  def change do
    alter table(:decks) do
      add(:tolerance, :integer, default: 15, null: false)
      add(:blockcap, :integer, default: 10, null: false)
      add(:avatar, :string, default: "", null: false)
    end
  end
end
