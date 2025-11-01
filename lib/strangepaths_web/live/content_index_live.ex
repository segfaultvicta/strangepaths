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
     |> assign(:creating, false)
     |> assign(:is_admin, is_admin)}
  end

  def handle_event(event, params, socket) do
    case forward_music_client_event(event, params, socket) do
      :not_music_event ->
        handle_contentindex_event(event, params, socket)

      result ->
        result
    end
  end

  defp handle_contentindex_event("start_create", _, socket) do
    {:noreply, assign(socket, :creating, true)}
  end

  defp handle_contentindex_event("cancel_create", _, socket) do
    {:noreply, assign(socket, :creating, false)}
  end

  defp handle_contentindex_event("create", %{"title" => title}, socket) do
    case Site.create_content_page(%{
           title: title,
           body: "# #{title}\n\nStart writing here...",
           # bypass entire Draft process, that's for Dragon only
           published: true
         }) do
      {:ok, page} ->
        {:noreply,
         socket
         |> assign(:pages, Site.list_content_pages())
         |> assign(:creating, false)
         |> push_redirect(to: "/content/#{page.slug}")}

      {:error, details} ->
        {:noreply, put_flash(socket, :error, "Failed to create page: #{inspect(details)}")}
    end
  end

  defp handle_contentindex_event(event, _params, socket) do
    {:noreply, socket |> put_flash(:error, "Unrecognised event #{event}. See log for details.")}
  end

  def handle_info(msg, socket) do
    case forward_music_event(msg, socket) do
      :not_music_event -> {:noreply, socket}
      result -> result
    end
  end
end
