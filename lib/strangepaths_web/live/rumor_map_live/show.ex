defmodule StrangepathsWeb.RumorMapLive.Show do
  use StrangepathsWeb, :live_view

  import StrangepathsWeb.MusicBroadcast

  alias Strangepaths.Rumor
  alias Strangepaths.Accounts

  @impl true
  def mount(_params, session, socket) do
    socket =
      assign_defaults(session, socket)
      |> assign(:avatar_picker_open, false)
      |> assign(:selected_avatar_id, nil)
      |> assign(:selected_avatar_filepath, nil)
      |> assign(:open_categories, [])

    subscribe_to_music(socket)

    if connected?(socket) do
      # Subscribe to rumor map updates
      StrangepathsWeb.Endpoint.subscribe("rumor_map")

      # Track user presence
      if socket.assigns.current_user do
        Strangepaths.Presence.track(self(), "rumor_map", socket.assigns.current_user.id, %{
          nickname: socket.assigns.current_user.nickname
        })
      end
    end

    nodes = Rumor.list_nodes()
    IO.inspect(nodes)
    connections = Rumor.list_connections()

    socket =
      socket
      |> assign(:nodes, nodes)
      |> assign(:connections, connections)
      |> assign(:pan_x, 950)
      |> assign(:pan_y, 500)
      |> assign(:zoom, 0.1)
      |> assign(:state, :viewing)
      |> assign(:editing_node_id, nil)
      |> assign(:connecting_from_node_id, nil)
      |> assign(:selected_node, nil)
      |> assign(:selected_connection, nil)

    # Draw existing connections on mount (for connected clients only)
    socket =
      if connected?(socket) do
        Enum.reduce(connections, socket, fn conn, acc ->
          push_event(acc, "draw_connection", connection_to_event(conn))
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
        handle_rumormap_event(event, params, socket)

      result ->
        result
    end
  end

  defp handle_rumormap_event(
         "zoom",
         %{"delta" => delta, "mouseX" => mouse_x, "mouseY" => mouse_y},
         socket
       ) do
    old_zoom = socket.assigns.zoom
    new_zoom = max(0.01, min(5.0, old_zoom * delta))

    # Calculate the world point under the mouse before zoom
    # Convert mouse position to world coordinates at old zoom
    world_x_before = (mouse_x - socket.assigns.pan_x) / old_zoom
    world_y_before = (mouse_y - socket.assigns.pan_y) / old_zoom

    # After zoom, we want the same world point under the mouse
    world_x_after = (mouse_x - socket.assigns.pan_x) / new_zoom
    world_y_after = (mouse_y - socket.assigns.pan_y) / new_zoom

    # Adjust pan to keep the world point under the cursor
    new_pan_x = socket.assigns.pan_x + (world_x_after - world_x_before) * new_zoom
    new_pan_y = socket.assigns.pan_y + (world_y_after - world_y_before) * new_zoom

    {:noreply,
     socket
     |> assign(:zoom, new_zoom)
     |> assign(:pan_x, new_pan_x)
     |> assign(:pan_y, new_pan_y)}
  end

  defp handle_rumormap_event("pan", %{"dx" => dx, "dy" => dy}, socket) do
    {:noreply,
     socket
     |> assign(:pan_x, socket.assigns.pan_x + dx)
     |> assign(:pan_y, socket.assigns.pan_y + dy)}
  end

  defp handle_rumormap_event("zoom_in", _params, socket) do
    new_zoom = min(5.0, socket.assigns.zoom * 1.2)
    {:noreply, assign(socket, :zoom, new_zoom)}
  end

  defp handle_rumormap_event("zoom_out", _params, socket) do
    new_zoom = max(0.01, socket.assigns.zoom / 1.2)
    {:noreply, assign(socket, :zoom, new_zoom)}
  end

  defp handle_rumormap_event("reset_view", _params, socket) do
    {:noreply,
     socket
     |> assign(:pan_x, 950)
     |> assign(:pan_y, 500)
     |> assign(:zoom, 0.1)}
  end

  defp handle_rumormap_event("create_node", %{"x" => x, "y" => y}, socket) do
    if socket.assigns.state == :viewing do
      attrs = %{
        x: x,
        y: y,
        title: "New Node",
        content: "",
        color_category: "red",
        created_by_id: socket.assigns.current_user.id
      }

      case Rumor.create_node(attrs) do
        {:ok, node} ->
          # Broadcast to other users
          StrangepathsWeb.Endpoint.broadcast("rumor_map", "node_created", %{node: node})

          {:noreply,
           socket
           |> assign(:nodes, [node | socket.assigns.nodes])}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to create node")}
      end
    else
      {:noreply, socket}
    end
  end

  defp handle_rumormap_event(
         "update_node_position",
         %{"node_id" => node_id_str, "x" => x, "y" => y},
         socket
       ) do
    node_id = String.to_integer(node_id_str)

    # Node might have been deleted while we were dragging it
    node = Enum.find(socket.assigns.nodes, &(&1.id == node_id))

    if node do
      case Rumor.update_node(node, %{x: x, y: y}) do
        {:ok, updated_node} ->
          # Broadcast to other users
          StrangepathsWeb.Endpoint.broadcast("rumor_map", "node_moved", %{
            node_id: node_id,
            x: x,
            y: y
          })

          # Update local state
          updated_nodes =
            Enum.map(socket.assigns.nodes, fn n ->
              if n.id == node_id, do: updated_node, else: n
            end)

          {:noreply, assign(socket, :nodes, updated_nodes)}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to update node position")}
      end
    else
      # Node was deleted, just ignore the position update
      {:noreply, socket}
    end
  end

  defp handle_rumormap_event("node_clicked", %{"node-id" => node_id_str}, socket) do
    node_id = String.to_integer(node_id_str)
    node = Enum.find(socket.assigns.nodes, &(&1.id == node_id))

    cond do
      socket.assigns.state == :connecting ->
        # Create connection from connecting_from_node_id to this node
        from_id = socket.assigns.connecting_from_node_id

        if from_id != node_id do
          case Rumor.create_connection(%{
                 from_node_id: from_id,
                 to_node_id: node_id,
                 created_by_id: socket.assigns.current_user.id
               }) do
            {:ok, connection} ->
              connection = Strangepaths.Repo.preload(connection, [:from_node, :to_node])

              StrangepathsWeb.Endpoint.broadcast("rumor_map", "connection_created", %{
                connection: connection
              })

              {:noreply,
               socket
               |> assign(:state, :viewing)
               |> assign(:connecting_from_node_id, nil)
               |> assign(:connections, [connection | socket.assigns.connections])
               |> push_event("draw_connection", connection_to_event(connection))
               |> put_flash(:info, "Connection created")}

            {:error, _changeset} ->
              {:noreply, put_flash(socket, :error, "Failed to create connection")}
          end
        else
          {:noreply, put_flash(socket, :error, "Cannot connect a node to itself")}
        end

      true ->
        # Just select the node
        {:noreply, assign(socket, :selected_node, node)}
    end
  end

  defp handle_rumormap_event("start_connecting", %{"node-id" => node_id_str}, socket) do
    node_id = String.to_integer(node_id_str)

    {:noreply,
     socket
     |> assign(:state, :connecting)
     |> assign(:connecting_from_node_id, node_id)
     |> put_flash(:info, "Click another node to create a connection")}
  end

  defp handle_rumormap_event("cancel_connecting", _params, socket) do
    {:noreply,
     socket
     |> assign(:state, :viewing)
     |> assign(:connecting_from_node_id, nil)
     |> clear_flash()}
  end

  defp handle_rumormap_event("start_editing_node", %{"node-id" => node_id_str}, socket) do
    node_id = String.to_integer(node_id_str)
    topic = "rumor_map:node:#{node_id}"

    # Check if anyone else is editing
    presences = Strangepaths.Presence.list(topic)

    if map_size(presences) > 0 do
      {_user_id, %{metas: [meta | _]}} = Enum.at(presences, 0)

      {:noreply, put_flash(socket, :error, "#{meta.nickname} is currently editing this node")}
    else
      # Claim the edit lock
      Strangepaths.Presence.track(self(), topic, socket.assigns.current_user.id, %{
        nickname: socket.assigns.current_user.nickname
      })

      node = Enum.find(socket.assigns.nodes, &(&1.id == node_id))

      {avatar_id, avatar_filepath} =
        if node.avatar_id != nil do
          avatar = Accounts.get_avatar!(node.avatar_id)
          {avatar.id, avatar.filepath}
        else
          {nil, nil}
        end

      {:noreply,
       socket
       |> assign(:editing_node_id, node_id)
       |> assign(:selected_avatar_id, avatar_id)
       |> assign(:selected_avatar_filepath, avatar_filepath)
       |> assign(:selected_node, node)}
    end
  end

  defp handle_rumormap_event("save_node", %{"node" => node_params}, socket) do
    node = Rumor.get_node!(socket.assigns.editing_node_id)

    node_params = Map.put(node_params, "avatar_id", socket.assigns.selected_avatar_id)
    IO.inspect(node_params)

    case Rumor.update_node(node, node_params) do
      {:ok, updated_node} ->
        # Release lock
        topic = "rumor_map:node:#{node.id}"
        Strangepaths.Presence.untrack(self(), topic, socket.assigns.current_user.id)

        # Broadcast update
        StrangepathsWeb.Endpoint.broadcast("rumor_map", "node_updated", %{
          node: updated_node
        })

        # Update local state
        updated_nodes =
          Enum.map(socket.assigns.nodes, fn n ->
            if n.id == updated_node.id, do: updated_node, else: n
          end)

        {:noreply,
         socket
         |> assign(:nodes, updated_nodes)
         |> assign(:editing_node_id, nil)
         |> assign(:selected_node, nil)
         |> assign(:selected_avatar_id, nil)
         |> assign(:selected_avatar_filepath, nil)
         |> put_flash(:info, "Node updated")}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp handle_rumormap_event("modal_content_clicked", _params, socket) do
    # No-op handler to prevent backdrop click from triggering
    {:noreply, socket}
  end

  defp handle_rumormap_event("cancel_editing", _params, socket) do
    if socket.assigns.editing_node_id do
      topic = "rumor_map:node:#{socket.assigns.editing_node_id}"
      Strangepaths.Presence.untrack(self(), topic, socket.assigns.current_user.id)
    end

    {:noreply,
     socket
     |> assign(:editing_node_id, nil)
     |> assign(:selected_node, nil)}
  end

  defp handle_rumormap_event("create_default_nodes", _params, socket) do
    if socket.assigns.current_user.role == :dragon do
      nodes = Rumor.create_default_nodes()

      # Broadcast to all users
      Enum.each(nodes, fn node ->
        StrangepathsWeb.Endpoint.broadcast("rumor_map", "node_created", %{node: node})
      end)

      {:noreply,
       socket
       |> assign(:nodes, Rumor.list_nodes())
       |> put_flash(:info, "Created #{length(nodes)} default anchor nodes")}
    else
      {:noreply, put_flash(socket, :error, "Unauthorized")}
    end
  end

  defp handle_rumormap_event("deselect_node", _params, socket) do
    {:noreply,
     socket
     |> assign(:selected_node, nil)
     |> assign(:selected_connection, nil)}
  end

  defp handle_rumormap_event(
         "connection_clicked",
         %{"connection-id" => connection_id_str},
         socket
       ) do
    connection_id = String.to_integer(connection_id_str)
    connection = Enum.find(socket.assigns.connections, &(&1.id == connection_id))

    {:noreply, assign(socket, :selected_connection, connection)}
  end

  defp handle_rumormap_event("clear_connection_selection", _params, socket) do
    {:noreply, assign(socket, :selected_connection, nil)}
  end

  defp handle_rumormap_event("delete_connection", %{"connection-id" => connection_id_str}, socket) do
    connection_id = String.to_integer(connection_id_str)
    connection = Enum.find(socket.assigns.connections, &(&1.id == connection_id))

    if connection do
      case Rumor.delete_connection(connection) do
        {:ok, _deleted_connection} ->
          StrangepathsWeb.Endpoint.broadcast("rumor_map", "connection_deleted", %{
            connection_id: connection_id
          })

          {:noreply,
           socket
           |> assign(
             :connections,
             Enum.reject(socket.assigns.connections, &(&1.id == connection_id))
           )
           |> assign(:selected_connection, nil)
           |> push_event("remove_connection", %{connection_id: connection_id})
           |> put_flash(:info, "Connection deleted")}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to delete connection")}
      end
    else
      {:noreply, assign(socket, :selected_connection, nil)}
    end
  end

  defp handle_rumormap_event("delete_node", %{"node-id" => node_id_str}, socket) do
    node_id = String.to_integer(node_id_str)

    # Find the node in our current state (might already be deleted)
    node = Enum.find(socket.assigns.nodes, &(&1.id == node_id))

    if node do
      case Rumor.delete_node(node) do
        {:ok, _deleted_node} ->
          # Delete any connections to/from this node
          connections_to_delete =
            Enum.filter(socket.assigns.connections, fn conn ->
              conn.from_node_id == node_id || conn.to_node_id == node_id
            end)

          Enum.each(connections_to_delete, &Rumor.delete_connection/1)

          StrangepathsWeb.Endpoint.broadcast("rumor_map", "node_deleted", %{node_id: node_id})

          {:noreply,
           socket
           |> assign(:nodes, Enum.reject(socket.assigns.nodes, &(&1.id == node_id)))
           |> assign(
             :connections,
             Enum.reject(socket.assigns.connections, fn conn ->
               conn.from_node_id == node_id || conn.to_node_id == node_id
             end)
           )
           |> assign(:selected_node, nil)
           |> push_event("remove_deleted_node_connections", %{node_id: node_id})
           |> push_event("remove_node_element", %{node_id: node_id})}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, reason)}
      end
    else
      # Node already deleted
      {:noreply,
       socket
       |> assign(:selected_node, nil)
       |> put_flash(:info, "Node already deleted")}
    end
  end

  defp handle_rumormap_event("open_avatar_picker", _, socket) do
    avatars_by_category =
      Strangepaths.Accounts.list_avatars_by_category(socket.assigns.current_user)

    {:noreply,
     socket
     |> assign(:avatar_picker_open, true)
     |> assign(:avatars_by_category, avatars_by_category)
     |> assign(:open_categories, [])}
  end

  defp handle_rumormap_event("close_avatar_picker", _, socket) do
    {:noreply, assign(socket, :avatar_picker_open, false)}
  end

  defp handle_rumormap_event("toggle_category", %{"category" => category}, socket) do
    open_categories = socket.assigns.open_categories

    new_open_categories =
      if category in open_categories do
        List.delete(open_categories, category)
      else
        [category | open_categories]
      end

    {:noreply, assign(socket, :open_categories, new_open_categories)}
  end

  defp handle_rumormap_event("select_avatar", %{"avatar-id" => avatar_id}, socket) do
    # look up avatar by ID
    avatar_id = String.to_integer(avatar_id)
    avatar = Accounts.get_avatar!(avatar_id)

    {:noreply,
     socket
     |> assign(:avatar_picker_open, false)
     |> assign(:selected_avatar_filepath, avatar.filepath)
     |> assign(:selected_avatar_id, avatar_id)}
  end

  defp handle_rumormap_event(event, params, socket) do
    IO.puts("Unhandled rumormap event: #{event} #{inspect(params)}")
    {:noreply, socket}
  end

  # Handle music broadcasts
  @impl true
  def handle_info(msg, socket) do
    case forward_music_event(msg, socket) do
      :not_music_event ->
        handle_rumormap_info(msg, socket)

      result ->
        result
    end
  end

  defp handle_rumormap_info(%{event: "node_created", payload: %{node: node}}, socket) do
    {:noreply, assign(socket, :nodes, [node | socket.assigns.nodes])}
  end

  defp handle_rumormap_info(
         %{event: "node_moved", payload: %{node_id: node_id, x: x, y: y}},
         socket
       ) do
    updated_nodes =
      Enum.map(socket.assigns.nodes, fn node ->
        if node.id == node_id do
          %{node | x: x, y: y}
        else
          node
        end
      end)

    {:noreply,
     socket
     |> assign(:nodes, updated_nodes)
     |> push_event("node_position_updated", %{node_id: node_id})}
  end

  defp handle_rumormap_info(%{event: "node_updated", payload: %{node: updated_node}}, socket) do
    updated_nodes =
      Enum.map(socket.assigns.nodes, fn node ->
        if node.id == updated_node.id, do: updated_node, else: node
      end)

    {:noreply, assign(socket, :nodes, updated_nodes)}
  end

  defp handle_rumormap_info(%{event: "node_deleted", payload: %{node_id: node_id}}, socket) do
    # Clear selected_node if the deleted node was selected
    new_selected_node =
      if socket.assigns.selected_node && socket.assigns.selected_node.id == node_id do
        nil
      else
        socket.assigns.selected_node
      end

    {:noreply,
     socket
     |> assign(:nodes, Enum.reject(socket.assigns.nodes, &(&1.id == node_id)))
     |> assign(
       :connections,
       Enum.reject(socket.assigns.connections, fn conn ->
         conn.from_node_id == node_id || conn.to_node_id == node_id
       end)
     )
     |> assign(:selected_node, new_selected_node)
     |> push_event("remove_deleted_node_connections", %{node_id: node_id})
     |> push_event("remove_node_element", %{node_id: node_id})}
  end

  defp handle_rumormap_info(
         %{event: "connection_created", payload: %{connection: connection}},
         socket
       ) do
    {:noreply,
     socket
     |> assign(:connections, [connection | socket.assigns.connections])
     |> push_event("draw_connection", connection_to_event(connection))}
  end

  defp handle_rumormap_info(
         %{event: "connection_deleted", payload: %{connection_id: connection_id}},
         socket
       ) do
    {:noreply,
     socket
     |> assign(:connections, Enum.reject(socket.assigns.connections, &(&1.id == connection_id)))
     |> assign(:selected_connection, nil)
     |> push_event("remove_connection", %{connection_id: connection_id})}
  end

  defp handle_rumormap_info(msg, socket) do
    IO.puts("unhandled rumor_map info: #{inspect(msg)}")
    {:noreply, socket}
  end

  # Helper functions

  defp connection_to_event(connection) do
    %{
      id: connection.id,
      from_id: connection.from_node_id,
      to_id: connection.to_node_id,
      label: connection.label,
      category: connection.from_node.color_category,
      line_style: connection.line_style || %{}
    }
  end

  defp get_border_class(color_category) do
    case color_category do
      "red" -> "red-500"
      "blue" -> "blue-500"
      "green" -> "emerald-500"
      "white" -> "white"
      # black-500 doesn't exist in Tailwind
      "black" -> "black"
      "secret" -> "yellow-500"
      _ -> "gray-500"
    end
  end

  defp get_bg_class(color_category) do
    case color_category do
      "red" -> "bg-red-200 dark:bg-red-800"
      "blue" -> "bg-blue-200 dark:bg-blue-800"
      "green" -> "bg-emerald-200 dark:bg-emerald-800"
      "white" -> "bg-gray-200 dark:bg-gray-800"
      "black" -> "bg-gray-200 dark:bg-gray-800"
      "secret" -> "bg-purple-200 dark:bg-purple-800"
      _ -> "bg-gray-500"
    end
  end

  defp get_avatar_path(nil), do: nil

  defp get_avatar_path(avatar_id) do
    avatar = Accounts.get_avatar!(avatar_id)
    avatar.filepath
  end
end
