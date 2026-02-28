defmodule Strangepaths.Rumor.Layer do
  use Ecto.Schema
  import Ecto.Changeset

  schema "rumor_layers" do
    field :name, :string
    field :sort_order, :integer, default: 0

    belongs_to :created_by, Strangepaths.Accounts.User
    has_many :nodes, Strangepaths.Rumor.Node

    timestamps()
  end

  @doc false
  def changeset(layer, attrs) do
    layer
    |> cast(attrs, [:name, :sort_order, :created_by_id])
    |> validate_required([:name])
  end
end
