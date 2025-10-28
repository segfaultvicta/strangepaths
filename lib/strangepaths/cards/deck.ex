defmodule Strangepaths.Cards.Deck do
  use Ecto.Schema
  import Ecto.Changeset

  schema "decks" do
    field(:name, :string)
    field(:aspect_id, :id)
    field(:glory, :integer)
    field(:tolerance, :integer)
    field(:blockcap, :integer)
    field(:avatar_id, :integer)
    field(:glory_used, :integer, virtual: true)
    field(:manabalance, :map)
    belongs_to(:user, Strangepaths.Accounts.User, foreign_key: :owner)

    has_one(:avatar, Strangepaths.Accounts.Avatar, foreign_key: :id, references: :avatar_id)

    many_to_many(:cards, Strangepaths.Cards.Card,
      join_through: "cards_decks",
      on_replace: :delete,
      on_delete: :delete_all
    )

    timestamps()
  end

  @doc false
  def new_changeset(deck, attrs) do
    deck
    |> cast(attrs, [:name, :aspect_id, :owner, :manabalance])
    |> validate_required([:name, :aspect_id, :owner, :manabalance])
    |> manabalance_validator()
  end

  def edit_changeset(deck, attrs) do
    deck
    |> cast(attrs, [:name, :glory, :manabalance])
  end

  def glory_changeset(deck, adjustment) do
    deck
    |> cast(%{"glory" => deck.glory + adjustment}, [:glory])
  end

  def tolerance_changeset(deck, adjustment) do
    deck
    |> cast(%{"tolerance" => deck.tolerance + adjustment}, [:tolerance])
  end

  def blockcap_changeset(deck, adjustment) do
    deck
    |> cast(%{"blockcap" => deck.blockcap + adjustment}, [:blockcap])
  end

  def cards_changeset(deck, cards) do
    deck
    |> change()
    |> put_assoc(:cards, cards)
  end

  defp manabalance_validator(changeset) do
    mana = get_field(changeset, :manabalance)

    balance = mana.red + mana.green + mana.blue + mana.white + mana.black

    if balance == 15 do
      changeset
    else
      if balance < 15 do
        add_error(changeset, :manabalance, "Mana Balance is too low!")
      else
        add_error(changeset, :manabalance, "Mana Balance is too high!")
      end
    end
  end
end
