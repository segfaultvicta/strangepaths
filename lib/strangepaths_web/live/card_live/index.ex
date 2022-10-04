defmodule StrangepathsWeb.CardLive.Index do
  use StrangepathsWeb, :live_view

  alias Strangepaths.Cards
  alias Strangepaths.Cards.Card

  @impl true
  def mount(_params, session, socket) do
    socket = assign_defaults(session, socket)

    {:ok,
     assign(socket,
       cards: nil,
       active_principle: nil
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

  defp apply_action(socket, :Dragon, _params) do
    socket
    |> assign(:page_title, "the Dragon's Cosmos")
    |> assign(:cards, Cards.list_cards_for_cosmos(:Dragon))
    |> assign(:active_principle, :Dragon)
  end

  defp apply_action(socket, :Stillness, _params) do
    socket
    |> assign(:page_title, "the Stillness' Cosmos")
    |> assign(:cards, Cards.list_cards_for_cosmos(:Stillness))
    |> assign(:active_principle, :Stillness)
  end

  defp apply_action(socket, :Song, _params) do
    socket
    |> assign(:page_title, "the Song's Cosmos")
    |> assign(:cards, Cards.list_cards_for_cosmos(:Song))
    |> assign(:active_principle, :Song)
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Choose a Principle")
    |> assign(:cards, nil)
    |> assign(:active_principle, nil)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    IO.puts("in index delete")
    card = Cards.get_card!(id)
    {:ok, _} = Cards.delete_card(card)

    {:noreply,
     assign(socket, :cards, Cards.list_cards_for_cosmos(socket.assigns.active_principle))}
  end

  def subnavClass(active_principle, test_principle) do
    "my-1 text-lg font-large md:mx-4 md:my-0 hover:text-sky-300 " <>
      if active_principle == test_principle,
        do: "activenav",
        else: "inactivenav"
  end
end
