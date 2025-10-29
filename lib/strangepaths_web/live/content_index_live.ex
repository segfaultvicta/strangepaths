defmodule StrangepathsWeb.ContentIndexLive do
  use StrangepathsWeb, :live_view

  import StrangepathsWeb.MusicBroadcast
  alias Strangepaths.Site

  def mount(_params, session, socket) do
    socket = assign_defaults(session, socket)
    subscribe_to_music(socket)

    is_admin =
      case socket.assigns.current_user do
        nil -> false
        user -> user.role == :dragon
      end

    pages =
      if is_admin do
        Site.list_content_pages()
      else
        Site.list_published_content_pages()
      end

    {:ok,
     socket
     |> assign(:pages, pages)
     |> assign(:is_admin, is_admin)}
  end

  def handle_event(event, params, socket) do
    case forward_music_client_event(event, params, socket) do
      :not_music_event -> {:noreply, socket}
      result -> result
    end
  end

  def handle_info(msg, socket) do
    case forward_music_event(msg, socket) do
      :not_music_event -> {:noreply, socket}
      result -> result
    end
  end
end
