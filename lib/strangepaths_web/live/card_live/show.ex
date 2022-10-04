defmodule StrangepathsWeb.CardLive.Show do
  use StrangepathsWeb, :live_view

  alias Strangepaths.Cards

  @impl true
  def mount(_params, session, socket) do
    socket = assign_defaults(session, socket)

    {:ok, socket}
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

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    card = Cards.get_card!(id)
    {:ok, _} = Cards.delete_card(card)

    {:noreply,
     push_redirect(socket |> put_flash(:info, card.name <> " successfully deleted!"),
       to: Routes.card_index_path(socket, card.principle)
     )}
  end

  defp page_title(:show, name), do: name
  defp page_title(:edit, name), do: "Editing " <> name
end
