defmodule StrangepathsWeb.ContentLive do
  use StrangepathsWeb, :live_view

  import StrangepathsWeb.MusicBroadcast
  alias Strangepaths.Site

  @impl true
  def mount(%{"slug" => slug}, session, socket) do
    socket = assign_defaults(session, socket)
    subscribe_to_music(socket)

    is_admin =
      case socket.assigns.current_user do
        nil -> false
        user -> user.role == :dragon
      end

    case Site.get_content_page_by_slug(slug) do
      nil ->
        {:ok, socket |> put_flash(:error, "404 Bullshit Not Found") |> push_redirect(to: "/")}

      page ->
        can_view = page.published || is_admin

        if can_view do
          can_edit = is_admin

          {:ok,
           socket
           |> assign(:page, page)
           # n.b. "can see content admin link"
           |> assign(:can_edit, can_edit)
           |> assign(:editing, false)}
        else
          {:ok,
           socket
           |> put_flash(:error, "403 The Dragon isn't ready to show you that one, yet.")
           |> push_redirect(to: "/")}
        end
    end
  end

  @impl true
  def handle_event(event, params, socket) do
    case forward_music_client_event(event, params, socket) do
      :not_music_event ->
        handle_content_event(event, params, socket)

      result ->
        result
    end
  end

  defp handle_content_event("start_edit", _, socket) do
    {:noreply, assign(socket, :editing, true)}
  end

  defp handle_content_event("cancel_edit", _, socket) do
    {:noreply, assign(socket, :editing, false)}
  end

  defp handle_content_event("save", %{"body" => body}, socket) do
    case Site.update_content_page(socket.assigns.page, %{body: body}) do
      {:ok, updated_page} ->
        {:noreply,
         socket
         |> assign(:page, updated_page)
         |> assign(:editing, false)
         |> put_flash(:info, "Page updated successfully")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update page")}
    end
  end

  defp handle_content_event(_event, _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info(msg, socket) do
    case forward_music_event(msg, socket) do
      :not_music_event ->
        handle_content_info(msg, socket)

      result ->
        result
    end
  end

  defp handle_content_info(_msg, socket) do
    {:noreply, socket}
  end
end
