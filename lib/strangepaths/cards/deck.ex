defmodule Strangepaths.Cards.Deck do
  use Ecto.Schema
  import Ecto.Changeset

  schema "decks" do
    field(:name, :string)
    field(:principle, Ecto.Enum, values: [:Dragon, :Stillness, :Song])
    belongs_to(:user, Strangepaths.Accounts.User, foreign_key: :owner)

    many_to_many(:cards, Strangepaths.Cards.Card, join_through: "cards_decks", on_replace: :delete)

    timestamps()
  end

  @doc false
  def changeset(deck, attrs) do
    deck
    |> cast(attrs, [:name, :principle])
    |> validate_required([:name, :principle])
  end
end
