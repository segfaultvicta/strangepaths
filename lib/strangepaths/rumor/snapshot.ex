defmodule Strangepaths.Rumor.Snapshot do
  use Ecto.Schema
  import Ecto.Changeset

  schema "rumor_snapshots" do
    field :label, :string
    field :nodes_data, :map
    field :connections_data, :map

    belongs_to :taken_by, Strangepaths.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(snapshot, attrs) do
    snapshot
    |> cast(attrs, [:label, :taken_by_id, :nodes_data, :connections_data])
    |> validate_required([:nodes_data, :connections_data])
    |> foreign_key_constraint(:taken_by_id)
  end
end
