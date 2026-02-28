defmodule Strangepaths.Rumor do
  @moduledoc """
  The Rumor context - manages the global rumor map for the campaign.
  """

  import Ecto.Query, warn: false
  alias Strangepaths.Repo

  alias Strangepaths.Rumor.Node
  alias Strangepaths.Rumor.Connection
  alias Strangepaths.Rumor.ChangeLogEntry
  alias Strangepaths.Rumor.Snapshot

  ## Nodes

  @doc """
  Returns the list of all nodes.
  """
  def list_nodes do
    Repo.all(from(n in Node, order_by: [desc: n.z_index, asc: n.inserted_at]))
  end

  @doc """
  Gets a single node.
  """
  def get_node!(id), do: Repo.get!(Node, id)

  @doc """
  Creates a node.
  """
  def create_node(attrs \\ %{}) do
    %Node{}
    |> Node.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a node.
  """
  def update_node(%Node{} = node, attrs) do
    node
    |> Node.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a node (only if it's not an anchor node).
  """
  def delete_node(%Node{is_anchor: true} = _node) do
    {:error, "Cannot delete anchor nodes"}
  end

  def delete_node(%Node{} = node) do
    Repo.delete(node)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking node changes.
  """
  def change_node(%Node{} = node, attrs \\ %{}) do
    Node.changeset(node, attrs)
  end

  @doc """
  Creates the five default anchor nodes in a star pattern.
  Should be called once when setting up the rumor map.
  """
  def create_default_nodes do
    import :math, only: [pi: 0, cos: 1, sin: 1]

    # Center point - expanded for infinite canvas
    center_x = 2450.0
    center_y = 500.0
    radius = 3500.0

    # Five-pointed star: each point is 72 degrees (2π/5) apart
    # Start at top (-90 degrees offset to point upward)
    nodes = [
      {"green", 0},
      {"blue", 1},
      {"black", 2},
      {"white", 3},
      {"red", 4}
    ]

    Enum.map(nodes, fn {color, index} ->
      angle = -pi() / 2 + index * 2 * pi() / 5
      x = center_x + radius * cos(angle)
      y = center_y + radius * sin(angle)

      {:ok, node} =
        create_node(%{
          x: x,
          y: y,
          z_index: 10,
          scale: 8.0,
          title: String.capitalize(color),
          content: "The #{color} anchor point.",
          color_category: color,
          is_anchor: true
        })

      node
    end)
  end

  ## Connections

  @doc """
  Returns all connections.
  """
  def list_connections do
    Repo.all(Connection)
    |> Repo.preload([:from_node, :to_node])
  end

  @doc """
  Gets a single connection.
  """
  def get_connection!(id) do
    Repo.get!(Connection, id)
    |> Repo.preload([:from_node, :to_node])
  end

  @doc """
  Creates a connection.
  """
  def create_connection(attrs \\ %{}) do
    %Connection{}
    |> Connection.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a connection.
  """
  def update_connection(%Connection{} = connection, attrs) do
    connection
    |> Connection.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a connection.
  """
  def delete_connection(%Connection{} = connection) do
    Repo.delete(connection)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking connection changes.
  """
  def change_connection(%Connection{} = connection, attrs \\ %{}) do
    Connection.changeset(connection, attrs)
  end

  ## Change Log

  def log_change(attrs) do
    %ChangeLogEntry{}
    |> ChangeLogEntry.changeset(attrs)
    |> Repo.insert()
  end

  def list_recent_changes(limit \\ 15) do
    from(e in ChangeLogEntry,
      order_by: [desc: e.inserted_at],
      limit: ^limit,
      select: [:id, :action, :actor_nickname, :node_id, :connection_id, :node_title, :details, :inserted_at]
    )
    |> Repo.all()
  end

  def list_all_changes do
    from(e in ChangeLogEntry,
      order_by: [desc: e.inserted_at],
      select: [:id, :action, :actor_nickname, :node_id, :connection_id, :node_title, :details, :inserted_at]
    )
    |> Repo.all()
  end

  ## Snapshots

  def create_snapshot(attrs) do
    %Snapshot{}
    |> Snapshot.changeset(attrs)
    |> Repo.insert()
  end

  def list_snapshots do
    from(s in Snapshot,
      order_by: [desc: s.inserted_at],
      preload: [:taken_by]
    )
    |> Repo.all()
  end

  def get_snapshot!(id) do
    Repo.get!(Snapshot, id)
    |> Repo.preload(:taken_by)
  end

  def delete_snapshot(%Snapshot{} = snapshot) do
    Repo.delete(snapshot)
  end

  def build_snapshot_data do
    nodes = list_nodes()
    connections = list_connections()

    nodes_data =
      Enum.map(nodes, fn n ->
        %{
          "id" => n.id,
          "x" => n.x,
          "y" => n.y,
          "z_index" => n.z_index,
          "scale" => n.scale,
          "title" => n.title,
          "content" => n.content,
          "image_url" => n.image_url,
          "color_category" => n.color_category,
          "is_anchor" => n.is_anchor,
          "avatar_id" => n.avatar_id
        }
      end)

    connections_data =
      Enum.map(connections, fn c ->
        %{
          "id" => c.id,
          "from_node_id" => c.from_node_id,
          "to_node_id" => c.to_node_id,
          "label" => c.label,
          "line_style" => c.line_style || %{},
          "from_node_title" => c.from_node.title,
          "to_node_title" => c.to_node.title,
          "from_node_color_category" => c.from_node.color_category
        }
      end)

    %{nodes: nodes_data, connections: connections_data}
  end
end
