defmodule StrangepathsWeb.CeremonyLive.Index do
  use StrangepathsWeb, :live_view

  import StrangepathsWeb.MusicBroadcast

  alias Strangepaths.Cards
  alias Strangepaths.Cards.Ceremony

  @impl true
  def mount(params, session, socket) do
    socket = assign_defaults(session, socket)

    # Subscribe to music broadcasts
    subscribe_to_music(socket)

    # If current user has a last_rite_id defined,
    # redirect to that rite, unless a specific
    # query parameter is present.
    if socket.assigns.current_user != nil and
         socket.assigns.current_user.last_rite_id != nil and
         Ceremony.ceremony_exists?(socket.assigns.current_user.last_rite_id) and
         params["force_index"] == nil do
      {:ok, push_redirect(socket, to: "/ceremony/#{socket.assigns.current_user.last_rite_id}")}
    else
      {:ok, assign(socket, :ceremonies, Cards.Ceremony.list())}
    end
  end

  @impl true
  def handle_event(event, params, socket) do
    # Try forwarding music client events first
    case forward_music_client_event(event, params, socket) do
      :not_music_event ->
        # Handle our own events
        handle_ceremony_event(event, params, socket)

      result ->
        result
    end
  end

  defp handle_ceremony_event("delete", %{"id" => id}, socket) do
    Cards.delete_ceremony(id)

    {:noreply, assign(socket, :ceremonies, Cards.Ceremony.list())}
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
end
