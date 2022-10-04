defmodule Strangepaths.Cards.Card do
  use Ecto.Schema
  import Ecto.Changeset

  schema "cards" do
    field(:img, :string)
    field(:name, :string)
    field(:principle, Ecto.Enum, values: [:Dragon, :Stillness, :Song])
    field(:rules, :string)
    field(:type, Ecto.Enum, values: [:Rite, :Grace, :Status])
    field(:alt, :id)
    field(:glorified, :boolean)
    field(:aspect_id, :id)
    field(:glory_cost, :integer, virtual: true)

    many_to_many(:decks, Strangepaths.Cards.Deck, join_through: "cards_decks")

    timestamps()
  end

  @doc false
  def changeset(card, attrs) do
    card
    |> cast(attrs, [:name, :img, :rules, :principle, :type, :aspect_id, :alt, :glorified])
    |> validate_required([:name, :img, :rules, :principle, :type, :aspect_id])
  end
end
