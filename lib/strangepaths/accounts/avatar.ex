defmodule Strangepaths.Accounts.Avatar do
  use Ecto.Schema
  import Ecto.Changeset

  schema "avatars" do
    field(:filepath, :string)
    field(:public, :boolean, default: false)
    field(:owner_id, :id)
    field(:selected, :boolean, virtual: true)
  end

  @doc false
  def changeset(avatar, attrs) do
    avatar
    |> cast(attrs, [:filepath, :public])
    |> validate_required([:filepath, :public])
  end
end
