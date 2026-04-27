defmodule StrangepathsWeb.LibraryLive.FolioList do
  use StrangepathsWeb, :live_view

  alias Strangepaths.Library

  @impl true
  def mount(_params, session, socket) do
    socket = assign_defaults(session, socket)
    user = socket.assigns.current_user
    folios = Library.list_folios()

    {:ok,
     socket
     |> assign(:page_title, "The Liminal Library")
     |> assign(:folios, folios)
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
      |> push_patch(to: "/library")
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
           |> push_redirect(to: "/library/#{folio.slug}")}

        {:error, changeset} ->
          {:noreply, assign(socket, :folio_changeset, changeset)}
      end
    else
      {:noreply, socket |> put_flash(:error, "Unauthorized") |> push_patch(to: "/library")}
    end
  end
end
