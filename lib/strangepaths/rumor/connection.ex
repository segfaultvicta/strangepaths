defmodule Strangepaths.Rumor.Connection do
  use Ecto.Schema
  import Ecto.Changeset

  schema "rumor_connections" do
    field :label, :string
    field :line_style, :map, default: %{}
    field :waypoints, {:array, :map}, default: []

    belongs_to :from_node, Strangepaths.Rumor.Node
    belongs_to :to_node, Strangepaths.Rumor.Node
    belongs_to :created_by, Strangepaths.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(connection, attrs) do
    connection
    |> cast(attrs, [:label, :line_style, :waypoints, :from_node_id, :to_node_id, :created_by_id])
    |> validate_required([:from_node_id, :to_node_id])
    |> foreign_key_constraint(:from_node_id)
    |> foreign_key_constraint(:to_node_id)
    |> validate_different_nodes()
    |> validate_waypoints()
  end

  defp validate_waypoints(changeset) do
    validate_change(changeset, :waypoints, fn :waypoints, waypoints ->
      if Enum.all?(waypoints, &valid_waypoint?/1) do
        []
      else
        [waypoints: "each waypoint must have numeric x and y"]
      end
    end)
  end

  defp valid_waypoint?(%{"x" => x, "y" => y}), do: is_number(x) and is_number(y)
  defp valid_waypoint?(_), do: false

  defp validate_different_nodes(changeset) do
    from_id = get_field(changeset, :from_node_id)
    to_id = get_field(changeset, :to_node_id)

    if from_id && to_id && from_id == to_id do
      add_error(changeset, :to_node_id, "cannot connect a node to itself")
    else
      changeset
    end
  end
end
