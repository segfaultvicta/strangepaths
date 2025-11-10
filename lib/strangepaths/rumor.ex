defmodule Strangepaths.Rumor do
  @moduledoc """
  The Rumor context - manages the global rumor map for the campaign.
  """

  import Ecto.Query, warn: false
  alias Strangepaths.Repo

  alias Strangepaths.Rumor.Node
  alias Strangepaths.Rumor.Connection

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
end
