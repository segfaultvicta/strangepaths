defmodule Strangepaths.Cards do
  @moduledoc """
  The Cards context.
  """

  import Ecto.Query, warn: false
  alias Strangepaths.Repo

  alias Strangepaths.Cards.Card
  alias Strangepaths.Cards.Aspect

  @doc """
  Returns the list of cards.

  ## Examples

      iex> list_cards()
      [%Card{}, ...]

  """
  def list_cards do
    Repo.all(Card)
  end

  def list_cards_for_cosmos() do
    cards =
      Card
      |> where(glorified: false)
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

  def list_cards_for_codex() do
    cards =
      Card
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

  @doc """
  Searches and filters cards based on query and filters.
  Returns cards grouped by aspect.

  Parameters:
  - search_query: String to search in card name and rules (nil or empty = no search)
  - aspect_id: Filter by specific aspect (nil = all unlocked aspects)
  - show_glorified: Include glorified cards (boolean)
  - user_role: :dragon to see locked aspects, anything else hides them
  """
  def search_and_filter_cards(search_query, aspect_id, show_glorified, user_role) do
    # Build base query
    query = from(c in Card, order_by: [asc: c.id])

    # Apply search if present
    query =
      if search_query && String.trim(search_query) != "" do
        search_pattern = "%#{search_query}%"

        from(c in query,
          where: ilike(c.name, ^search_pattern) or ilike(c.rules, ^search_pattern)
        )
      else
        query
      end

    # Filter by aspect if specified
    query =
      if aspect_id do
        from(c in query, where: c.aspect_id == ^aspect_id)
      else
        query
      end

    # Filter glorified cards
    query =
      if !show_glorified do
        from(c in query, where: c.glorified == false)
      else
        query
      end

    # Execute query
    cards = Repo.all(query)

    # Get aspects to group by (only unlocked unless dragon)
    aspects =
      if user_role == :dragon do
        Repo.all(Aspect)
      else
        list_unlocked_aspects()
      end

    # Group cards by aspect
    Enum.reduce(aspects, %{}, fn aspect, acc ->
      aspect_cards = Enum.filter(cards, fn c -> c.aspect_id == aspect.id end)

      if length(aspect_cards) > 0 do
        Map.put(acc, aspect.id, %{
          name: aspect.name,
          cards: aspect_cards,
          parent_aspect_id: aspect.parent_aspect_id,
          unlocked: aspect.unlocked
        })
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
  Gets all unlocked aspects.
  """
  def list_unlocked_aspects do
    from(a in Aspect, where: a.unlocked == true)
    |> Repo.all()
  end

  @doc """
  Gets aspects organized by parent/child hierarchy.
  Returns a list of %{parent: aspect, children: [child_aspects]}
  """
  def list_aspects_with_hierarchy do
    aspects = Repo.all(from(a in Aspect, order_by: [asc: a.id]))

    # Group by parent
    base_aspects = Enum.filter(aspects, fn a -> is_nil(a.parent_aspect_id) end)

    Enum.map(base_aspects, fn parent ->
      children = Enum.filter(aspects, fn a -> a.parent_aspect_id == parent.id end)
      %{parent: parent, children: children}
    end)
  end

  @doc """
  Gets aspects that can be selected for deck creation based on user role.
  - Regular users: Only base aspects (Fang, Claw, Scale, Breath)
  - Dragons: Base aspects + all unlocked sub-aspects
  """
  def list_aspects_for_deck_creation(:dragon) do
    # Get all base aspects and their unlocked children
    from(a in Aspect,
      where: a.id in [1, 2, 3, 4] or (a.unlocked == true and not is_nil(a.parent_aspect_id)),
      order_by: [asc: a.parent_aspect_id, asc: a.id],
      preload: [:parent_aspect]
    )
    |> Repo.all()
  end

  def list_aspects_for_deck_creation(_user_role) do
    # Regular users only see base aspects
    from(a in Aspect, where: a.id in [1, 2, 3, 4])
    |> Repo.all()
  end

  @doc """
  Gets an aspect with its parent preloaded.
  """
  def get_aspect_with_parent(id) do
    Repo.get(Aspect, id)
    |> Repo.preload(:parent_aspect)
  end

  @doc """
  Returns a display name for an aspect including parent if it's a sub-aspect.
  Examples: "Fang", "Venom (Fang)"
  """
  def get_aspect_display_name(aspect_id) when is_integer(aspect_id) do
    aspect = get_aspect_with_parent(aspect_id)
    get_aspect_display_name(aspect)
  end

  def get_aspect_display_name(%Aspect{parent_aspect: nil} = aspect) do
    aspect.name
  end

  def get_aspect_display_name(%Aspect{parent_aspect: parent} = aspect) when not is_nil(parent) do
    "#{aspect.name} (#{parent.name})"
  end

  def get_aspect_display_name(%Aspect{parent_aspect_id: nil} = aspect) do
    aspect.name
  end

  def get_aspect_display_name(%Aspect{parent_aspect_id: parent_id} = aspect)
      when not is_nil(parent_id) do
    parent = Repo.get(Aspect, parent_id)
    "#{aspect.name} (#{parent.name})"
  end

  @doc """
  Creates a new aspect.
  """
  def create_aspect(attrs) do
    %Aspect{}
    |> Aspect.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an aspect (name, description).
  """
  def update_aspect(%Aspect{} = aspect, attrs) do
    aspect
    |> Aspect.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Toggles the locked status of an aspect.
  Cannot unlock aspect if parent is locked.
  """
  def toggle_aspect_lock(%Aspect{} = aspect) do
    aspect = Repo.preload(aspect, :parent_aspect)

    # If unlocking a child aspect, check parent is unlocked
    if !aspect.unlocked && aspect.parent_aspect && !aspect.parent_aspect.unlocked do
      {:error, "Cannot unlock aspect while parent aspect is locked"}
    else
      aspect
      |> Ecto.Changeset.change(unlocked: !aspect.unlocked)
      |> Repo.update()
    end
  end

  @doc """
  Deletes an aspect.
  Prevents deletion if aspect has cards or is a base aspect.
  """
  def delete_aspect(%Aspect{id: id}) when id in [1, 2, 3, 4] do
    {:error, "Cannot delete base aspects (Fang, Claw, Scale, Breath)"}
  end

  def delete_aspect(%Aspect{} = aspect) do
    # Check if aspect has any cards
    card_count =
      from(c in Card, where: c.aspect_id == ^aspect.id, select: count(c.id))
      |> Repo.one()

    if card_count > 0 do
      {:error, "Cannot delete aspect with #{card_count} associated card(s)"}
    else
      Repo.delete(aspect)
    end
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
        type: type,
        aspect_id: aspect_id,
        rules: rules,
        glory_rules: glory_rules
      }) do
    {res, card} =
      %Card{}
      |> Card.changeset(%{
        name: name,
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
        type: type,
        aspect_id: aspect_id,
        rules: rules
      }) do
    %Card{}
    |> Card.changeset(%{
      name: name,
      img: image_from_name(name, false),
      type: type,
      aspect_id: aspect_id,
      rules: rules,
      alt: nil,
      glorified: false
    })
    |> Repo.insert()
  end

  # TODO need to make a webform created card that
  # works for non-base-aspect, non-alethic cards in
  # order to fix the crash I am experiencing right now

  # for cards created via the webform (alethic rites)
  def create_card(%{
        "name" => name,
        "img" => img,
        "type" => type,
        "rules" => rules,
        "gnosis" => gnosis_plaintext
      }) do
    %Card{}
    |> Card.changeset(%{
      name: name,
      img: img,
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
  Deletes a card. Need to name-search to delete both a card and its glorified form, if necessary.

  ## Examples

      iex> delete_card(card)
      {:ok, %Card{}}

      iex> delete_card(card)
      {:error, %Ecto.Changeset{}}

  """
  def delete_card(%Card{} = card) do
    from(c in Card, where: c.name == ^card.name)
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

  def select_decks_for_ceremony(user_id) do
    decks =
      list_decks(user_id)
      |> Enum.map(fn {d} -> d.deck end)
      |> Enum.map(fn d -> {d.name, d.id} end)

    decks ++
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
    |> Repo.preload(:avatar)
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
    aspect_id = String.to_integer(attrs["aspect_id"])
    aspect = Repo.get!(Aspect, aspect_id)

    # Only preload base cards for base aspects (Fang, Claw, Scale, Breath)
    # Sub-aspects (with parent_aspect_id) start with empty deck
    basecards =
      if aspect.parent_aspect_id do
        # Sub-aspect: no base cards
        []
      else
        # Base aspect: preload the basic Grace and base 5 Rites
        cards = list_cards_for_codex()

        [Enum.at(rites(cards, aspect_id, 1, :Grace), 0)] ++
          Enum.reject(rites(cards, aspect_id, 20, :Rite), fn r ->
            r.glory_cost != 0
          end)
      end

    %Deck{glory: 0, cards: basecards}
    |> Deck.new_changeset(attrs)
    |> Repo.insert()
  end

  def add_card_to_deck(deck, card) do
    card = get_card!(card)

    deck
    |> Deck.cards_changeset([card | deck.cards])
    |> Repo.update()
    |> bingle_bongle
  end

  def remove_card_from_deck(deck, card_id) do
    deck
    |> Deck.cards_changeset(Enum.reject(deck.cards, fn c -> c.id == card_id end))
    |> Repo.update()
    |> bingle_bongle
  end

  # bingles ur bongle
  # had to give this an intentionally stupid name
  # because it is a very stupid thing that does stupid things
  def bingle_bongle({:ok, deck}) do
    deck
  end

  def update_deck_manabalance(deck, manabalance) do
    deck
    |> Deck.edit_changeset(%{manabalance: manabalance})
    |> Repo.update()
  end

  def adjust_glory(deck, adjustment) do
    adjustment =
      if deck.glory + adjustment < deck.glory_used and !(deck.glory < deck.glory_used) do
        0
      else
        adjustment
      end

    deck
    |> Deck.glory_changeset(adjustment)
    |> Repo.update()
  end

  def adjust_tolerance(deck, adjustment) do
    deck
    |> Deck.tolerance_changeset(adjustment)
    |> Repo.update()
  end

  def update_deck_avatar(deck, avatar_id) do
    deck
    |> Deck.avatar_changeset(avatar_id)
    |> Repo.update()
  end

  def adjust_blockcap(deck, adjustment) do
    deck
    |> Deck.blockcap_changeset(adjustment)
    |> Repo.update()
  end

  def deckmana(deck_id) do
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

  def bonus_text(deckID) do
    if(deckID == nil) do
      ""
    else
      Enum.reduce(
        get_deck(deckID).manabalance,
        "",
        fn {color, count}, acc ->
          acc <> Strangepaths.Cards.bonus_text(color, count, "simple") <> "\n\n"
        end
      )
    end
  end

  def bonus_text(color, num, complexity) do
    if num > 0 do
      case {color, complexity} do
        {"red", "simple"} ->
          "#{num} Strikes deal +1 Stress."

        {"red", "full"} ->
          "- Your first #{num} Strikes played each encounter deal +1 Stress."

        {"black", "simple"} ->
          "1 Stress to first #{num} opponents targeting you."

        {"black", "full"} ->
          "- The first #{num} time(s) as an opponent uses a Rite on you, the opponent Stresses 1."

        {"blue", "simple"} ->
          comp1 = ceil(num / 3)
          comp2 = if num >= 2, do: ceil((num - 1) / 3), else: 0
          comp3 = if num >= 3, do: ceil((num - 2) / 3), else: 0

          base = "+#{comp1} initial Draw"
          with_refresh = if comp2 > 0, do: " & on first #{comp2} Refresh", else: ""
          with_draw_discard = if comp3 > 0, do: ". Draw&Discard #{comp3} at start", else: ""

          base <> with_refresh <> with_draw_discard <> "."

        {"blue", "full"} ->
          comp1 = ceil(num / 3)
          comp2 = if num >= 2, do: ceil((num - 1) / 3), else: 0
          comp3 = if num >= 3, do: ceil((num - 2) / 3), else: 0

          base = "- Gain +#{comp1} Draw into your starting hand at the beginning of a Ritual."

          with_refresh =
            if comp2 > 0 do
              "\n\n- Your first #{comp2} refreshes draw +1 rites."
            else
              ""
            end

          with_draw_discard =
            if comp3 > 0 do
              "\n\n- At the start of your turn, Draw N and Discard N, where N is the smaller of #{comp3} and the current number of rites in your hand."
            else
              ""
            end

          base <> with_refresh <> with_draw_discard

        {"green", "simple"} ->
          comp1 = ceil(num / 3)
          comp2 = if num >= 2, do: ceil((num - 1) / 3), else: 0
          comp3 = if num >= 3, do: ceil((num - 2) / 3), else: 0

          base = "+#{comp1} Tolerance"
          with_refresh = if comp2 > 0, do: ", first #{comp2} Refresh free", else: ""

          with_quick =
            if comp3 > 0, do: ". First #{comp3} Quick rites trigger Draw 1 EOT", else: ""

          base <> with_refresh <> with_quick <> "."

        {"green", "full"} ->
          comp1 = ceil(num / 3)
          comp2 = if num >= 2, do: ceil((num - 1) / 3), else: 0
          comp3 = if num >= 3, do: ceil((num - 2) / 3), else: 0

          base = "- +#{comp1} Tolerance."

          with_refresh =
            if comp2 > 0 do
              "\n\n- Your first #{comp2} refreshes have no Stress cost."
            else
              ""
            end

          with_quick =
            if comp3 > 0 do
              "\n\n- The first #{comp3} of Quick rites you play cause you to Draw 1 at the end of your turn when played."
            else
              ""
            end

          base <> with_refresh <> with_quick

        {"white", "simple"} ->
          comp1 = ceil(num / 3)
          comp2 = if num >= 2, do: ceil((num - 1) / 3), else: 0
          comp3 = if num >= 3, do: ceil((num - 2) / 3), else: 0

          base = "First #{comp1} round(s) +1 Defense"

          with_refresh =
            if comp2 > 0, do: ", first #{comp2} Refreshes grant ally +1 Defense", else: ""

          with_non_strike =
            if comp3 > 0, do: ", first #{comp3} non-Strike Rite grant ally +1 Defense", else: ""

          base <> with_refresh <> with_non_strike <> "."

        {"white", "full"} ->
          comp1 = ceil(num / 3)
          comp2 = if num >= 2, do: ceil((num - 1) / 3), else: 0
          comp3 = if num >= 3, do: ceil((num - 2) / 3), else: 0

          base = "- For the first #{comp1} rounds, gain 1 Defense at the start of the round."

          with_refresh =
            if comp2 > 0 do
              "\n\n- Your first #{comp2} Refreshes grant 1 ally in your lane +1 Defense."
            else
              ""
            end

          with_non_strike =
            if comp3 > 0 do
              "\n\n- Your first #{comp3} rites that do not deal damage also let you Defend 1 an ally in your lane."
            else
              ""
            end

          base <> with_refresh <> with_non_strike

        _ ->
          ""
      end
    else
      ""
    end
  end

  def deck_bonuses(deck) do
    Enum.map(deck.manabalance, fn {color, num} ->
      if num > 0 do
        %{simple: bonus_text(color, num, "simple"), full: bonus_text(color, num, "full")}
      else
        nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  def deckglory(deck_id) do
    (get_deck!(deck_id) |> Enum.at(0) |> Tuple.to_list() |> Enum.at(0)).deck.glory
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
          %{
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
              tolerance: 15,
              blockcap: 10,
              stress: 7,
              defence: 0,
              glory: 0,
              deckmana: nil,
              bonustext: "",
              rulestext: "",
              type: nil,
              card_id: nil,
              glorified: false,
              gnosis: false,
              smol: false,
              bright: true,
              owner_id: 0

    def to_string(self) do
      self.uuid <> ":" <> self.name
    end

    def create(:Avatar, name, deckID, tolerance, blockcap, avatar, owner) do
      if Strangepaths.Cards.deck_exists?(deckID) do
        %Entity{
          name: name,
          uuid: Ecto.UUID.generate(),
          x: 0,
          y: 0,
          img: avatar.filepath,
          tolerance: tolerance,
          blockcap: blockcap,
          stress: 0,
          glory: Strangepaths.Cards.deckglory(deckID),
          defence: 0,
          deckID: deckID,
          deckmana: Strangepaths.Cards.deckmana(deckID),
          bonustext: Strangepaths.Cards.bonus_text(deckID),
          type: :Avatar,
          owner_id: owner.id
        }
      else
        # we're a fiend
        %Entity{
          name: name,
          uuid: Ecto.UUID.generate(),
          x: 0,
          y: 0,
          img: avatar.filepath,
          tolerance: tolerance,
          blockcap: blockcap,
          stress: 0,
          glory: 0,
          defence: 0,
          deckID: deckID,
          deckmana: [],
          type: :Avatar,
          owner_id: owner.id
        }
      end
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
      width = context["width"]
      left = context["left"]
      screenWidth = screenWidth(e.type, e.smol)

      e.x * 0.01 * width + left - screenWidth / 2
    end

    def screen_y(_e, nil) do
      0
    end

    def screen_y(e, context) do
      height = context["height"]
      top = context["top"]
      screenHeight = screenHeight(e.type, e.smol)

      e.y * 0.01 * height + top - screenHeight / 2
    end

    def screenWidth(type) do
      screenWidth(type, false)
    end

    def screenWidth(type, smol) do
      case {type, smol} do
        {:Avatar, false} -> 120
        {:Card, false} -> 200
        {:Card, true} -> 100
        {:Counter, false} -> 40
        {:Radial, false} -> 400
        _ -> 1
      end
    end

    def screenHeight(type) do
      screenHeight(type, false)
    end

    def screenHeight(type, smol) do
      case {type, smol} do
        {:Avatar, false} -> 120
        {:Card, false} -> 300
        {:Card, true} -> 150
        {:Counter, false} -> 40
        {:Radial, false} -> 400
        _ -> 1
      end
    end
  end

  defimpl Inspect, for: Entity do
    def inspect(
          %Entity{
            name: name,
            uuid: uuid,
            x: x,
            y: y,
            img: _img,
            deckID: _deckID,
            cards: cards,
            tolerance: _tolerance,
            blockcap: _blockcap,
            stress: _stress,
            defence: _defence,
            glory: _glory,
            deckmana: _deckmana,
            rulestext: _rulestext,
            type: type,
            card_id: _card_id,
            glorified: _glorified,
            gnosis: _gnosis,
            smol: _smol,
            bright: _bright,
            owner_id: _owner_id
          },
          _opts
        ) do
      """
      E[#{name} (#{uuid}) #{type}@#{x}, #{y}]:
      """ <>
        case type do
          :Avatar ->
            "Avatar! \n" <>
              "HAND: " <>
              (cards.hand
               |> Enum.map(fn c -> c.name end)
               |> Enum.join(", ")) <>
              "\n" <>
              "DISCARD: " <>
              (cards.discard
               |> Enum.map(fn c -> c.name end)
               |> Enum.join(", ")) <>
              "\n" <>
              "DECK: " <>
              (cards.draw
               |> Enum.map(fn c -> c.name end)
               |> Enum.join(", ")) <>
              "\n" <>
              "GRACES: " <>
              (cards.graces
               |> Enum.map(fn c -> c.name end)
               |> Enum.join(", "))

          :Card ->
            "Card"

          :Counter ->
            "Counter"

          :Radial ->
            "Radial"
        end
    end
  end

  defmodule Ceremony do
    use Agent

    defstruct id: nil,
              name: "",
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

    def create(name, owner_id) do
      owner_name = Strangepaths.Accounts.get_user!(owner_id).nickname
      truename = truename(name, owner_id)

      ceremony = %Ceremony{
        id: truename,
        name: name,
        owner_id: owner_id,
        owner_name: owner_name,
        entities: []
      }

      if !ceremony_exists?(truename) do
        Agent.update(__MODULE__, fn state -> Map.put(state, truename, ceremony) end)
        {:ok, ceremony}
      else
        {:error, "Ceremony with that name and creator already exists."}
      end
    end

    def placeEntity(truename, trueentity) do
      {ok, ceremony} = get(truename)

      entity =
        if !Enum.find(ceremony.entities, fn e -> e.uuid == trueentity.uuid end) &&
             trueentity.type == :Avatar &&
             trueentity.deckID != nil do
          deck =
            if(Strangepaths.Cards.deck_exists?(trueentity.deckID)) do
              Strangepaths.Cards.get_full_deck(trueentity.deckID).cards
            else
              []
            end

          graces = deck |> Enum.filter(fn c -> c.type == :Grace end)

          rites =
            deck
            |> Enum.filter(fn c -> c.type == :Rite end)
            |> Enum.map(fn c -> %{c | uuid: Ecto.UUID.generate()} end)
            |> _shuffle()

          {hand, rites} = Enum.split(rites, 4)

          %{trueentity | cards: %{trueentity.cards | hand: hand, graces: graces, draw: rites}}
        else
          trueentity
        end

      # if entity already exists, remove it from the list of entities (handles moves)
      entities = ceremony.entities |> Enum.reject(fn e -> e.uuid == entity.uuid end)

      if ok == :ok do
        {:ok, save(truename, %{ceremony | entities: [entity | entities]})}
      else
        {:error, ceremony}
      end
    end

    def removeEntity(truename, entity) do
      {ok, ceremony} = get(truename)
      entities = ceremony.entities |> Enum.reject(fn e -> e.uuid == entity.uuid end)

      if ok == :ok do
        {:ok, save(truename, %{ceremony | entities: entities})}
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

    def toggle_brightness(truename, uuid) do
      {ok, ceremony} = get(truename)

      if ok == :ok do
        entity = Enum.find(ceremony.entities, fn e -> e.uuid == uuid end)
        entity = %{entity | bright: !entity.bright}

        {:ok,
         save(truename, %{
           ceremony
           | entities: [entity | Enum.reject(ceremony.entities, fn e -> e.uuid == uuid end)]
         })}
      else
        {:error, ceremony}
      end
    end

    def brighten_all_entities(truename) do
      {ok, ceremony} = get(truename)

      if ok == :ok do
        entities = Enum.map(ceremony.entities, fn e -> %{e | bright: true} end)

        {:ok, save(truename, %{ceremony | entities: entities})}
      else
        {:error, ceremony}
      end
    end

    def toggle_smolness(truename, uuid) do
      {ok, ceremony} = get(truename)

      if ok == :ok do
        entity = Enum.find(ceremony.entities, fn e -> e.uuid == uuid end)
        entity = %{entity | smol: !entity.smol}

        {:ok,
         save(truename, %{
           ceremony
           | entities: [entity | Enum.reject(ceremony.entities, fn e -> e.uuid == uuid end)]
         })}
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
      entity = get_entity(truename, entity.uuid)

      hand =
        if n == 1 do
          [%{card | uuid: Ecto.UUID.generate()} | entity.cards.hand]
        else
          (List.duplicate(card, n)
           |> Enum.map(fn c -> %{c | uuid: Ecto.UUID.generate()} end)) ++ entity.cards.hand
        end

      entity = %{entity | cards: %{entity.cards | hand: hand}}
      placeEntity(truename, entity)
    end

    def draw(truename, entity) do
      entity = get_entity(truename, entity.uuid)

      entity =
        if Enum.count(entity.cards.draw) == 0 do
          %{entity | cards: %{entity.cards | draw: _shuffle(entity.cards.discard), discard: []}}
        else
          entity
        end

      if entity.cards.draw |> Enum.count() > 0 do
        [card | draw] = entity.cards.draw

        entity = %{
          entity
          | cards: %{entity.cards | hand: [card | entity.cards.hand], draw: draw}
        }

        placeEntity(truename, entity)
      end
    end

    def shuffle(truename, entity) do
      # make sure we are dealing with the most up to date version of that entity
      entity = get_entity(truename, entity.uuid)
      entity = %{entity | cards: %{entity.cards | draw: _shuffle(entity.cards.draw)}}
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
      entity = get_entity(truename, entity.uuid)
      # selects random card from discard and sends it to the hand
      if entity.cards.discard |> Enum.count() > 0 do
        card = entity.cards.discard |> Enum.random()
        discard = entity.cards.discard |> Enum.reject(fn c -> c.uuid == card.uuid end)
        hand = [card | entity.cards.hand]
        entity = %{entity | cards: %{entity.cards | hand: hand, discard: discard}}
        placeEntity(truename, entity)
      end
    end

    def discard(truename, entity, card_uuid) do
      entity = get_entity(truename, entity.uuid)
      card = entity.cards.hand |> Enum.find(fn c -> c.uuid == card_uuid end)
      discard = [card | entity.cards.discard]
      hand = entity.cards.hand |> Enum.reject(fn c -> c.uuid == card.uuid end)
      entity = %{entity | cards: %{entity.cards | hand: hand, discard: discard}}
      placeEntity(truename, entity)
    end

    def discard_from_field(truename, card, entity) do
      # need to turn card entity back into a card proper
      truecard = Strangepaths.Cards.get_card!(card.card_id)
      entity = get_entity(truename, entity.uuid)

      entity = %{
        entity
        | cards: %{entity.cards | discard: [truecard | entity.cards.discard]}
      }

      removeEntity(truename, card)
      placeEntity(truename, entity)
    end

    def card_to_hand(truename, card, entity) do
      truecard = Strangepaths.Cards.get_card!(card.card_id)
      entity = get_entity(truename, entity.uuid)

      entity = %{
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

    def card_id_to_deck(truename, card_id, entity) do
      truecard = Strangepaths.Cards.get_card!(card_id)
      entity = get_entity(truename, entity.uuid)

      entity = %{
        entity
        | cards: %{entity.cards | draw: shuffle_in(entity.cards.draw, truecard)}
      }

      placeEntity(truename, entity)
    end

    def card_to_deck(truename, card, entity) do
      truecard = Strangepaths.Cards.get_card!(card.card_id)
      entity = get_entity(truename, entity.uuid)

      entity = %{
        entity
        | cards: %{entity.cards | draw: shuffle_in(entity.cards.draw, truecard)}
      }

      removeEntity(truename, card)
      placeEntity(truename, entity)
    end

    def card_to_top_deck(truename, card, entity) do
      truecard = Strangepaths.Cards.get_card!(card.card_id)
      entity = get_entity(truename, entity.uuid)

      entity = %{
        entity
        | cards: %{entity.cards | draw: [truecard | entity.cards.draw]}
      }

      removeEntity(truename, card)
      placeEntity(truename, entity)
    end

    def remove_from_hand(truename, originalUUID, entity) do
      entity = get_entity(truename, entity.uuid)
      hand = entity.cards.hand |> Enum.reject(fn c -> c.uuid == originalUUID end)
      placeEntity(truename, %{entity | cards: %{entity.cards | hand: hand}})
    end

    def scry(truename, entity, card_uuid) do
      entity = get_entity(truename, entity.uuid)
      card = entity.cards.draw |> Enum.find(fn c -> c.uuid == card_uuid end)
      hand = [card | entity.cards.hand]
      draw = entity.cards.draw |> Enum.reject(fn c -> c.uuid == card.uuid end)
      entity = %{entity | cards: %{entity.cards | hand: hand, draw: draw}}
      placeEntity(truename, entity)
    end

    def return(truename, entity, card_uuid) do
      entity = get_entity(truename, entity.uuid)
      card = entity.cards.discard |> Enum.find(fn c -> c.uuid == card_uuid end)
      hand = [card | entity.cards.hand]
      discard = entity.cards.discard |> Enum.reject(fn c -> c.uuid == card.uuid end)
      entity = %{entity | cards: %{entity.cards | hand: hand, discard: discard}}
      placeEntity(truename, entity)
    end

    def gm_screen_toggle(truename) do
      {_, ceremony} = get(truename)
      ceremony = %{ceremony | gm_avatars_visible: !ceremony.gm_avatars_visible}
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

    def truename(name, owner_id) do
      :crypto.hash(:md5, name <> Integer.to_string(owner_id))
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
    Ceremony.create(attrs["name"], owner_id)
  end

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
