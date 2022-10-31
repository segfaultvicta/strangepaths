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

  def get_card_by_gnosis(gnosis) do
    card = Repo.get_by(Strangepaths.Cards.Card, gnosis: gnosis)

    if card == nil do
      {:no_card, nil}
    else
      {:ok, card.id}
    end
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

  # for cards created via the webform (alethic rites)
  def create_card(%{
        "name" => name,
        "img" => img,
        "principle" => principle,
        "type" => type,
        "rules" => rules,
        "gnosis" => gnosis_plaintext
      }) do
    %Card{}
    |> Card.changeset(%{
      name: name,
      img: img,
      principle: principle,
      type: type,
      aspect_id: Strangepaths.Cards.get_aspect_id("Alethic"),
      rules: rules,
      alt: nil,
      glorified: false,
      gnosis: :crypto.hash(:md5, gnosis_plaintext) |> Base.encode16() |> String.downcase()
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

  def select_decks_for_ceremony(user_id, ceremony) do
    decks =
      list_decks(user_id)
      |> Enum.map(fn {d} -> d.deck end)
      |> Enum.filter(fn d -> d.principle == ceremony.principle end)
      |> Enum.map(fn d -> {d.name, d.id} end)

    decks ++
      case ceremony.principle do
        :Dragon ->
          [
            {"⭒Lithos⭒", 99990},
            {"🟔Lithos🟔", 99991},
            {"⭒Orichalca⭒", 99992},
            {"🟔Orichalca🟔", 99993},
            {"⭒Papyrus⭒", 99994},
            {"🟔Papyrus🟔", 99995},
            {"⭒Vitriol⭒", 99996},
            {"🟔Vitriol🟔", 99997},
            {"⭒Lutum⭒", 99998},
            {"🟔Lutum🟔", 99999}
          ]

        _ ->
          []
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

  def get_deck(id) do
    Repo.get(Deck, id)
  end

  def get_full_deck(id) do
    Repo.get(Deck, id) |> Repo.preload(:cards)
  end

  def deck_exists?(id) do
    Repo.exists?(from(d in Deck, where: d.id == ^id))
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

  def deckmana(deck_id) do
    IO.puts(deck_id)

    if(deck_id == nil) do
      []
    else
      (get_deck!(deck_id) |> Enum.at(0) |> Tuple.to_list() |> Enum.at(0)).deck.manabalance
      |> Enum.reduce("", fn {color, num}, a ->
        char =
          case color do
            "black" -> "B"
            "blue" -> "U"
            "red" -> "R"
            "green" -> "G"
            "white" -> "W"
            _ -> "*"
          end

        a <> String.duplicate(char, num)
      end)
      |> String.codepoints()
    end
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

  defmodule Entity do
    defstruct name: "",
              uuid: nil,
              x: 0,
              y: 0,
              img: "",
              deckID: nil,
              cards: %{draw: [], discard: [], hand: [], graces: []},
              tolerance: 10,
              stress: 7,
              defence: 0,
              # todo
              deckmana: nil,
              rulestext: "",
              type: nil,
              card_id: nil,
              glorified: false,
              gnosis: false,
              owner_id: 0

    def to_string(self) do
      self.uuid <> ":" <> self.name
    end

    def create(:Avatar, name, deckID, tolerance, avatarID, owner) do
      deckID =
        if Strangepaths.Cards.deck_exists?(deckID) do
          deckID
        else
          nil
        end

      %Entity{
        name: name,
        uuid: Ecto.UUID.generate(),
        x: 0,
        y: 0,
        img: Strangepaths.Accounts.get_avatar!(avatarID).filepath,
        tolerance: String.to_integer(tolerance),
        stress: 0,
        defence: 0,
        deckID: deckID,
        deckmana: Strangepaths.Cards.deckmana(deckID),
        type: :Avatar,
        owner_id: owner.id
      }
    end

    def create(:Card, card, owner) do
      %Entity{
        name: card.name,
        uuid: Ecto.UUID.generate(),
        x: 0,
        y: 0,
        img: card.img,
        rulestext: card.rules,
        type: :Card,
        card_id: card.id,
        glorified: card.glorified,
        gnosis: card.gnosis,
        owner_id: owner.id
      }
    end

    def create(:Radial, x, y) do
      %Entity{type: :Radial, x: x, y: y}
    end

    def create(:Counter, img, owner) do
      %Entity{
        name: "counter",
        uuid: Ecto.UUID.generate(),
        x: 0,
        y: 0,
        img: img,
        type: :Counter,
        owner_id: owner.id
      }
    end

    def create() do
      raise("Unknown entity type created.")
    end

    @spec screen_x(any, nil | maybe_improper_list | map) :: number
    def screen_x(_e, nil) do
      0
    end

    def screen_x(e, context) do
      e.x * 0.01 * context["width"] + context["left"] - screenWidth(e.type) / 2
    end

    def screen_y(_e, nil) do
      0
    end

    def screen_y(e, context) do
      e.y * 0.01 * context["height"] + context["top"] - screenHeight(e.type) / 2
    end

    def screenWidth(type) do
      case type do
        :Avatar -> 120
        :Card -> 200
        :Counter -> 40
        :Radial -> 400
        _ -> 1
      end
    end

    def screenHeight(type) do
      case type do
        :Avatar -> 120
        :Card -> 300
        :Counter -> 40
        :Radial -> 400
        _ -> 1
      end
    end
  end

  defmodule Ceremony do
    use Agent

    defstruct id: nil,
              name: "",
              principle: nil,
              owner_id: nil,
              owner_name: "",
              entities: [],
              gm_avatars_visible: true

    def to_string(self) do
      self.id <> ":" <> self.name
    end

    def start_link(_) do
      Agent.start_link(fn -> %{} end, name: __MODULE__)
    end

    def create(name, principle, owner_id) do
      owner_name = Strangepaths.Accounts.get_user!(owner_id).nickname
      truename = truename(name, principle, owner_id)

      ceremony = %Ceremony{
        id: truename,
        name: name,
        principle: String.to_atom(principle),
        owner_id: owner_id,
        owner_name: owner_name,
        entities: []
      }

      if !ceremony_exists?(truename) do
        Agent.update(__MODULE__, fn state -> Map.put(state, truename, ceremony) end)
        {:ok, ceremony}
      else
        {:error, "Ceremony with that name, principle, and creator already exists."}
      end
    end

    def placeEntity(truename, entity) do
      {ok, ceremony} = get(truename)

      entity =
        if !Enum.find(ceremony.entities, fn e -> e.uuid == entity.uuid end) &&
             entity.type == :Avatar &&
             entity.deckID != nil do
          # if placing a completely new avatar, handle things differently
          IO.puts(
            "placing a totally new non-fiend avatar, do deck lookup and populate cards accordingly"
          )

          deck = Strangepaths.Cards.get_full_deck(entity.deckID).cards
          graces = deck |> Enum.filter(fn c -> c.type == :Grace end)

          rites =
            deck
            |> Enum.filter(fn c -> c.type == :Rite end)
            |> Enum.map(fn c -> %Card{c | uuid: Ecto.UUID.generate()} end)
            |> _shuffle()

          {hand, rites} = Enum.split(rites, 4)

          %Entity{entity | cards: %{entity.cards | hand: hand, graces: graces, draw: rites}}
        else
          entity
        end

      # if entity already exists, remove it from the list of entities (handles moves)
      entities = ceremony.entities |> Enum.reject(fn e -> e.uuid == entity.uuid end)

      if ok == :ok do
        {:ok, save(truename, %Ceremony{ceremony | entities: [entity | entities]})}
      else
        {:error, ceremony}
      end
    end

    def removeEntity(truename, entity) do
      {ok, ceremony} = get(truename)
      ceremony.entities |> Enum.each(fn e -> IO.puts("#{e.name}: #{e.uuid}") end)
      entities = ceremony.entities |> Enum.reject(fn e -> e.uuid == entity.uuid end)

      if ok == :ok do
        {:ok, save(truename, %Ceremony{ceremony | entities: entities})}
      else
        {:error, ceremony}
      end
    end

    def get_entity(truename, uuid) do
      {ok, ceremony} = get(truename)

      if ok == :ok do
        Enum.find(ceremony.entities, fn e -> e.uuid == uuid end)
      else
        {:error, ceremony}
      end
    end

    def avatars(truename) do
      {_ok, ceremony} = get(truename)
      ceremony.entities |> Enum.filter(fn e -> e.type == :Avatar end)
    end

    def avatars(truename, uid) do
      avatars(truename) |> Enum.filter(fn a -> a.owner_id == uid end)
    end

    def add_card_to_entity_hand(truename, entity, card_id, n \\ 1) do
      card = Strangepaths.Cards.get_card!(card_id)

      hand =
        if n == 1 do
          [%Card{card | uuid: Ecto.UUID.generate()} | entity.cards.hand]
        else
          (List.duplicate(card, n)
           |> Enum.map(fn c -> %Card{c | uuid: Ecto.UUID.generate()} end)) ++ entity.cards.hand
        end

      entity = %Entity{entity | cards: %{entity.cards | hand: hand}}
      placeEntity(truename, entity)
    end

    def draw(truename, entity) do
      entity =
        if Enum.count(entity.cards.draw) == 0 do
          %{entity | cards: %{entity.cards | draw: _shuffle(entity.cards.discard), discard: []}}
        else
          entity
        end

      if entity.cards.draw |> Enum.count() > 0 do
        [card | draw] = entity.cards.draw

        entity = %Entity{
          entity
          | cards: %{entity.cards | hand: [card | entity.cards.hand], draw: draw}
        }

        placeEntity(truename, entity)
      end
    end

    def shuffle(truename, entity) do
      entity = %Entity{entity | cards: %{entity.cards | draw: _shuffle(entity.cards.draw)}}
      placeEntity(truename, entity)
    end

    defp _shuffle(cards) do
      cards = Enum.shuffle(cards)
      # always make sure that Final Seal is on the bottom (194 and 195)
      finalSeal = Enum.any?(cards, fn c -> c.id == 194 || c.id == 195 end)

      if finalSeal do
        card = Enum.filter(cards, fn c -> c.id == 194 || c.id == 195 end)
        Enum.reject(cards, fn c -> c.id == 194 || c.id == 195 end) ++ card
      else
        cards
      end
    end

    def return_random(truename, entity) do
      # selects random card from discard and sends it to the hand
      if entity.cards.discard |> Enum.count() > 0 do
        card = entity.cards.discard |> Enum.random()
        discard = entity.cards.discard |> Enum.reject(fn c -> c.uuid == card.uuid end)
        hand = [card | entity.cards.hand]
        entity = %Entity{entity | cards: %{entity.cards | hand: hand, discard: discard}}
        placeEntity(truename, entity)
      end
    end

    def discard(truename, entity, card_uuid) do
      card = entity.cards.hand |> Enum.find(fn c -> c.uuid == card_uuid end)
      discard = [card | entity.cards.discard]
      hand = entity.cards.hand |> Enum.reject(fn c -> c.uuid == card.uuid end)
      entity = %Entity{entity | cards: %{entity.cards | hand: hand, discard: discard}}
      placeEntity(truename, entity)
    end

    def discard_from_field(truename, card, entity) do
      # need to turn card entity back into a card proper
      truecard = Strangepaths.Cards.get_card!(card.card_id)

      entity = %Entity{
        entity
        | cards: %{entity.cards | discard: [truecard | entity.cards.discard]}
      }

      removeEntity(truename, card)
      placeEntity(truename, entity)
    end

    def card_to_hand(truename, card, entity) do
      truecard = Strangepaths.Cards.get_card!(card.card_id)

      entity = %Entity{
        entity
        | cards: %{entity.cards | hand: [truecard | entity.cards.hand]}
      }

      removeEntity(truename, card)
      placeEntity(truename, entity)
    end

    def shuffle_in(deck, card) do
      count = Enum.count(deck)
      split = Enum.random(0..count)
      {stacka, stackb} = Enum.split(deck, split)
      stacka ++ [card] ++ stackb
    end

    def card_to_deck(truename, card, entity) do
      truecard = Strangepaths.Cards.get_card!(card.card_id)

      entity = %Entity{
        entity
        | cards: %{entity.cards | draw: shuffle_in(entity.cards.draw, truecard)}
      }

      removeEntity(truename, card)
      placeEntity(truename, entity)
    end

    def card_to_top_deck(truename, card, entity) do
      truecard = Strangepaths.Cards.get_card!(card.card_id)

      entity = %Entity{
        entity
        | cards: %{entity.cards | draw: [truecard | entity.cards.draw]}
      }

      removeEntity(truename, card)
      placeEntity(truename, entity)
    end

    def remove_from_hand(truename, originalUUID, entity) do
      hand = entity.cards.hand |> Enum.reject(fn c -> c.uuid == originalUUID end)
      placeEntity(truename, %Entity{entity | cards: %{entity.cards | hand: hand}})
    end

    def scry(truename, entity, card_uuid) do
      card = entity.cards.draw |> Enum.find(fn c -> c.uuid == card_uuid end)
      hand = [card | entity.cards.hand]
      draw = entity.cards.draw |> Enum.reject(fn c -> c.uuid == card.uuid end)
      entity = %Entity{entity | cards: %{entity.cards | hand: hand, draw: draw}}
      placeEntity(truename, entity)
    end

    def return(truename, entity, card_uuid) do
      card = entity.cards.discard |> Enum.find(fn c -> c.uuid == card_uuid end)
      hand = [card | entity.cards.hand]
      discard = entity.cards.discard |> Enum.reject(fn c -> c.uuid == card.uuid end)
      entity = %Entity{entity | cards: %{entity.cards | hand: hand, discard: discard}}
      placeEntity(truename, entity)
    end

    def gm_screen_toggle(truename) do
      {_, ceremony} = get(truename)
      ceremony = %Ceremony{ceremony | gm_avatars_visible: !ceremony.gm_avatars_visible}
      save(truename, ceremony)
    end

    def delete(truename) do
      Agent.update(__MODULE__, fn state -> Map.delete(state, truename) end)
    end

    def list() do
      ceremonies = Agent.get(__MODULE__, fn state -> state end)

      ceremonies
    end

    def get(truename) do
      ceremony = Agent.get(__MODULE__, fn state -> state[truename] end)

      if ceremony == nil do
        {:error, "No ceremony found."}
      else
        {:ok, ceremony}
      end
    end

    defp save(truename, ceremony) do
      Agent.update(__MODULE__, fn state -> Map.put(state, truename, ceremony) end)
      ceremony
    end

    def ceremony_exists?(name) do
      !is_nil(Agent.get(__MODULE__, fn state -> state[name] end))
    end

    def truename(name, principle, owner_id) do
      :crypto.hash(:md5, name <> principle <> Integer.to_string(owner_id))
      |> Base.encode16()
      |> String.downcase()
    end
  end

  @doc """
  Returns the list of ceremonies.

  ## Examples

      iex> list_ceremonies()
      [%Ceremony{}, ...]

  """
  def list_ceremonies do
    # Might not be necessary
    Ceremony.list()
  end

  @doc """
  Gets a single ceremony.

  Raises if the Ceremony does not exist.

  ## Examples

      iex> get_ceremony!(123)
      %Ceremony{}

  """
  def get_ceremony!(truename) do
    # Might not be necessary
    Ceremony.get(truename)
  end

  @doc """
  Creates a ceremony.

  ## Examples

      iex> create_ceremony(%{field: value})
      {:ok, %Ceremony{}}

      iex> create_ceremony(%{field: bad_value})
      {:error, ...}

  """
  def create_ceremony(attrs \\ %{}, owner_id) do
    # ceremony =
    #  %Ceremony{}
    #  |> Ceremony.changeset(attrs)
    Ceremony.create(attrs["name"], attrs["principle"], owner_id)
  end

  @doc """
  Updates a ceremony.

  ## Examples

      iex> update_ceremony(ceremony, %{field: new_value})
      {:ok, %Ceremony{}}

      iex> update_ceremony(ceremony, %{field: bad_value})
      {:error, ...}

  """

  @doc """
  Deletes a Ceremony.

  ## Examples

      iex> delete_ceremony(ceremony)
      {:ok, %Ceremony{}}

      iex> delete_ceremony(ceremony)
      {:error, ...}

  """
  def delete_ceremony(truename) do
    Ceremony.delete(truename)
  end
end
