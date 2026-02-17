defmodule Strangepaths.Scenes.SceneReadMark do
  use Ecto.Schema
  import Ecto.Changeset

  schema "scene_read_marks" do
    field(:last_read_at, :utc_datetime)

    belongs_to(:user, Strangepaths.Accounts.User)
    belongs_to(:scene, Strangepaths.Scenes.Scene)
  end

  def changeset(read_mark, attrs) do
    read_mark
    |> cast(attrs, [:user_id, :scene_id, :last_read_at])
    |> validate_required([:user_id, :scene_id, :last_read_at])
    |> unique_constraint([:user_id, :scene_id])
  end
end
