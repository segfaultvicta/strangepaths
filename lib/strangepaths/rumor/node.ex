defmodule Strangepaths.Rumor.Node do
  use Ecto.Schema
  import Ecto.Changeset

  schema "rumor_nodes" do
    field(:x, :integer)
    field(:y, :integer)
    field(:z_index, :integer, default: 0)
    field(:scale, :float, default: 4.5)
    field(:title, :string)
    field(:content, :string)
    field(:image_url, :string)
    field(:color_category, :string)
    field(:is_anchor, :boolean, default: false)
    field(:avatar_only, :boolean, default: false)

    field(:avatar_id, :id)
    belongs_to(:created_by, Strangepaths.Accounts.User)

    has_many(:connections_from, Strangepaths.Rumor.Connection, foreign_key: :from_node_id)
    has_many(:connections_to, Strangepaths.Rumor.Connection, foreign_key: :to_node_id)

    timestamps()
  end

  @doc false
  def changeset(node, attrs) do
    node
    |> cast(attrs, [
      :x,
      :y,
      :z_index,
      :scale,
      :title,
      :content,
      :image_url,
      :color_category,
      :is_anchor,
      :avatar_only,
      :avatar_id,
      :created_by_id
    ])
    |> validate_required([:x, :y, :title, :color_category])
    |> validate_inclusion(:color_category, ["red", "blue", "green", "white", "black", "redacted"])
    |> validate_number(:scale, greater_than: 0, less_than_or_equal_to: 20)
  end
end
