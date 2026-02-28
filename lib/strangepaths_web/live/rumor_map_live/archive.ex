defmodule StrangepathsWeb.RumorMapLive.Archive do
  use StrangepathsWeb, :live_view

  import StrangepathsWeb.MusicBroadcast

  alias Strangepaths.Rumor

  @impl true
  def mount(_params, session, socket) do
    socket = assign_defaults(session, socket)
    subscribe_to_music(socket)

    if socket.assigns.current_user do
      {:ok,
       socket
       |> assign(:page_title, "Rumor Map Archive")
       |> assign(:snapshots, Rumor.list_snapshots())
       |> assign(:changes, Rumor.list_all_changes())
       |> assign(:viewing_snapshot, nil)}
    else
      {:ok,
       socket
       |> put_flash(:error, "You must be logged in to access the archive")
       |> redirect(to: "/")}
    end
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    snapshot = Rumor.get_snapshot!(id)
    {:noreply, assign(socket, :viewing_snapshot, snapshot)}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, :viewing_snapshot, nil)}
  end

  @impl true
  def handle_event(event, params, socket) do
    case forward_music_client_event(event, params, socket) do
      :not_music_event ->
        handle_archive_event(event, params, socket)

      result ->
        result
    end
  end

  defp handle_archive_event("delete_snapshot", %{"id" => id}, socket) do
    if socket.assigns.current_user.role == :dragon do
      snapshot = Rumor.get_snapshot!(String.to_integer(id))

      case Rumor.delete_snapshot(snapshot) do
        {:ok, _} ->
          {:noreply,
           socket
           |> assign(:snapshots, Rumor.list_snapshots())
           |> put_flash(:info, "Snapshot deleted")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete snapshot")}
      end
    else
      {:noreply, put_flash(socket, :error, "Unauthorized")}
    end
  end

  defp handle_archive_event(_event, _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info(msg, socket) do
    case forward_music_event(msg, socket) do
      :not_music_event -> {:noreply, socket}
      result -> result
    end
  end

  defp format_change_action(action) do
    case action do
      "node_created" -> "created node"
      "node_updated" -> "updated node"
      "node_moved" -> "moved node"
      "node_deleted" -> "deleted node"
      "connection_created" -> "connected"
      "connection_updated" -> "updated connection"
      "connection_deleted" -> "disconnected"
      _ -> action
    end
  end
end
