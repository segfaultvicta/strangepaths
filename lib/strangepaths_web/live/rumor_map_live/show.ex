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
      |> assign(:archive_panel_open, false)
      |> assign(:recent_changes, [])
      |> assign(:recent_snapshots, [])
      |> assign(:layers, [])
      |> assign(:visible_layer_ids, MapSet.new())
      |> assign(:layer_panel_open, false)
      |> assign(:creating_layer, false)
      |> assign(:connection_sort_mode, :distance)

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

    layers = Rumor.list_layers()
    nodes = Rumor.list_nodes()
    connections = Rumor.list_connections()
    visible_layer_ids = layers |> Enum.map(& &1.id) |> MapSet.new()

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
      |> assign(:layers, layers)
      |> assign(:visible_layer_ids, visible_layer_ids)
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
    # Only draw connections where both endpoint nodes are on visible layers
    socket =
      if connected?(socket) do
        Enum.reduce(connections, socket, fn conn, acc ->
          if connection_visible?(conn, nodes, visible_layer_ids) do
            push_event(acc, "draw_connection", connection_to_event(conn))
          else
            acc
          end
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
    if socket.assigns.state == :viewing && socket.assigns.current_user do
      default_avatar = Strangepaths.Accounts.get_avatar_by_display_name("Question")

      # Pick the first visible layer, or the default layer
      default_layer_id =
        case Enum.find(socket.assigns.layers, fn l -> MapSet.member?(socket.assigns.visible_layer_ids, l.id) end) do
          nil -> case Rumor.get_default_layer() do
                   nil -> nil
                   layer -> layer.id
                 end
          layer -> layer.id
        end

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
        created_by_id: socket.assigns.current_user.id,
        layer_id: default_layer_id
      }

      case Rumor.create_node(attrs) do
        {:ok, node} ->
          # Broadcast to other users
          StrangepathsWeb.Endpoint.broadcast("rumor_map", "node_created", %{node: node})

          log_rumor_change(socket, "node_created", %{
            node_id: node.id,
            node_title: node.title,
            details: %{"color_category" => node.color_category, "x" => node.x, "y" => node.y}
          })

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

          # Only log moves that are more than trivial (>50px) to avoid click noise
          dx = x - node.x
          dy = y - node.y
          distance = :math.sqrt(dx * dx + dy * dy)

          if distance > 50 do
            log_rumor_change(socket, "node_moved", %{
              node_id: node_id,
              node_title: updated_node.title
            })
          end

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

              log_rumor_change(socket, "connection_created", %{
                connection_id: connection.id,
                details: %{
                  "from" => connection.from_node.title,
                  "to" => connection.to_node.title
                }
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

    node_params =
      node_params
      |> Map.put("avatar_id", socket.assigns.selected_avatar_id)

    case Rumor.update_node(node, node_params) do
      {:ok, updated_node} ->
        # Release lock
        topic = "rumor_map:node:#{node.id}"
        Strangepaths.Presence.untrack(self(), topic, socket.assigns.current_user.id)

        # Broadcast update
        StrangepathsWeb.Endpoint.broadcast("rumor_map", "node_updated", %{
          node: updated_node
        })

        # Build a diff of what actually changed
        changes =
          %{
            "title" => {node.title, updated_node.title},
            "content" => {node.content, updated_node.content},
            "color_category" => {node.color_category, updated_node.color_category},
            "image_url" => {node.image_url, updated_node.image_url},
            "avatar_id" => {node.avatar_id, updated_node.avatar_id}
          }
          |> Enum.reject(fn {_k, {old, new}} -> old == new end)
          |> Enum.map(fn {k, {old, new}} -> %{"field" => k, "from" => inspect(old), "to" => inspect(new)} end)

        log_rumor_change(socket, "node_updated", %{
          node_id: updated_node.id,
          node_title: node.title,
          details: %{"changes" => changes}
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

          log_rumor_change(socket, "connection_deleted", %{
            connection_id: connection_id,
            details: %{
              "from" => connection.from_node.title,
              "to" => connection.to_node.title
            }
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
          log_rumor_change(socket, "node_deleted", %{
            node_id: node_id,
            node_title: node.title
          })

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

  defp handle_rumormap_event("edit_node_form_changed", %{"node" => node_params}, socket) do
    selected_node = socket.assigns.selected_node

    updated_node =
      %{selected_node |
        title: Map.get(node_params, "title", selected_node.title),
        content: Map.get(node_params, "content", selected_node.content),
        image_url: Map.get(node_params, "image_url", selected_node.image_url),
        color_category: Map.get(node_params, "color_category", selected_node.color_category),
        layer_id: case Map.get(node_params, "layer_id") do
          nil -> selected_node.layer_id
          id -> String.to_integer(id)
        end,
        scale: case Map.get(node_params, "scale") do
          nil -> selected_node.scale
          "" -> selected_node.scale
          val ->
            {f, _} = Float.parse(val)
            f
        end,
        z_index: case Map.get(node_params, "z_index") do
          nil -> selected_node.z_index
          "" -> selected_node.z_index
          val -> String.to_integer(val)
        end,
        x: case Map.get(node_params, "x") do
          nil -> selected_node.x
          "" -> selected_node.x
          val -> String.to_integer(val)
        end,
        y: case Map.get(node_params, "y") do
          nil -> selected_node.y
          "" -> selected_node.y
          val -> String.to_integer(val)
        end,
        is_anchor: Map.get(node_params, "is_anchor", to_string(selected_node.is_anchor)) == "true"
      }

    {:noreply, assign(socket, :selected_node, updated_node)}
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

        updated_connection = Strangepaths.Repo.preload(updated_connection, [:from_node, :to_node])

        old_style = connection.line_style || %{}

        conn_changes =
          [
            if(connection.label != params["label"],
              do: %{"field" => "label", "from" => connection.label || "", "to" => params["label"] || ""}),
            if(old_style["color"] != params["color"],
              do: %{"field" => "color", "from" => old_style["color"] || "", "to" => params["color"]}),
            if(old_style["size"] != String.to_integer(params["size"]),
              do: %{"field" => "thickness", "from" => to_string(old_style["size"] || 2), "to" => params["size"]}),
            if(old_style["dash"] != params["dash"],
              do: %{"field" => "line style", "from" => old_style["dash"] || "solid", "to" => params["dash"]})
          ]
          |> Enum.reject(&is_nil/1)

        log_rumor_change(socket, "connection_updated", %{
          connection_id: updated_connection.id,
          details: %{
            "from" => updated_connection.from_node.title,
            "to" => updated_connection.to_node.title,
            "changes" => conn_changes
          }
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

  defp handle_rumormap_event("toggle_connection_sort", _params, socket) do
    new_mode =
      if socket.assigns.connection_sort_mode == :distance, do: :alpha, else: :distance

    {:noreply, assign(socket, :connection_sort_mode, new_mode)}
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

        log_rumor_change(socket, "connection_created", %{
          connection_id: connection.id,
          details: %{
            "from" => connection.from_node.title,
            "to" => connection.to_node.title
          }
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

  defp handle_rumormap_event("toggle_layer_panel", _params, socket) do
    {:noreply, assign(socket, :layer_panel_open, !socket.assigns.layer_panel_open)}
  end

  defp handle_rumormap_event("toggle_layer", %{"layer-id" => layer_id_str}, socket) do
    layer_id = String.to_integer(layer_id_str)
    visible = socket.assigns.visible_layer_ids

    new_visible =
      if MapSet.member?(visible, layer_id) do
        MapSet.delete(visible, layer_id)
      else
        MapSet.put(visible, layer_id)
      end

    socket =
      socket
      |> assign(:visible_layer_ids, new_visible)
      |> sync_connection_visibility(visible, new_visible)
      |> push_layer_visibility_saved()

    {:noreply, socket}
  end

  defp handle_rumormap_event("show_all_layers", _params, socket) do
    old_visible = socket.assigns.visible_layer_ids
    new_visible = socket.assigns.layers |> Enum.map(& &1.id) |> MapSet.new()

    socket =
      socket
      |> assign(:visible_layer_ids, new_visible)
      |> sync_connection_visibility(old_visible, new_visible)
      |> push_layer_visibility_saved()

    {:noreply, socket}
  end

  defp handle_rumormap_event("hide_all_layers", _params, socket) do
    old_visible = socket.assigns.visible_layer_ids
    new_visible = MapSet.new()

    socket =
      socket
      |> assign(:visible_layer_ids, new_visible)
      |> sync_connection_visibility(old_visible, new_visible)
      |> push_layer_visibility_saved()

    {:noreply, socket}
  end

  defp handle_rumormap_event("restore_layer_visibility", %{"hidden_ids" => hidden_ids}, socket) do
    all_layer_ids = socket.assigns.layers |> Enum.map(& &1.id) |> MapSet.new()
    # Only keep IDs that correspond to layers that still exist
    hidden_valid = hidden_ids |> Enum.filter(&MapSet.member?(all_layer_ids, &1)) |> MapSet.new()
    old_visible = socket.assigns.visible_layer_ids
    new_visible = MapSet.difference(all_layer_ids, hidden_valid)

    socket =
      socket
      |> assign(:visible_layer_ids, new_visible)
      |> sync_connection_visibility(old_visible, new_visible)

    {:noreply, socket}
  end

  defp handle_rumormap_event("start_creating_layer", _params, socket) do
    {:noreply, assign(socket, :creating_layer, true)}
  end

  defp handle_rumormap_event("cancel_creating_layer", _params, socket) do
    {:noreply, assign(socket, :creating_layer, false)}
  end

  defp handle_rumormap_event("create_layer", %{"name" => name}, socket) do
    if socket.assigns.current_user && String.trim(name) != "" do
      attrs = %{
        name: String.trim(name),
        sort_order: length(socket.assigns.layers),
        created_by_id: socket.assigns.current_user.id
      }

      case Rumor.create_layer(attrs) do
        {:ok, layer} ->
          StrangepathsWeb.Endpoint.broadcast("rumor_map", "layer_created", %{layer: layer})

          {:noreply,
           socket
           |> assign(:layers, socket.assigns.layers ++ [layer])
           |> assign(:visible_layer_ids, MapSet.put(socket.assigns.visible_layer_ids, layer.id))
           |> assign(:creating_layer, false)}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to create layer")}
      end
    else
      {:noreply, socket}
    end
  end

  defp handle_rumormap_event("rename_layer", %{"layer-id" => layer_id_str, "name" => name}, socket) do
    layer_id = String.to_integer(layer_id_str)
    layer = Rumor.get_layer!(layer_id)

    if can_manage_layer?(socket, layer) && String.trim(name) != "" do
      case Rumor.update_layer(layer, %{name: String.trim(name)}) do
        {:ok, updated_layer} ->
          StrangepathsWeb.Endpoint.broadcast("rumor_map", "layer_updated", %{layer: updated_layer})

          updated_layers =
            Enum.map(socket.assigns.layers, fn l ->
              if l.id == updated_layer.id, do: updated_layer, else: l
            end)

          {:noreply, assign(socket, :layers, updated_layers)}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to rename layer")}
      end
    else
      {:noreply, put_flash(socket, :error, "Unauthorized")}
    end
  end

  defp handle_rumormap_event("delete_layer", %{"layer-id" => layer_id_str}, socket) do
    layer_id = String.to_integer(layer_id_str)
    layer = Rumor.get_layer!(layer_id)

    if can_manage_layer?(socket, layer) do
      case Rumor.delete_layer(layer) do
        {:ok, _} ->
          StrangepathsWeb.Endpoint.broadcast("rumor_map", "layer_deleted", %{layer_id: layer_id})

          # Reload nodes since they may have been reassigned
          nodes = Rumor.list_nodes()

          {:noreply,
           socket
           |> assign(:layers, Enum.reject(socket.assigns.layers, &(&1.id == layer_id)))
           |> assign(:visible_layer_ids, MapSet.delete(socket.assigns.visible_layer_ids, layer_id))
           |> assign(:nodes, nodes)}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, reason)}
      end
    else
      {:noreply, put_flash(socket, :error, "Unauthorized")}
    end
  end

  defp handle_rumormap_event("toggle_archive_panel", _params, socket) do
    opening = !socket.assigns.archive_panel_open

    socket =
      if opening do
        socket
        |> assign(:archive_panel_open, true)
        |> assign(:recent_changes, Rumor.list_recent_changes(15))
        |> assign(:recent_snapshots, Rumor.list_snapshots() |> Enum.take(5))
      else
        assign(socket, :archive_panel_open, false)
      end

    {:noreply, socket}
  end

  defp handle_rumormap_event("take_snapshot", %{"label" => label}, socket) do
    %{nodes: nodes_data, connections: connections_data} = Rumor.build_snapshot_data()

    attrs = %{
      label: if(label == "", do: nil, else: label),
      taken_by_id: socket.assigns.current_user.id,
      nodes_data: %{"nodes" => nodes_data},
      connections_data: %{"connections" => connections_data}
    }

    case Rumor.create_snapshot(attrs) do
      {:ok, _snapshot} ->
        {:noreply,
         socket
         |> assign(:recent_snapshots, Rumor.list_snapshots() |> Enum.take(5))
         |> put_flash(:info, "Snapshot saved")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to save snapshot")}
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

  defp handle_rumormap_info(%{event: "layer_created", payload: %{layer: layer}}, socket) do
    if Enum.any?(socket.assigns.layers, &(&1.id == layer.id)) do
      {:noreply, socket}
    else
      {:noreply,
       socket
       |> assign(:layers, socket.assigns.layers ++ [layer])
       |> assign(:visible_layer_ids, MapSet.put(socket.assigns.visible_layer_ids, layer.id))}
    end
  end

  defp handle_rumormap_info(%{event: "layer_updated", payload: %{layer: updated_layer}}, socket) do
    updated_layers =
      Enum.map(socket.assigns.layers, fn l ->
        if l.id == updated_layer.id, do: updated_layer, else: l
      end)

    {:noreply, assign(socket, :layers, updated_layers)}
  end

  defp handle_rumormap_info(%{event: "layer_deleted", payload: %{layer_id: layer_id}}, socket) do
    # Reload nodes since they may have been reassigned to Default
    nodes = Rumor.list_nodes()

    {:noreply,
     socket
     |> assign(:layers, Enum.reject(socket.assigns.layers, &(&1.id == layer_id)))
     |> assign(:visible_layer_ids, MapSet.delete(socket.assigns.visible_layer_ids, layer_id))
     |> assign(:nodes, nodes)}
  end

  defp handle_rumormap_info(
         %{event: "presence_diff", payload: %{joins: _joins, leaves: _leaves}},
         socket
       ) do
    # Ignore for now, but handle the event
    {:noreply, socket}
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
      "green" -> "#43e106"
      "white" -> "#ceb900"
      "black" -> "#ffe6ff"
      "redacted" -> "#a855f7"
      _ -> "#9ca3af"
    end
  end

  defp get_avatar_path(nil), do: nil

  defp get_avatar_path(avatar_id) do
    avatar = Accounts.get_avatar!(avatar_id)
    avatar.filepath
  end

  defp log_rumor_change(socket, action, fields) do
    user = socket.assigns.current_user

    attrs =
      Map.merge(fields, %{
        action: action,
        actor_id: if(user, do: user.id),
        actor_nickname: if(user, do: user.nickname)
      })

    Task.start(fn ->
      case Rumor.log_change(attrs) do
        {:ok, _} -> :ok
        {:error, changeset} -> IO.warn("Failed to log rumor change: #{inspect(changeset.errors)}")
      end
    end)
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

  defp node_visible?(node, visible_layer_ids) do
    MapSet.member?(visible_layer_ids, node.layer_id)
  end

  defp connection_visible?(conn, nodes, visible_layer_ids) do
    from_node = Enum.find(nodes, &(&1.id == conn.from_node_id))
    to_node = Enum.find(nodes, &(&1.id == conn.to_node_id))

    from_node && to_node &&
      node_visible?(from_node, visible_layer_ids) &&
      node_visible?(to_node, visible_layer_ids)
  end

  defp sync_connection_visibility(socket, old_visible, new_visible) do
    if old_visible == new_visible do
      socket
    else
      nodes = socket.assigns.nodes

      Enum.reduce(socket.assigns.connections, socket, fn conn, acc ->
        was_visible = connection_visible?(conn, nodes, old_visible)
        now_visible = connection_visible?(conn, nodes, new_visible)

        cond do
          was_visible && !now_visible ->
            push_event(acc, "remove_connection", %{connection_id: conn.id})

          !was_visible && now_visible ->
            push_event(acc, "draw_connection", connection_to_event(conn))

          true ->
            acc
        end
      end)
    end
  end

  defp push_layer_visibility_saved(socket) do
    all_ids = socket.assigns.layers |> Enum.map(& &1.id) |> MapSet.new()
    hidden_ids = MapSet.difference(all_ids, socket.assigns.visible_layer_ids) |> MapSet.to_list()
    push_event(socket, "layer_visibility_saved", %{hidden_ids: hidden_ids})
  end

  defp can_manage_layer?(socket, layer) do
    user = socket.assigns.current_user

    user && (user.role == :dragon || layer.created_by_id == user.id)
  end

  defp layer_node_count(layer, nodes) do
    Enum.count(nodes, &(&1.layer_id == layer.id))
  end

  # Get available nodes for creating a connection from the given node
  # Filters out self and already-connected nodes, sorted by proximity or alphabetically
  defp get_available_connection_targets(from_node, all_nodes, connections, sort_mode \\ :distance) do
    # Get IDs of nodes already connected to
    connected_node_ids =
      connections
      |> Enum.filter(&(&1.from_node_id == from_node.id))
      |> Enum.map(& &1.to_node_id)
      |> MapSet.new()

    filtered =
      Enum.reject(all_nodes, fn node ->
        node.id == from_node.id || MapSet.member?(connected_node_ids, node.id)
      end)

    case sort_mode do
      :alpha ->
        Enum.sort_by(filtered, &String.downcase(&1.title))

      _ ->
        Enum.sort_by(filtered, fn node ->
          dx = node.x - from_node.x
          dy = node.y - from_node.y
          :math.sqrt(dx * dx + dy * dy)
        end)
    end
  end
end
