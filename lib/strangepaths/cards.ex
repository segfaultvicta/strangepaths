defmodule Strangepaths.Cards do
  @moduledoc """
  The Cards context.
  """

  import Ecto.Query, warn: false
  alias Strangepaths.Repo

  alias Strangepaths.Cards.Card

  @doc """
  Returns the list of cards.

  ## Examples

      iex> list_cards()
      [%Card{}, ...]

  """
  def list_cards do
    Repo.all(Card)
  end

  def list_cards_for_cosmos(principle) do
    cards =
      Card
      |> where(principle: ^principle, glorified: false)
      |> order_by(:id)
      |> Repo.all()

    Enum.reduce(Repo.all(Strangepaths.Cards.Aspect), %{}, fn aspect, acc ->
      c = cards |> Enum.filter(fn e -> e.aspect_id == aspect.id end)

      if c |> Enum.count() > 0 do
        Map.put(acc, aspect.id, %{name: aspect.name, cards: c})
      else
        acc
      end
    end)
  end

  def list_cards_for_codex(principle) do
    cards =
      Card
      |> where(principle: ^principle)
      # Flurry should not show up in codex
      |> where([c], c.id != 187)
      |> order_by(:id)
      |> Repo.all()

    Enum.reduce(Repo.all(Strangepaths.Cards.Aspect), %{}, fn aspect, acc ->
      c = cards |> Enum.filter(fn e -> e.aspect_id == aspect.id end)

      if c |> Enum.count() > 0 do
        Map.put(acc, aspect.id, %{name: aspect.name, cards: c})
      else
        acc
      end
    end)
  end

  def list_aspects do
    Repo.all(Strangepaths.Cards.Aspect)
  end

  def list_aspects_for_form_permitting(aspects) do
    list_aspects()
    |> Enum.filter(fn a -> a.name in aspects end)
    |> Enum.map(fn a -> [key: a.name, value: a.id] end)
  end

  def name_aspect(id) do
    Repo.get(Strangepaths.Cards.Aspect, id).name
  end

  def get_aspect_id(name) do
    Repo.get_by!(Strangepaths.Cards.Aspect, name: name).id
  end

  @doc """
  Gets a single card.

  Raises `Ecto.NoResultsError` if the Card does not exist.

  ## Examples

      iex> get_card!(123)
      %Card{}

      iex> get_card!(456)
      ** (Ecto.NoResultsError)

  """
  def get_card!(id), do: Repo.get!(Card, id)

  @doc """
  Gets a card and, if it exists, its glorified alternate; will return nil for second element if no glorified alternate exists.
  """
  def get_card_and_alt(id) do
    card = get_card!(id)

    {card,
     if card.alt != nil do
       Repo.get(Card, card.alt)
     else
       nil
     end}
  end

  @doc """
  Creates a card and, potentially, its glorified double.

  ## Examples

      iex> create_card(%{field: value})
      {:ok, %Card{}}

      iex> create_card(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_card(%{
        name: name,
        principle: principle,
        type: type,
        aspect_id: aspect_id,
        rules: rules,
        glory_rules: glory_rules
      }) do
    {res, card} =
      %Card{}
      |> Card.changeset(%{
        name: name,
        principle: principle,
        type: type,
        aspect_id: aspect_id,
        rules: rules,
        img: image_from_name(name, false),
        glorified: false
      })
      |> Repo.insert()

    if res == :ok do
      original_id = card.id

      {gloryres, glorycard} =
        %Card{}
        |> Card.changeset(%{
          name: name,
          principle: principle,
          type: type,
          aspect_id: aspect_id,
          rules: glory_rules,
          img: image_from_name(name, true),
          alt: original_id,
          glorified: true
        })
        |> Repo.insert()

      if gloryres == :ok do
        glory_id = glorycard.id
        Strangepaths.Cards.update_card(card, %{alt: glory_id})
        {:ok, %{base: card, glory: glorycard}}
      else
        {:error, %{base: card, glory: glorycard}}
      end
    end

    # and get the Glory card's inserted ID, and update the original card to backreference its glorified version
  end

  # for cards with no glory version
  def create_card(%{
        name: name,
        principle: principle,
        type: type,
        aspect_id: aspect_id,
        rules: rules
      }) do
    %Card{}
    |> Card.changeset(%{
      name: name,
      img: image_from_name(name, false),
      principle: principle,
      type: type,
      aspect_id: aspect_id,
      rules: rules,
      alt: nil,
      glorified: false
    })
    |> Repo.insert()
  end

  def image_from_name(name, glory) do
    base =
      Slug.slugify(name, separator: " ")
      |> String.split()
      |> Enum.map(&String.capitalize/1)
      |> Enum.join(" ")

    IO.puts(base)

    if glory do
      "/images/" <> base <> " G.png"
    else
      "/images/" <>
        base <> ".png"
    end
  end

  @doc """
  Updates a card.

  ## Examples

      iex> update_card(card, %{field: new_value})
      {:ok, %Card{}}

      iex> update_card(card, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_card(%Card{} = card, attrs) do
    card
    |> Card.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a card. Need to name-search to delete both a card and its glorified form within a principle, if necessary.

  ## Examples

      iex> delete_card(card)
      {:ok, %Card{}}

      iex> delete_card(card)
      {:error, %Ecto.Changeset{}}

  """
  def delete_card(%Card{} = card) do
    from(c in Card, where: c.name == ^card.name and c.principle == ^card.principle)
    |> Repo.delete_all()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking card changes.

  ## Examples

      iex> change_card(card)
      %Ecto.Changeset{data: %Card{}}

  """
  def change_card(%Card{} = card, attrs \\ %{}) do
    Card.changeset(card, attrs)
  end

  alias Strangepaths.Cards.Deck

  @doc """
  Returns the list of decks.

  ## Examples

      iex> list_decks()
      [%Deck{}, ...]

  """
  def list_decks(user_id, sortcol \\ :name, direction \\ :asc) do
    if user_id == nil do
      query_all_decks(sortcol, direction)
    else
      query_decks(user_id, sortcol, direction)
    end
  end

  defp query_decks(user_id, sortcol, direction) do
    from(d in Deck,
      join: a in Strangepaths.Cards.Aspect,
      on: d.aspect_id == a.id,
      select: {%{deck: d, aspect: a.name}},
      where: d.owner == ^user_id,
      order_by: {^direction, ^sortcol}
    )
    |> Repo.all()
  end

  defp query_all_decks(sortcol, direction) do
    from(d in Deck,
      join: a in Strangepaths.Cards.Aspect,
      on: d.aspect_id == a.id,
      select: {%{deck: d, aspect: a.name}},
      order_by: {^direction, ^sortcol}
    )
    |> Repo.all()
  end

  @doc """
  Gets a single deck.

  Raises `Ecto.NoResultsError` if the Deck does not exist.

  ## Examples

      iex> get_deck!(123)
      %Deck{}

      iex> get_deck!(456)
      ** (Ecto.NoResultsError)

  """
  def get_deck!(id) do
    from(d in Deck,
      join: a in Strangepaths.Cards.Aspect,
      on: d.aspect_id == a.id,
      select: {%{deck: d, aspect: a.name}},
      where: d.id == ^id
    )
    |> Repo.all()
  end

  @doc """
  Creates a deck.

  ## Examples

      iex> create_deck(%{field: value})
      {:ok, %Deck{}}

      iex> create_deck(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_deck(attrs \\ %{}) do
    # preload the deck with the basic Grace and base 5 Rites for that deck's aspect
    cards = list_cards_for_codex(String.to_atom(attrs["principle"]))

    basecards =
      [Enum.at(rites(cards, String.to_integer(attrs["aspect_id"]), 1, :Grace), 0)] ++
        Enum.reject(rites(cards, String.to_integer(attrs["aspect_id"]), 10, :Rite), fn r ->
          r.glory_cost != 0
        end)

    %Deck{glory: 0, cards: basecards}
    |> Deck.new_changeset(attrs)
    |> Repo.insert()
  end

  def add_card_to_deck(deck, card) do
    card = get_card!(card)

    deck
    |> Deck.cards_changeset([card | deck.cards])
    |> Repo.update()
    |> update_glory_used
  end

  def remove_card_from_deck(deck, card_id) do
    deck
    |> Deck.cards_changeset(Enum.reject(deck.cards, fn c -> c.id == card_id end))
    |> Repo.update()
    |> update_glory_used
  end

  def update_glory_used({:ok, deck}) do
    deck
  end

  def adjust_glory(deck, adjustment) do
    adjustment =
      if deck.glory + adjustment < deck.glory_used do
        0
      else
        adjustment
      end

    deck
    |> Deck.glory_changeset(adjustment)
    |> Repo.update()
  end

  @doc """
  Deletes a deck.

  ## Examples

      iex> delete_deck(deck)
      {:ok, %Deck{}}

      iex> delete_deck(deck)
      {:error, %Ecto.Changeset{}}

  """
  def delete_deck(%Deck{} = deck) do
    Repo.delete(deck)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking deck changes.

  ## Examples

      iex> change_deck(deck)
      %Ecto.Changeset{data: %Deck{}}

  """
  def change_new_deck(%Deck{} = deck, attrs \\ %{}) do
    Deck.new_changeset(deck, attrs)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking deck changes.

  ## Examples

      iex> change_deck(deck)
      %Ecto.Changeset{data: %Deck{}}

  """
  def change_deck(%Deck{} = deck, attrs \\ %{}) do
    Deck.edit_changeset(deck, attrs)
  end

  def rites(cards, aspect_id, base_cards_in_aspect, type) do
    rites = Enum.filter(cards[aspect_id].cards, fn c -> c.type == type end)

    Enum.reduce(rites, %{rites: [], i: 1}, fn rite, %{rites: acc, i: i} ->
      %{
        rites: [
          %Card{
            rite
            | glory_cost:
                if i in 1..base_cards_in_aspect do
                  0 +
                    if rite.glorified do
                      1
                    else
                      0
                    end
                else
                  1 +
                    if rite.glorified do
                      1
                    else
                      0
                    end
                end
          }
          | acc
        ],
        i: i + 1
      }
    end).rites
    |> Enum.reverse()
  end
end
