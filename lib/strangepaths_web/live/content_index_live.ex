defmodule StrangepathsWeb.ContentIndexLive do
  use StrangepathsWeb, :live_view

  import StrangepathsWeb.MusicBroadcast
  alias Strangepaths.Site

  def mount(_params, session, socket) do
    socket = assign_defaults(session, socket)
    subscribe_to_music(socket)

    is_dragon =
      case socket.assigns.current_user do
        nil -> false
        user -> user.role == :dragon
      end

    logged_in = socket.assigns.current_user != nil

    {:ok,
     socket
     |> assign(:page_title, "Codex - Index")
     |> assign(:is_dragon, is_dragon)
     |> assign(:logged_in, logged_in)
     |> assign(:creating, false)
     |> assign(:creating_folder, false)
     |> assign(:renaming_folder, nil)
     |> assign(:current_folder_id, nil)
     |> assign(:breadcrumbs, [])
     |> assign(:folders, [])
     |> assign(:pages, [])}
  end

  def handle_params(params, _uri, socket) do
    folder_id =
      case params["folder"] do
        nil -> nil
        id -> String.to_integer(id)
      end

    {:noreply,
     socket
     |> assign(:current_folder_id, folder_id)
     |> assign(:breadcrumbs, Site.get_folder_breadcrumbs(folder_id))
     |> reload_contents()}
  end

  def handle_event(event, params, socket) do
    case forward_music_client_event(event, params, socket) do
      :not_music_event ->
        handle_content_event(event, params, socket)

      result ->
        result
    end
  end

  # --- Page creation (logged-in users) ---

  defp handle_content_event("start_create", _, socket) do
    {:noreply, assign(socket, :creating, true)}
  end

  defp handle_content_event("cancel_create", _, socket) do
    {:noreply, assign(socket, :creating, false)}
  end

  defp handle_content_event("create", %{"title" => title}, socket) do
    attrs = %{
      title: title,
      body: "# #{title}\n\nStart writing here...",
      published: true,
      folder_id: socket.assigns.current_folder_id
    }

    case Site.create_content_page(attrs) do
      {:ok, page} ->
        {:noreply,
         socket
         |> assign(:creating, false)
         |> push_redirect(to: "/content/#{page.slug}")}

      {:error, details} ->
        {:noreply, put_flash(socket, :error, "Failed to create page: #{inspect(details)}")}
    end
  end

  # --- Folder creation (logged-in users) ---

  defp handle_content_event("start_create_folder", _, socket) do
    {:noreply, assign(socket, :creating_folder, true)}
  end

  defp handle_content_event("cancel_create_folder", _, socket) do
    {:noreply, assign(socket, :creating_folder, false)}
  end

  defp handle_content_event("create_folder", %{"name" => name}, socket) do
    attrs = %{
      name: name,
      parent_id: socket.assigns.current_folder_id
    }

    case Site.create_folder(attrs) do
      {:ok, _folder} ->
        {:noreply,
         socket
         |> assign(:creating_folder, false)
         |> reload_contents()}

      {:error, details} ->
        {:noreply, put_flash(socket, :error, "Failed to create folder: #{inspect(details)}")}
    end
  end

  # --- Drag and drop (logged-in users) ---

  defp handle_content_event("drop_into_folder", %{"item_id" => id, "item_type" => type, "folder_id" => fid}, socket) do
    target_folder_id = String.to_integer(fid)
    item_id = String.to_integer(id)

    case type do
      "page" -> Site.move_page_to_folder(item_id, target_folder_id)
      "folder" -> Site.move_folder_to_parent(item_id, target_folder_id)
    end

    {:noreply, reload_contents(socket)}
  end

  defp handle_content_event("drop_into_parent", %{"item_id" => id, "item_type" => type}, socket) do
    item_id = String.to_integer(id)
    folder = Site.get_folder!(socket.assigns.current_folder_id)

    case type do
      "page" ->
        if folder.parent_id do
          Site.move_page_to_folder(item_id, folder.parent_id)
        else
          Site.move_page_to_root(item_id)
        end

      "folder" ->
        Site.move_folder_to_parent(item_id, folder.parent_id)
    end

    {:noreply, reload_contents(socket)}
  end

  # --- Dragon-only actions ---

  defp handle_content_event("toggle_published", %{"id" => id}, socket) do
    if socket.assigns.is_dragon do
      page = Site.get_content_page!(id)
      Site.update_content_page(page, %{published: !page.published})
      {:noreply, reload_contents(socket)}
    else
      {:noreply, socket}
    end
  end

  defp handle_content_event("toggle_render_mode", %{"id" => id}, socket) do
    if socket.assigns.is_dragon do
      page = Site.get_content_page!(id)
      new_mode = if page.render_mode == "markdown", do: "html", else: "markdown"
      Site.update_content_page(page, %{render_mode: new_mode})
      {:noreply, reload_contents(socket)}
    else
      {:noreply, socket}
    end
  end

  defp handle_content_event("delete", %{"id" => id}, socket) do
    if socket.assigns.is_dragon do
      page = Site.get_content_page!(id)
      Site.delete_content_page(page)
      {:noreply, reload_contents(socket)}
    else
      {:noreply, socket}
    end
  end

  defp handle_content_event("delete_folder", %{"id" => id}, socket) do
    if socket.assigns.is_dragon do
      folder = Site.get_folder!(String.to_integer(id))

      case Site.delete_folder(folder) do
        {:ok, _} ->
          {:noreply, reload_contents(socket)}

        {:error, :not_empty} ->
          {:noreply, put_flash(socket, :error, "Folder is not empty")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete folder")}
      end
    else
      {:noreply, socket}
    end
  end

  defp handle_content_event("start_rename_folder", %{"id" => id}, socket) do
    if socket.assigns.is_dragon do
      {:noreply, assign(socket, :renaming_folder, String.to_integer(id))}
    else
      {:noreply, socket}
    end
  end

  defp handle_content_event("cancel_rename_folder", _, socket) do
    {:noreply, assign(socket, :renaming_folder, nil)}
  end

  defp handle_content_event("rename_folder", %{"id" => id, "name" => name}, socket) do
    if socket.assigns.is_dragon do
      folder = Site.get_folder!(String.to_integer(id))
      Site.update_folder(folder, %{name: name})

      {:noreply,
       socket
       |> assign(:renaming_folder, nil)
       |> reload_contents()}
    else
      {:noreply, socket}
    end
  end

  defp handle_content_event(_event, _params, socket) do
    {:noreply, socket}
  end

  def handle_info(msg, socket) do
    case forward_music_event(msg, socket) do
      :not_music_event -> {:noreply, socket}
      result -> result
    end
  end

  defp reload_contents(socket) do
    published_only = !socket.assigns.is_dragon

    contents =
      case socket.assigns.current_folder_id do
        nil -> Site.list_root_folder_contents(published_only: published_only)
        id -> Site.list_folder_contents(id, published_only: published_only)
      end

    socket
    |> assign(:folders, contents.folders)
    |> assign(:pages, contents.pages)
  end
end
