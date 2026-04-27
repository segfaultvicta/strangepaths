defmodule StrangepathsWeb.LibraryLive.Folio do
  use StrangepathsWeb, :live_view
  import StrangepathsWeb.SceneHelpers, only: [render_post_content: 1]

  alias Strangepaths.Library

  @lock_timeout_ms Library.lock_timeout_seconds() * 1_000

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
         |> assign(:is_dragon, user != nil && user.role == :dragon)
         |> assign(:is_folio_editor, user != nil && Library.folio_editor?(user.id))
         |> assign(:editing_body, false)
         |> assign(:body_content, folio.body || "")
         |> assign(:preview_html, render_library_content(folio.body || ""))
         |> assign(:editor_typefaces, if(user, do: Library.folio_editor_typefaces(user.id), else: []))}
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

  def handle_event("claim_body_lock", _params, socket) do
    user = socket.assigns.current_user
    folio = socket.assigns.folio

    if socket.assigns.is_folio_editor do
      case Library.claim_body_lock(folio.id, user.id) do
        :ok ->
          Process.send_after(self(), :body_lock_timeout, @lock_timeout_ms)

          {:noreply,
           socket
           |> assign(:editing_body, true)
           |> assign(:body_content, folio.body || "")}

        {:error, :locked} ->
          {:noreply, put_flash(socket, :error, "Another editor is currently editing the body.")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("cancel_edit_body", _params, socket) do
    Library.release_body_lock(socket.assigns.folio.id)
    {:noreply, assign(socket, :editing_body, false)}
  end

  def handle_event("update_preview", %{"folio" => %{"body" => content}}, socket) do
    {:noreply,
     socket
     |> assign(:body_content, content)
     |> assign(:preview_html, render_library_content(content))}
  end

  def handle_event("save_body", %{"folio" => %{"body" => content}}, socket) do
    if socket.assigns.is_folio_editor do
      case Library.save_body(socket.assigns.folio, socket.assigns.current_user.id, content) do
        :ok ->
          updated_folio = %{socket.assigns.folio | body: content}

          {:noreply,
           socket
           |> assign(:folio, updated_folio)
           |> assign(:editing_body, false)
           |> assign(:preview_html, render_library_content(content))}

        {:error, :lock_lost} ->
          {:noreply, put_flash(socket, :error, "Lock was lost. Your changes were not saved. Please try again.")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(:body_lock_timeout, socket) do
    if socket.assigns[:editing_body] do
      Library.release_body_lock(socket.assigns.folio.id)

      {:noreply,
       socket
       |> assign(:editing_body, false)
       |> put_flash(:warning, "Body editing session timed out. Changes were not saved.")}
    else
      {:noreply, socket}
    end
  end
end
