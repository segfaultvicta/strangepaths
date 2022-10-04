defmodule StrangepathsWeb.DeckLive.Index do
  use StrangepathsWeb, :live_view

  alias Strangepaths.Cards
  alias Strangepaths.Cards.Deck

  @impl true
  def mount(_params, session, socket) do
    socket =
      assign_defaults(session, socket)
      |> assign(sortcol: :name)
      |> assign(direction: :asc)

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

  def handle_event("sort", %{"sortcol" => sortcol}, socket) do
    direction =
      if socket.assigns.sortcol == String.to_atom(sortcol) do
        IO.puts("sortcal invariant")

        if socket.assigns.direction == :asc do
          :desc
        else
          :asc
        end
      else
        IO.puts("sortcal variant, defaulting to desc")
        :desc
      end

    socket = assign(socket, sortcol: String.to_atom(sortcol)) |> assign(direction: direction)

    {:noreply,
     socket
     |> assign(decks: list_decks_of(socket))}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    [{%{aspect: _, deck: deck}}] = Cards.get_deck!(id)
    {:ok, _} = Cards.delete_deck(deck)

    {:noreply, assign(socket, :decks, list_decks_of(socket))}
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
    if(socket.assigns.current_user.role == :god) do
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
