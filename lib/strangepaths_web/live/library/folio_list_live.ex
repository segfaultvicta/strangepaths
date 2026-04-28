defmodule StrangepathsWeb.LibraryLive.FolioList do
  use StrangepathsWeb, :live_view

  alias Strangepaths.Library

  @impl true
  def mount(_params, session, socket) do
    socket = assign_defaults(session, socket)
    user = socket.assigns.current_user

    {:ok,
     socket
     |> assign(:page_title, "The Liminal Library")
     |> assign(:search_query, "")
     |> assign(:filter_author_id, nil)
     |> assign(:filter_tag, "")
     |> assign(:sort_by, :date)
     |> assign(:all_users, Library.list_folio_authors())
     |> assign(:folios, Library.search_folios([]))
     |> assign(:folio_changeset, nil)
     |> assign(:is_folio_editor, user != nil && Library.folio_editor?(user.id))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
  end

  defp apply_action(socket, :new, _params) do
    if socket.assigns.current_user && Library.folio_editor?(socket.assigns.current_user.id) do
      socket
      |> assign(:page_title, "New Folio")
      |> assign(:folio_changeset, Library.change_folio())
    else
      socket
      |> put_flash(:error, "You must be a folio editor to create folios.")
      |> push_redirect(to: "/library")
    end
  end

  @impl true
  def handle_event("validate_folio", %{"folio" => attrs}, socket) do
    changeset =
      Library.change_folio(%Strangepaths.Library.Folio{}, attrs)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :folio_changeset, changeset)}
  end

  def handle_event("create_folio", %{"folio" => attrs}, socket) do
    user = socket.assigns.current_user

    if user && Library.folio_editor?(user.id) do
      case Library.create_folio(user, attrs) do
        {:ok, folio} ->
          {:noreply,
           socket
           |> put_flash(:info, "Folio created.")
           |> push_redirect(to: "/library/#{folio.slug}/compose")}

        {:error, changeset} ->
          {:noreply, assign(socket, :folio_changeset, changeset)}
      end
    else
      {:noreply, socket |> put_flash(:error, "Unauthorized") |> push_redirect(to: "/library")}
    end
  end

  @impl true
  def handle_event("search", %{"query" => query, "tag" => tag, "author_id" => author_id_str, "sort_by" => sort_str}, socket) do
    sort_by = case sort_str do
      "title" -> :title
      "author" -> :author
      _ -> :date
    end

    author_id =
      case Integer.parse(author_id_str) do
        {id, ""} when id > 0 -> id
        _ -> nil
      end

    socket =
      socket
      |> assign(:search_query, query)
      |> assign(:filter_tag, tag)
      |> assign(:filter_author_id, author_id)
      |> assign(:sort_by, sort_by)
      |> rebuild_folios()

    {:noreply, socket}
  end

  defp rebuild_folios(socket) do
    opts =
      [
        query: socket.assigns.search_query,
        author_id: socket.assigns.filter_author_id,
        tag: socket.assigns.filter_tag,
        sort_by: socket.assigns.sort_by
      ]
      # Note: sort_by is always an atom (:date, :title, or :author) and never nil/empty,
      # so it always passes through the filter. If the default changes from :date, ensure
      # it remains truthy (an atom is always truthy, so any atom value works fine).
      |> Enum.reject(fn {_k, v} -> v == nil or v == "" end)

    assign(socket, :folios, Library.search_folios(opts))
  end
end
