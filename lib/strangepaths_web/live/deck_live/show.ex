defmodule StrangepathsWeb.DeckLive.Show do
  use StrangepathsWeb, :live_view

  import StrangepathsWeb.MusicBroadcast

  alias Strangepaths.Cards

  @impl true
  def mount(_params, session, socket) do
    # Subscribe to music broadcasts
    subscribe_to_music(socket)

    {:ok, assign_defaults(session, socket)}
  end

  @impl true
  def handle_event(event, params, socket) do
    # Try forwarding music client events first
    case forward_music_client_event(event, params, socket) do
      :not_music_event ->
        # Handle our own events
        handle_deck_event(event, params, socket)

      result ->
        result
    end
  end

  defp handle_deck_event("swap", %{"card" => card, "value" => _, "with" => into}, socket) do
    deck =
      socket.assigns.deck
      |> Cards.remove_card_from_deck(String.to_integer(card))
      |> Cards.add_card_to_deck(String.to_integer(into))

    {:noreply, recalc(socket, deck)}
  end

  defp handle_deck_event("add", %{"value" => card}, socket) do
    deck = Cards.add_card_to_deck(socket.assigns.deck, String.to_integer(card))

    {:noreply, recalc(socket, deck)}
  end

  defp handle_deck_event("remove", %{"value" => card}, socket) do
    deck = Cards.remove_card_from_deck(socket.assigns.deck, String.to_integer(card))

    {:noreply, recalc(socket, deck)}
  end

  defp handle_deck_event("adjust_glory", %{"value" => adjustment}, socket) do
    {:ok, deck} = Cards.adjust_glory(socket.assigns.deck, String.to_integer(adjustment))

    {:noreply, recalc(socket, deck)}
  end

  defp handle_deck_event("truth", _, socket) do
    {:noreply, assign(socket, eye: 0, eye_img: "/images/eye/0.png")}
  end

  defp handle_deck_event("key", value, socket) do
    value = value["key"]
    IO.inspect(value)

    case {socket.assigns.eye, value} do
      {0, "ArrowUp"} ->
        {:noreply, socket |> assign(eye: 1, eye_img: "/images/eye/1.png")}

      {1, "ArrowUp"} ->
        {:noreply, socket |> assign(eye: 2, eye_img: "/images/eye/1.png")}

      {2, "ArrowDown"} ->
        {:noreply, socket |> assign(eye: 3, eye_img: "/images/eye/2.png")}

      {3, "ArrowDown"} ->
        {:noreply, socket |> assign(eye: 4, eye_img: "/images/eye/2.png")}

      {4, "ArrowLeft"} ->
        {:noreply, socket |> assign(eye: 5, eye_img: "/images/eye/3.png")}

      {5, "ArrowRight"} ->
        {:noreply, socket |> assign(eye: 6, eye_img: "/images/eye/3.png")}

      {6, "ArrowLeft"} ->
        {:noreply, socket |> assign(eye: 7, eye_img: "/images/eye/4.png")}

      {7, "ArrowRight"} ->
        {:noreply, socket |> assign(eye: 8, eye_img: "/images/eye/4.png")}

      {8, "b"} ->
        {:noreply, socket |> assign(eye: 9, eye_img: "/images/eye/5.png")}

      {9, "a"} ->
        {:noreply, socket |> assign(eye: 10, eye_img: "/images/eye/6.png")}

      {10, "Enter"} ->
        IO.puts("boop")
        IO.inspect(Process.send_after(self(), :alethics, 2000))
        {:noreply, socket |> assign(eye: :open, eye_img: "/images/eye/7.png")}

      _ ->
        {:noreply, socket |> assign(:eye, nil)}
    end
  end

  defp handle_deck_event("libra", value, socket) do
    IO.inspect(value)

    {res, card_id} =
      Cards.get_card_by_gnosis(
        :crypto.hash(:md5, value["LIBRA"])
        |> Base.encode16()
        |> String.downcase()
      )

    if res == :ok do
      # add card to the deck and clear LIBRA
      deck = Cards.add_card_to_deck(socket.assigns.deck, card_id)

      {:noreply, recalc(socket |> assign(eye: nil, eye_img: nil, alethics: false), deck)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(msg, socket) do
    # Try forwarding music events first
    case forward_music_event(msg, socket) do
      :not_music_event ->
        # Handle our own events
        handle_deck_info(msg, socket)

      result ->
        result
    end
  end

  defp handle_deck_info(:alethics, socket) do
    {:noreply, assign(socket, eye: nil, eye_img: nil, alethics: true)}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    # THIS IS STUPID
    [{%{deck: deck, aspect: aspect}}] = Cards.get_deck!(id)
    deck = Map.put(Strangepaths.Repo.preload(deck, :cards), :aspect, aspect)

    {:noreply,
     socket
     |> assign(eye: nil, eye_img: nil, alethics: false)
     |> assign(:page_title, deck.name)
     |> recalc(deck)}
  end

  defp manabalance_div(deck) do
    Enum.reduce(deck.manabalance, "", fn {color, cardinality}, acc ->
      acc <>
        Enum.reduce(0..cardinality, "", fn
          i, acc2 ->
            case i do
              0 ->
                ""

              _ ->
                acc2 <>
                  "<img class='object-scale-down h-8 mr-4" <>
                  if sidereal_satiation(
                       deck.cards,
                       Cards.get_aspect_id(String.capitalize(color)),
                       i
                     ) do
                    ""
                  else
                    " blur-lg"
                  end <>
                  "' src='/images/" <>
                  color <> "2.png'>"
            end
        end)
    end)
  end


  defp recalc(socket, deck) do
    deck_ids = Enum.map(deck.cards, fn c -> c.id end)
    cards = Cards.list_cards_for_codex()
    graces = Cards.rites(cards, deck.aspect_id, 1, :Grace)
    aspectrites = Cards.rites(cards, deck.aspect_id, 10, :Rite)
    aspects = Cards.list_aspects()

    sidereals =
      Enum.reduce(deck.manabalance, %{}, fn {color, cardinality}, acc ->
        if cardinality > 0 do
          Map.put(
            acc,
            String.to_atom(color),
            Cards.rites(
              cards,
              Enum.filter(aspects, fn a -> a.name == String.capitalize(color) end)
              |> Enum.map(fn a -> a.id end)
              |> Enum.at(0),
              30,
              :Rite
            )
            |> Enum.map(fn c ->
              if Enum.member?(deck_ids, c.id) do
                if c.glorified do
                  Map.put(c, :deckstatus, "glorified")
                else
                  Map.put(c, :deckstatus, "extant")
                end
              else
                if(!c.glorified && !Enum.member?(deck_ids, c.alt)) do
                  Map.put(c, :deckstatus, "latent")
                end
              end
            end)
            |> Enum.reject(fn c -> c == nil end)
          )
        else
          acc
        end
      end)

    basecards =
      ([Enum.at(graces, 0)] ++ Enum.slice(aspectrites, 0..9))
      |> Enum.reject(fn c -> !Enum.member?(deck_ids, c.id) end)
      |> Enum.map(fn c ->
        Map.put(
          c,
          :deckstatus,
          if c.glorified do
            "glorified"
          else
            "extant"
          end
        )
      end)

    graces =
      graces
      |> Enum.slice(1, 5)
      |> Enum.map(fn c ->
        if Enum.member?(deck_ids, c.id) do
          if(c.glorified) do
            Map.put(c, :deckstatus, "glorified")
          else
            Map.put(c, :deckstatus, "extant")
          end
        else
          Map.put(c, :deckstatus, "latent")
        end
      end)

    aspectrites =
      aspectrites
      |> Enum.slice(10, 10)
      |> Enum.map(fn c ->
        if Enum.member?(deck_ids, c.id) do
          if c.glorified do
            Map.put(c, :deckstatus, "glorified")
          else
            Map.put(c, :deckstatus, "extant")
          end
        else
          if(!c.glorified && !Enum.member?(deck_ids, c.alt)) do
            Map.put(c, :deckstatus, "latent")
          end
        end
      end)
      |> Enum.reject(fn c -> c == nil end)

    aletheia = Enum.filter(deck.cards, fn c -> c.gnosis != nil end)

    cards =
      (basecards ++
         graces ++
         aspectrites ++
         Enum.reduce(sidereals, [], fn {_, rites}, acc -> acc ++ rites end) ++ aletheia)
      |> Enum.reject(fn c -> c == nil end)

    deck = %{
      deck
      | cards:
          Enum.map(deck.cards, fn c ->
            %{
              c
              | glory_cost:
                  if(c.gnosis != nil) do
                    0
                  else
                    Enum.find(cards, fn d -> c.id == d.id end).glory_cost
                  end
            }
          end)
    }

    glory = Enum.reduce(deck.cards, 0, fn c, acc -> acc + c.glory_cost end)

    satieties =
      Enum.reduce(deck.manabalance, %{}, fn {color, cardinality}, acc ->
        aspect_id = Cards.get_aspect_id(String.capitalize(color))

        Map.put(
          acc,
          color,
          Enum.count(deck.cards, fn c -> c.aspect_id == aspect_id end) == cardinality
        )
      end)

    balanced = Map.values(satieties) |> Enum.all?()

    socket
    |> assign(:basecards, basecards)
    |> assign(:graces, graces)
    |> assign(:aspectrites, aspectrites)
    |> assign(:sidereals, sidereals)
    |> assign(:aletheia, aletheia)
    |> assign(:glory, glory)
    |> assign(:balanced, balanced)
    |> assign(:satieties, satieties)
    |> assign(:deck, %{deck | glory_used: glory})
  end

  defp sidereal_satiation(cards, color, i) do
    Enum.count(cards, fn c -> c.aspect_id == color end) >= i
  end

  defp ch(type, glory, gnosis) do
    if gnosis != nil do
      "ꙮ"
    else
      if type == :Grace do
        "❂"
      else
        if glory do
          "🟔"
        else
          "⭒"
        end
      end
    end
  end

  defp cardclass(type, glory, aid) do
    if type == :Grace do
      "text-center text-blue-300"
    else
      if glory do
        "text-center text-yellow-300"
      else
        "text-center"
      end <>
        case aid do
          9 -> " underline decoration-red-500"
          10 -> " underline decoration-blue-500"
          11 -> " underline decoration-green-500"
          12 -> " underline decoration-white"
          13 -> " underline decoration-black"
          _ -> ""
        end
    end
  end
end
