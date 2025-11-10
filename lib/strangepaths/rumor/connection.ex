defmodule Strangepaths.Rumor.Connection do
  use Ecto.Schema
  import Ecto.Changeset

  schema "rumor_connections" do
    field :label, :string
    field :line_style, :map, default: %{}

    belongs_to :from_node, Strangepaths.Rumor.Node
    belongs_to :to_node, Strangepaths.Rumor.Node
    belongs_to :created_by, Strangepaths.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(connection, attrs) do
    connection
    |> cast(attrs, [:label, :line_style, :from_node_id, :to_node_id, :created_by_id])
    |> validate_required([:from_node_id, :to_node_id])
    |> foreign_key_constraint(:from_node_id)
    |> foreign_key_constraint(:to_node_id)
    |> validate_different_nodes()
  end

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
