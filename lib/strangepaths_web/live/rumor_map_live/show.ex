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
      |> assign(:page_title, "Rumor Map")
      |> assign(:selected_avatar_id, nil)
      |> assign(:selected_avatar_filepath, nil)
      |> assign(:open_categories, [])
      |> assign(:editing_connection_id, nil)

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
    connections = Rumor.list_connections()

    Enum.each(connections, fn conn ->
      IO.puts("conn: #{conn.id} with label #{conn.label}")
    end)

    # Initial zoom level
    initial_zoom = 0.09

    # Center coordinates in world space (node position)
    center_world_x = 2029
    center_world_y = 358

    # Viewport center (approximate - based on typical screen ~1920x1080, 86vh)
    # Half of typical width
    viewport_center_x = 960
    # Half of 86% of 1080px
    viewport_center_y = 464

    # Calculate pan to center the world coordinates in viewport
    # Formula: pan = viewport_center - world_position * zoom
    initial_pan_x = viewport_center_x - center_world_x * initial_zoom
    initial_pan_y = viewport_center_y - center_world_y * initial_zoom

    socket =
      socket
      |> assign(:nodes, nodes)
      |> assign(:connections, connections)
      |> assign(:pan_x, initial_pan_x)
      |> assign(:pan_y, initial_pan_y)
      |> assign(:zoom, initial_zoom)
      |> assign(:state, :viewing)
      |> assign(:editing_node_id, nil)
      |> assign(:connecting_from_node_id, nil)
      |> assign(:selected_node, nil)
      |> assign(:viewing_node_id, nil)
      |> assign(:viewport_width, nil)
      |> assign(:viewport_height, nil)

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
    new_zoom = max(0.05, min(5.0, old_zoom * delta))

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
    new_zoom = max(0.05, socket.assigns.zoom / 1.2)
    {:noreply, assign(socket, :zoom, new_zoom)}
  end

  defp handle_rumormap_event("reset_view", _params, socket) do
    # Reset to centered view on world coordinates (2029, 968)
    initial_zoom = 0.1
    center_world_x = 2029
    center_world_y = 968

    # Use actual viewport dimensions if available, otherwise use defaults
    viewport_center_x =
      if socket.assigns.viewport_width, do: socket.assigns.viewport_width / 2, else: 960

    viewport_center_y =
      if socket.assigns.viewport_height, do: socket.assigns.viewport_height / 2, else: 464

    initial_pan_x = viewport_center_x - center_world_x * initial_zoom
    initial_pan_y = viewport_center_y - center_world_y * initial_zoom

    {:noreply,
     socket
     |> assign(:pan_x, initial_pan_x)
     |> assign(:pan_y, initial_pan_y)
     |> assign(:zoom, initial_zoom)}
  end

  defp handle_rumormap_event(
         "set_viewport_dimensions",
         %{"width" => width, "height" => height},
         socket
       ) do
    # Store viewport dimensions
    socket =
      socket
      |> assign(:viewport_width, width)
      |> assign(:viewport_height, height)

    # Recalculate pan to properly center on world coordinates
    center_world_x = 2029
    center_world_y = 968
    viewport_center_x = width / 2
    viewport_center_y = height / 2

    new_pan_x = viewport_center_x - center_world_x * socket.assigns.zoom
    new_pan_y = viewport_center_y - center_world_y * socket.assigns.zoom

    {:noreply,
     socket
     |> assign(:pan_x, new_pan_x)
     |> assign(:pan_y, new_pan_y)}
  end

  defp handle_rumormap_event("create_node", %{"x" => x, "y" => y}, socket) do
    if socket.assigns.state == :viewing do
      default_avatar = Strangepaths.Accounts.get_avatar_by_display_name("Question")

      attrs = %{
        x: trunc(x),
        y: trunc(y),
        title: "New Node",
        content: "",
        avatar_id:
          if default_avatar != nil do
            default_avatar.id
          else
            nil
          end,
        scale: 4.5,
        color_category: "redacted",
        created_by_id: socket.assigns.current_user.id
      }

      IO.inspect(attrs)

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

    x = trunc(x)
    y = trunc(y)
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

        from_node = Enum.find(socket.assigns.nodes, &(&1.id == from_id))
        default_color = color_category_to_hex(from_node.color_category)

        if from_id != node_id do
          attrs = %{
            from_node_id: from_id,
            to_node_id: node_id,
            created_by_id: socket.assigns.current_user.id,
            label: "",
            line_style: %{
              "color" => default_color,
              "size" => 2,
              "dash" => "solid",
              "label_position" => "middle"
            }
          }

          case Rumor.create_connection(attrs) do
            {:ok, connection} ->
              connection = Strangepaths.Repo.preload(connection, [:from_node, :to_node])

              StrangepathsWeb.Endpoint.broadcast("rumor_map", "connection_created", %{
                connection: connection
              })

              {:noreply,
               socket
               |> assign(:state, :viewing)
               |> assign(:connecting_from_node_id, nil)}

            {:error, _changeset} ->
              {:noreply, put_flash(socket, :error, "Failed to create connection")}
          end
        else
          {:noreply, put_flash(socket, :error, "Cannot connect a node to itself")}
        end

      true ->
        # Open detail panel for the node
        {:noreply,
         socket
         |> assign(:viewing_node_id, node_id)
         |> assign(:selected_node, node)}
    end
  end

  defp handle_rumormap_event("start_connecting", %{"node-id" => node_id_str}, socket) do
    node_id = String.to_integer(node_id_str)

    {:noreply,
     socket
     |> assign(:state, :connecting)
     |> assign(:connecting_from_node_id, node_id)}
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
         |> assign(:selected_avatar_filepath, nil)}

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

  defp handle_rumormap_event("close_detail_panel", _params, socket)
       when socket.assigns.editing_node_id != nil do
    # Release edit lock before clearing editing_node_id
    topic = "rumor_map:node:#{socket.assigns.editing_node_id}"
    Strangepaths.Presence.untrack(self(), topic, socket.assigns.current_user.id)

    {:noreply,
     socket
     |> assign(:editing_node_id, nil)
     |> assign(:viewing_node_id, nil)
     |> assign(:selected_node, nil)
     |> assign(:editing_connection_id, nil)}
  end

  defp handle_rumormap_event("close_detail_panel", _params, socket) do
    {:noreply,
     socket
     |> assign(:viewing_node_id, nil)
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
       |> assign(:nodes, Rumor.list_nodes())}
    else
      {:noreply, put_flash(socket, :error, "Unauthorized")}
    end
  end

  defp handle_rumormap_event("deselect_node", _params, socket) do
    # Clicking background deselects node and also cancels connecting state
    socket =
      socket
      |> assign(:selected_node, nil)

    socket =
      if socket.assigns.state == :connecting do
        socket
        |> assign(:state, :viewing)
        |> assign(:connecting_from_node_id, nil)
        |> clear_flash()
      else
        socket
      end

    {:noreply, socket}
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
           |> push_event("remove_connection", %{connection_id: connection_id})}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to delete connection")}
      end
    else
      {:noreply, socket}
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
       |> assign(:selected_node, nil)}
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

  defp handle_rumormap_event("unset_avatar", _params, socket) do
    {:noreply,
     socket
     |> assign(:selected_avatar_id, nil)
     |> assign(:selected_avatar_filepath, nil)}
  end

  defp handle_rumormap_event("view_connected_node", %{"node-id" => node_id_str}, socket) do
    node_id = String.to_integer(node_id_str)
    node = Enum.find(socket.assigns.nodes, &(&1.id == node_id))

    if node do
      # Use actual viewport dimensions if available, otherwise use defaults
      viewport_center_x =
        if socket.assigns.viewport_width, do: socket.assigns.viewport_width / 2, else: 960

      viewport_center_y =
        if socket.assigns.viewport_height, do: socket.assigns.viewport_height / 2, else: 464

      # Calculate pan to center the node in viewport
      # Formula: pan = viewport_center - (node_position * zoom)
      new_pan_x = viewport_center_x - node.x * socket.assigns.zoom
      new_pan_y = viewport_center_y - node.y * socket.assigns.zoom

      {:noreply,
       socket
       |> assign(:viewing_node_id, node_id)
       |> assign(:selected_node, node)
       |> assign(:pan_x, new_pan_x)
       |> assign(:pan_y, new_pan_y)}
    else
      {:noreply, socket}
    end
  end

  defp handle_rumormap_event(
         "start_editing_connection",
         %{"connection-id" => conn_id_str},
         socket
       ) do
    conn_id = String.to_integer(conn_id_str)
    connection_under_edit = Enum.find(socket.assigns.connections, &(&1.id == conn_id))

    {:noreply,
     assign(socket, :editing_connection_id, conn_id)
     |> assign(:connection_under_edit, connection_under_edit)}
  end

  defp handle_rumormap_event("cancel_editing_connection", _params, socket) do
    {:noreply, assign(socket, :editing_connection_id, nil)}
  end

  defp handle_rumormap_event("update_connection_style", params, socket) do
    conn_id = String.to_integer(params["connection_id"])
    connection = Rumor.get_connection!(conn_id)

    # Build line_style map from form params
    line_style = %{
      "color" => params["color"],
      "size" => String.to_integer(params["size"]),
      "dash" => params["dash"],
      "label_position" => params["label_position"]
    }

    attrs = %{
      label: params["label"],
      line_style: line_style
    }

    case Rumor.update_connection(connection, attrs) do
      {:ok, updated_connection} ->
        # Broadcast the update

        StrangepathsWeb.Endpoint.broadcast("rumor_map", "connection_updated", %{
          connection: updated_connection
        })

        # Update local state
        updated_connections =
          Enum.map(socket.assigns.connections, fn conn ->
            if conn.id == conn_id, do: updated_connection, else: conn
          end)

        {:noreply,
         socket
         |> assign(:connections, updated_connections)
         |> assign(:editing_connection_id, nil)
         |> push_event("update_connection", connection_to_event(updated_connection))}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update connection")}
    end
  end

  defp handle_rumormap_event("create_connection_from_modal", params, socket) do
    from_node_id = String.to_integer(params["from-node-id"])
    to_node_id = String.to_integer(params["to-node-id"])

    # Get the from_node to determine default color
    from_node = Enum.find(socket.assigns.nodes, &(&1.id == from_node_id))
    default_color = color_category_to_hex(from_node.color_category)

    attrs = %{
      from_node_id: from_node_id,
      to_node_id: to_node_id,
      created_by_id: socket.assigns.current_user.id,
      label: "",
      line_style: %{
        "color" => default_color,
        "size" => 2,
        "dash" => "solid",
        "label_position" => "middle"
      }
    }

    case Rumor.create_connection(attrs) do
      {:ok, connection} ->
        connection = Rumor.get_connection!(connection.id)

        StrangepathsWeb.Endpoint.broadcast("rumor_map", "connection_created", %{
          connection: connection
        })

        {:noreply, socket}

      {:error, changeset} ->
        error_msg =
          case changeset.errors do
            [{:to_node_id, {"cannot connect a node to itself", _}} | _] ->
              "Cannot connect a node to itself"

            _ ->
              "Failed to create connection"
          end

        {:noreply, put_flash(socket, :error, error_msg)}
    end
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
     |> push_event("remove_connection", %{connection_id: connection_id})}
  end

  defp handle_rumormap_info(
         %{event: "connection_updated", payload: %{connection: updated_connection}},
         socket
       ) do
    updated_connections =
      Enum.map(socket.assigns.connections, fn conn ->
        if conn.id == updated_connection.id, do: updated_connection, else: conn
      end)

    {:noreply,
     socket
     |> assign(:connections, updated_connections)
     |> push_event("update_connection", connection_to_event(updated_connection))}
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

  # Convert color category to hex color for connection defaults
  defp color_category_to_hex(color_category) do
    case color_category do
      "red" -> "#ef4444"
      "blue" -> "#3b82f6"
      "green" -> "#22c55e"
      "white" -> "#ceb900"
      "black" -> "#ffffff"
      "redacted" -> "#a855f7"
      _ -> "#9ca3af"
    end
  end

  defp get_avatar_path(nil), do: nil

  defp get_avatar_path(avatar_id) do
    avatar = Accounts.get_avatar!(avatar_id)
    avatar.filepath
  end

  # Get available nodes for creating a connection from the given node
  # Filters out self and already-connected nodes, sorted by proximity
  defp get_available_connection_targets(from_node, all_nodes, connections) do
    # Get IDs of nodes already connected to
    connected_node_ids =
      connections
      |> Enum.filter(&(&1.from_node_id == from_node.id))
      |> Enum.map(& &1.to_node_id)
      |> MapSet.new()

    # Filter and sort by distance
    all_nodes
    |> Enum.reject(fn node ->
      node.id == from_node.id || MapSet.member?(connected_node_ids, node.id)
    end)
    |> Enum.sort_by(fn node ->
      # Calculate Euclidean distance
      dx = node.x - from_node.x
      dy = node.y - from_node.y
      :math.sqrt(dx * dx + dy * dy)
    end)
  end
end
