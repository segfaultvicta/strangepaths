defmodule Strangepaths.Cards.Card do
  use Ecto.Schema
  import Ecto.Changeset

  schema "cards" do
    field(:img, :string)
    field(:name, :string)
    field(:rules, :string)
    field(:type, Ecto.Enum, values: [:Rite, :Grace, :Status])
    field(:alt, :id)
    field(:glorified, :boolean)
    field(:aspect_id, :id)
    field(:gnosis, :string)
    field(:glory_cost, :integer, virtual: true)
    field(:uuid, :string, virtual: true)

    many_to_many(:decks, Strangepaths.Cards.Deck,
      join_through: "cards_decks",
      on_delete: :nothing
    )

    timestamps()
  end

  @doc false
  def changeset(card, attrs) do
    card
    |> cast(attrs, [:name, :img, :rules, :type, :aspect_id, :alt, :glorified, :gnosis])
    |> validate_required([:name, :img, :rules, :type, :aspect_id])
  end
end
