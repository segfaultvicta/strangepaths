defmodule Strangepaths.Accounts.Avatar do
  use Ecto.Schema
  import Ecto.Changeset

  schema "avatars" do
    field(:filepath, :string)
    field(:public, :boolean, default: false)
    field(:category, :string, default: "general")
    field(:display_name, :string)
  end

  @doc false
  def changeset(avatar, attrs) do
    avatar
    |> cast(attrs, [:filepath, :public, :category, :display_name])
    |> validate_required([:filepath])
  end
end
