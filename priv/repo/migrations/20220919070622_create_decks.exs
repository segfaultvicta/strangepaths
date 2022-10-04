defmodule Strangepaths.Repo.Migrations.CreateDecks do
  use Ecto.Migration

  def change do
    create table(:decks) do
      add(:name, :string, null: false)
      add(:principle, :string, null: false)
      add(:aspect_id, references(:aspect, on_delete: :nothing), null: false)
      add(:glory, :integer)
      add(:manabalance, :map)
      add(:owner, references(:users, on_delete: :delete_all), null: false)

      timestamps()
    end

    create(index(:decks, [:owner]))
    create(index(:decks, [:aspect_id]))
  end
end
