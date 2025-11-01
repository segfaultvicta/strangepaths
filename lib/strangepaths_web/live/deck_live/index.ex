defmodule StrangepathsWeb.DeckLive.Index do
  use StrangepathsWeb, :live_view

  import StrangepathsWeb.MusicBroadcast

  alias Strangepaths.Cards
  alias Strangepaths.Cards.Deck

  @impl true
  def mount(_params, session, socket) do
    socket =
      assign_defaults(session, socket)
      |> assign(sortcol: :name)
      |> assign(direction: :asc)

    # Subscribe to music broadcasts
    subscribe_to_music(socket)

    {:ok,
     assign(socket,
       decks:
         if socket.assigns.current_user == nil do
           nil
         else
           list_decks_of(socket)
         end
     )}
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

  defp handle_deck_event("sort", %{"sortcol" => sortcol}, socket) do
    direction =
      if socket.assigns.sortcol == String.to_atom(sortcol) do
        if socket.assigns.direction == :asc do
          :desc
        else
          :asc
        end
      else
        :desc
      end

    socket = assign(socket, sortcol: String.to_atom(sortcol)) |> assign(direction: direction)

    {:noreply,
     socket
     |> assign(decks: list_decks_of(socket))}
  end

  defp handle_deck_event("delete", %{"id" => id}, socket) do
    [{%{aspect: _, deck: deck}}] = Cards.get_deck!(id)
    {:ok, _} = Cards.delete_deck(deck)

    {:noreply, assign(socket, :decks, list_decks_of(socket))}
  end

  @impl true
  def handle_info(msg, socket) do
    # Forward music broadcasts to the component
    case forward_music_event(msg, socket) do
      :not_music_event ->
        # Handle other non-music events here if needed
        {:noreply, socket}

      result ->
        result
    end
  end

  def get_owner_name_by_id(id) do
    Strangepaths.Accounts.get_user!(id).nickname
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Deck")
    |> assign(:deck, Cards.get_deck!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Deck")
    |> assign(:deck, %Deck{
      owner: socket.assigns.current_user.id,
      manabalance: %{green: 0, blue: 0, red: 0, white: 0, black: 0}
    })
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Decks")
    |> assign(:deck, nil)
  end

  defp manabalance_div(manabalance) do
    Enum.reduce(manabalance, "", fn {color, cardinality}, acc ->
      acc <>
        Enum.reduce(0..cardinality, "", fn
          i, acc2 ->
            case i do
              0 ->
                ""

              _ ->
                acc2 <>
                  "<img class='object-scale-down h-8' src='/images/" <> color <> "2.png'>"
            end
        end)
    end)
  end

  defp list_decks_of(socket) do
    if(socket.assigns.current_user.role == :dragon) do
      Cards.list_decks(nil, socket.assigns.sortcol, socket.assigns.direction)
    else
      Cards.list_decks(
        socket.assigns.current_user.id,
        socket.assigns.sortcol,
        socket.assigns.direction
      )
    end
  end
end
