defmodule StrangepathsWeb.ContentAdminLive do
  use StrangepathsWeb, :live_view

  import StrangepathsWeb.MusicBroadcast
  alias Strangepaths.Site

  @impl true
  def mount(_params, session, socket) do
    socket = assign_defaults(session, socket)
    subscribe_to_music(socket)

    IO.inspect(socket.assigns.current_user.role)

    if socket.assigns.current_user.role == :dragon do
      {:ok,
       socket
       |> assign(:pages, Site.list_content_pages())
       |> assign(:creating, false)}
    else
      {:ok,
       socket
       |> put_flash(:error, "Unauthorized")
       |> push_redirect(to: "/")}
    end
  end

  @impl true
  def handle_event(event, params, socket) do
    case forward_music_client_event(event, params, socket) do
      :not_music_event ->
        handle_contentadmin_event(event, params, socket)

      result ->
        result
    end
  end

  defp handle_contentadmin_event("start_create", _, socket) do
    {:noreply, assign(socket, :creating, true)}
  end

  defp handle_contentadmin_event("cancel_create", _, socket) do
    {:noreply, assign(socket, :creating, false)}
  end

  defp handle_contentadmin_event("create", %{"title" => title}, socket) do
    case Site.create_content_page(%{
           title: title,
           body: "# #{title}\n\nStart writing here...",
           published: false
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

  defp handle_contentadmin_event("toggle_published", %{"id" => id}, socket) do
    page = Site.get_content_page!(id)
    Site.update_content_page(page, %{published: !page.published})

    {:noreply, assign(socket, :pages, Site.list_content_pages())}
  end

  defp handle_contentadmin_event("delete", %{"id" => id}, socket) do
    page = Site.get_content_page!(id)
    Site.delete_content_page(page)

    {:noreply, assign(socket, :pages, Site.list_content_pages())}
  end

  defp handle_contentadmin_event(event, params, socket) do
    IO.inspect(event)
    IO.inspect(params)
    {:noreply, socket |> put_flash(:error, "Unrecognised event #{event}. See log for details.")}
  end

  @impl true
  def handle_info(msg, socket) do
    case forward_music_event(msg, socket) do
      :not_music_event ->
        handle_contentadmin_info(msg, socket)

      result ->
        result
    end
  end

  defp handle_contentadmin_info(msg, socket) do
    IO.inspect(msg)

    {:noreply,
     socket |> put_flash(:error, "Unrecognised message #{inspect(msg)}. See log for details.")}
  end
end
