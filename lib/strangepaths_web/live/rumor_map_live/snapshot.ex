defmodule StrangepathsWeb.RumorMapLive.Snapshot do
  use StrangepathsWeb, :live_view

  import StrangepathsWeb.MusicBroadcast

  alias Strangepaths.Rumor
  alias Strangepaths.Accounts

  @impl true
  def mount(%{"id" => id}, session, socket) do
    socket = assign_defaults(session, socket)
    subscribe_to_music(socket)

    snapshot = Rumor.get_snapshot!(id)

    nodes_data = Map.get(snapshot.nodes_data, "nodes", [])
    connections_data = Map.get(snapshot.connections_data, "connections", [])

    initial_zoom = 0.09
    center_world_x = 2029
    center_world_y = 358
    viewport_center_x = 960
    viewport_center_y = 464

    initial_pan_x = viewport_center_x - center_world_x * initial_zoom
    initial_pan_y = viewport_center_y - center_world_y * initial_zoom

    socket =
      socket
      |> assign(:page_title, "Snapshot: #{snapshot.label || "Rumor Map"}")
      |> assign(:snapshot, snapshot)
      |> assign(:nodes, nodes_data)
      |> assign(:connections, connections_data)
      |> assign(:pan_x, initial_pan_x)
      |> assign(:pan_y, initial_pan_y)
      |> assign(:zoom, initial_zoom)
      |> assign(:selected_node, nil)
      |> assign(:viewing_node_id, nil)
      |> assign(:viewport_width, nil)
      |> assign(:viewport_height, nil)

    # Draw connections on mount for connected clients
    socket =
      if connected?(socket) do
        Enum.reduce(connections_data, socket, fn conn, acc ->
          push_event(acc, "draw_connection", %{
            id: Map.get(conn, "id"),
            from_id: Map.get(conn, "from_node_id"),
            to_id: Map.get(conn, "to_node_id"),
            label: Map.get(conn, "label"),
            category: Map.get(conn, "from_node_color_category"),
            line_style: Map.get(conn, "line_style", %{})
          })
        end)
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_event(event, params, socket) do
    case forward_music_client_event(event, params, socket) do
      :not_music_event ->
        handle_snapshot_event(event, params, socket)

      result ->
        result
    end
  end

  defp handle_snapshot_event(
         "zoom",
         %{"delta" => delta, "mouseX" => mouse_x, "mouseY" => mouse_y},
         socket
       ) do
    old_zoom = socket.assigns.zoom
    new_zoom = max(0.05, min(5.0, old_zoom * delta))

    world_x_before = (mouse_x - socket.assigns.pan_x) / old_zoom
    world_y_before = (mouse_y - socket.assigns.pan_y) / old_zoom
    world_x_after = (mouse_x - socket.assigns.pan_x) / new_zoom
    world_y_after = (mouse_y - socket.assigns.pan_y) / new_zoom

    new_pan_x = socket.assigns.pan_x + (world_x_after - world_x_before) * new_zoom
    new_pan_y = socket.assigns.pan_y + (world_y_after - world_y_before) * new_zoom

    {:noreply,
     socket
     |> assign(:zoom, new_zoom)
     |> assign(:pan_x, new_pan_x)
     |> assign(:pan_y, new_pan_y)}
  end

  defp handle_snapshot_event("pan", %{"dx" => dx, "dy" => dy}, socket) do
    {:noreply,
     socket
     |> assign(:pan_x, socket.assigns.pan_x + dx)
     |> assign(:pan_y, socket.assigns.pan_y + dy)}
  end

  defp handle_snapshot_event("zoom_in", _params, socket) do
    {:noreply, assign(socket, :zoom, min(5.0, socket.assigns.zoom * 1.2))}
  end

  defp handle_snapshot_event("zoom_out", _params, socket) do
    {:noreply, assign(socket, :zoom, max(0.05, socket.assigns.zoom / 1.2))}
  end

  defp handle_snapshot_event("reset_view", _params, socket) do
    initial_zoom = 0.1
    center_world_x = 2029
    center_world_y = 968

    viewport_center_x =
      if socket.assigns.viewport_width, do: socket.assigns.viewport_width / 2, else: 960

    viewport_center_y =
      if socket.assigns.viewport_height, do: socket.assigns.viewport_height / 2, else: 464

    {:noreply,
     socket
     |> assign(:pan_x, viewport_center_x - center_world_x * initial_zoom)
     |> assign(:pan_y, viewport_center_y - center_world_y * initial_zoom)
     |> assign(:zoom, initial_zoom)}
  end

  defp handle_snapshot_event(
         "set_viewport_dimensions",
         %{"width" => width, "height" => height},
         socket
       ) do
    center_world_x = 2029
    center_world_y = 968

    {:noreply,
     socket
     |> assign(:viewport_width, width)
     |> assign(:viewport_height, height)
     |> assign(:pan_x, width / 2 - center_world_x * socket.assigns.zoom)
     |> assign(:pan_y, height / 2 - center_world_y * socket.assigns.zoom)}
  end

  defp handle_snapshot_event("node_clicked", %{"node-id" => node_id_str}, socket) do
    node_id = String.to_integer(node_id_str)
    node = Enum.find(socket.assigns.nodes, fn n -> Map.get(n, "id") == node_id end)

    {:noreply,
     socket
     |> assign(:viewing_node_id, node_id)
     |> assign(:selected_node, node)}
  end

  defp handle_snapshot_event("deselect_node", _params, socket) do
    {:noreply, assign(socket, :selected_node, nil)}
  end

  defp handle_snapshot_event("close_detail_panel", _params, socket) do
    {:noreply,
     socket
     |> assign(:viewing_node_id, nil)
     |> assign(:selected_node, nil)}
  end

  defp handle_snapshot_event("view_connected_node", %{"node-id" => node_id_str}, socket) do
    node_id = String.to_integer(node_id_str)
    node = Enum.find(socket.assigns.nodes, fn n -> Map.get(n, "id") == node_id end)

    if node do
      viewport_center_x =
        if socket.assigns.viewport_width, do: socket.assigns.viewport_width / 2, else: 960

      viewport_center_y =
        if socket.assigns.viewport_height, do: socket.assigns.viewport_height / 2, else: 464

      {:noreply,
       socket
       |> assign(:viewing_node_id, node_id)
       |> assign(:selected_node, node)
       |> assign(:pan_x, viewport_center_x - Map.get(node, "x") * socket.assigns.zoom)
       |> assign(:pan_y, viewport_center_y - Map.get(node, "y") * socket.assigns.zoom)}
    else
      {:noreply, socket}
    end
  end

  defp handle_snapshot_event(_event, _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info(msg, socket) do
    case forward_music_event(msg, socket) do
      :not_music_event -> {:noreply, socket}
      result -> result
    end
  end

  # Helper functions — same as show.ex

  defp get_font_family(color_category) do
    case color_category do
      "red" -> "Burning Gnosis"
      "blue" -> "Pellucid Gnosis"
      "green" -> "Flourishing Gnosis"
      "white" -> "Radiant Gnosis"
      "black" -> "Tenebrous Gnosis"
      "redacted" -> "Aletheia"
      _ -> "Aletheia"
    end
  end

  defp get_text_class(color_category) do
    case color_category do
      "red" -> "text-red-400"
      "blue" -> "text-blue-400"
      "green" -> "text-emerald-400"
      "white" -> "text-white"
      "black" -> "text-black"
      "redacted" -> "text-redacted"
      _ -> "text-white"
    end
  end

  defp get_border_class(color_category) do
    case color_category do
      "red" -> "red-500"
      "blue" -> "blue-500"
      "green" -> "emerald-500"
      "white" -> "white"
      "black" -> "black"
      "redacted" -> "black"
      _ -> "gray-500"
    end
  end

  defp get_bg_class(color_category) do
    case color_category do
      "red" -> "bg-red-900"
      "blue" -> "bg-blue-900"
      "green" -> "bg-emerald-900"
      "white" -> "bg-black"
      "black" -> "bg-purple-200"
      "redacted" -> "bg-purple-900"
      _ -> "bg-gray-500"
    end
  end

  defp get_avatar_path(nil), do: nil

  defp get_avatar_path(avatar_id) do
    avatar = Accounts.get_avatar!(avatar_id)
    avatar.filepath
  end
end
