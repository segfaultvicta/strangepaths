defmodule Strangepaths.Rumor.ChangeLogEntry do
  use Ecto.Schema
  import Ecto.Changeset

  @valid_actions ~w(node_created node_updated node_moved node_deleted connection_created connection_updated connection_deleted)

  schema "rumor_change_log" do
    field :action, :string
    field :node_id, :integer
    field :connection_id, :integer
    field :node_title, :string
    field :actor_nickname, :string
    field :details, :map, default: %{}

    belongs_to :actor, Strangepaths.Accounts.User

    timestamps(updated_at: false)
  end

  @doc false
  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [:action, :actor_id, :actor_nickname, :node_id, :connection_id, :node_title, :details])
    |> validate_required([:action])
    |> validate_inclusion(:action, @valid_actions)
    |> foreign_key_constraint(:actor_id)
  end
end
