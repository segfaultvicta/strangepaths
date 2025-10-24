defmodule StrangepathsWeb.CardLive.Show do
  use StrangepathsWeb, :live_view

  import StrangepathsWeb.MusicBroadcast

  alias Strangepaths.Cards

  @impl true
  def mount(_params, session, socket) do
    socket = assign_defaults(session, socket)

    # Subscribe to music broadcasts
    subscribe_to_music(socket)

    {:ok, socket}
  end

  @impl true
  def handle_event(event, params, socket) do
    # Try forwarding music client events first
    case forward_music_client_event(event, params, socket) do
      :not_music_event ->
        # Handle our own events
        handle_card_event(event, params, socket)

      result ->
        result
    end
  end

  defp handle_card_event("delete", %{"id" => id}, socket) do
    card = Cards.get_card!(id)
    {:ok, _} = Cards.delete_card(card)

    {:noreply,
     push_redirect(socket |> put_flash(:info, card.name <> " successfully deleted!"),
       to: Routes.card_index_path(socket, :index)
     )}
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
  def handle_params(%{"id" => id}, _, socket) do
    {card, glory} = Cards.get_card_and_alt(id)

    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action, card.name))
     |> assign(
       card: card,
       glory: glory,
       aspect: Cards.name_aspect(card.aspect_id)
     )}
  end


  defp page_title(:show, name), do: name
  defp page_title(:edit, name), do: "Editing " <> name
end
