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
    # obviously this should be filtering
    IO.inspect(principle)

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

  def list_aspects do
    Repo.all(Strangepaths.Cards.Aspect)
  end

  def name_aspect(id) do
    Repo.get(Strangepaths.Cards.Aspect, id).name
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

    # now, get the ID of the inserted card and use that as the alt for the Glory card
    IO.inspect(card)

    if res == :ok do
      original_id = card.id
      IO.inspect(original_id)

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
        IO.inspect(glory_id)
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
    IO.puts("in update_card")
    IO.inspect(card)
    IO.inspect(attrs)

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
  def list_decks do
    Repo.all(Deck)
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
  def get_deck!(id), do: Repo.get!(Deck, id)

  @doc """
  Creates a deck.

  ## Examples

      iex> create_deck(%{field: value})
      {:ok, %Deck{}}

      iex> create_deck(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_deck(attrs \\ %{}) do
    %Deck{}
    |> Deck.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a deck.

  ## Examples

      iex> update_deck(deck, %{field: new_value})
      {:ok, %Deck{}}

      iex> update_deck(deck, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_deck(%Deck{} = deck, attrs) do
    deck
    |> Deck.changeset(attrs)
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
  def change_deck(%Deck{} = deck, attrs \\ %{}) do
    Deck.changeset(deck, attrs)
  end
end
