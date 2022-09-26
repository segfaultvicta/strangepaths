defmodule Strangepaths.Repo.Migrations.CreateCardsDecks do
  use Ecto.Migration

  def change do
    create table(:cards_decks) do
      add(:card_id, references(:cards))
      add(:deck_id, references(:decks))
    end

    create(unique_index(:cards_decks, [:card_id, :deck_id]))
  end
end
