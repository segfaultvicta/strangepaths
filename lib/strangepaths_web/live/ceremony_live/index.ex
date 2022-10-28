defmodule StrangepathsWeb.CeremonyLive.Index do
  use StrangepathsWeb, :live_view

  alias Strangepaths.Cards
  alias Strangepaths.Cards.Ceremony

  @impl true
  def mount(_params, session, socket) do
    socket = assign_defaults(session, socket)
    {:ok, assign(socket, :ceremonies, Cards.Ceremony.list())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Ceremony")
    |> assign(:ceremony, %Ceremony{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Ceremonies")
    |> assign(:ceremony, nil)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    Cards.delete_ceremony(id)

    {:noreply, assign(socket, :ceremonies, Cards.Ceremony.list())}
  end
end
