defmodule StrangepathsWeb.LibraryLive.Folio do
  use StrangepathsWeb, :live_view
  import StrangepathsWeb.SceneHelpers, only: [render_post_content: 1]

  alias Strangepaths.Library

  @impl true
  def mount(%{"slug" => slug}, session, socket) do
    socket = assign_defaults(session, socket)

    case Library.get_folio_by_slug(slug) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Folio not found.")
         |> push_redirect(to: "/library")}

      folio ->
        user = socket.assigns.current_user
        entries = Library.list_entries(folio.id)
        tags = Library.list_tags(folio.id)

        {:ok,
         socket
         |> assign(:page_title, folio.title)
         |> assign(:folio, folio)
         |> assign(:entries, entries)
         |> assign(:tags, tags)
         |> assign(:editing_title, false)
         |> assign(:title_changeset, Library.change_folio(folio))
         |> assign(:is_author, user != nil && folio.user_id == user.id)
         |> assign(:is_dragon, user != nil && user.role == :dragon)}
    end
  end

  @impl true
  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  @impl true
  def handle_event("start_edit_title", _params, socket) do
    if socket.assigns.is_author || socket.assigns.is_dragon do
      {:noreply, assign(socket, :editing_title, true)}
    else
      {:noreply, put_flash(socket, :error, "Unauthorized.")}
    end
  end

  def handle_event("cancel_edit_title", _params, socket) do
    {:noreply, assign(socket, :editing_title, false)}
  end

  def handle_event("save_title", %{"folio" => attrs}, socket) do
    if socket.assigns.is_author || socket.assigns.is_dragon do
      case Library.update_folio_title(socket.assigns.folio, attrs) do
        {:ok, updated_folio} ->
          # update_folio_title preserves the :user preload from the in-memory struct
          {:noreply,
           socket
           |> assign(:folio, updated_folio)
           |> assign(:editing_title, false)
           |> assign(:title_changeset, Library.change_folio(updated_folio))
           |> push_patch(to: "/library/#{updated_folio.slug}")}

        {:error, changeset} ->
          {:noreply, assign(socket, :title_changeset, changeset)}
      end
    else
      {:noreply, put_flash(socket, :error, "Unauthorized.")}
    end
  end

  def handle_event("delete_folio", _params, socket) do
    if socket.assigns.is_dragon do
      Library.delete_folio(socket.assigns.folio)

      {:noreply,
       socket
       |> put_flash(:info, "Folio deleted.")
       |> push_redirect(to: "/library")}
    else
      {:noreply, put_flash(socket, :error, "Unauthorized.")}
    end
  end
end
