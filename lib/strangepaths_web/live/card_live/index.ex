defmodule StrangepathsWeb.CardLive.Index do
  use StrangepathsWeb, :live_view

  alias Strangepaths.Cards
  alias Strangepaths.Cards.Card

  @impl true
  def mount(_params, session, socket) do
    socket = assign_defaults(session, socket)

    {:ok,
     assign(socket,
       cards: nil
     )}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Card")
    |> assign(:card, Cards.get_card!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Card")
    |> assign(:card, %Card{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "the Dragon's Cosmos")
    |> assign(:cards, Cards.list_cards_for_cosmos())
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    card = Cards.get_card!(id)
    {:ok, _} = Cards.delete_card(card)

    {:noreply, assign(socket, :cards, Cards.list_cards_for_cosmos())}
  end
end
