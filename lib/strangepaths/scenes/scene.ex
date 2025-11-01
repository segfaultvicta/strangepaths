defmodule Strangepaths.Scenes.Scene do
  use Ecto.Schema
  import Ecto.Changeset

  schema "scenes" do
    field(:name, :string)
    field(:status, Ecto.Enum, values: [:active, :archived], default: :active)
    field(:locked_to_users, {:array, :integer}, default: [])
    field(:is_elsewhere, :boolean, default: false)
    field(:archived_at, :utc_datetime)

    belongs_to(:owner, Strangepaths.Accounts.User)
    has_many(:posts, Strangepaths.Scenes.Post, foreign_key: :scene_id)

    timestamps()
  end

  @doc """
  Changeset for creating a new scene.
  """
  def create_changeset(scene, attrs) do
    scene
    |> cast(attrs, [:name, :owner_id, :locked_to_users, :is_elsewhere])
    |> validate_required([:name, :owner_id])
    |> validate_length(:name, min: 1, max: 255)
    |> unique_constraint(:is_elsewhere,
      name: :only_one_elsewhere,
      message: "Only one Elsewhere scene can exist"
    )
  end

  def update_locked_users_changeset(scene, attrs) do
    scene
    |> cast(attrs, [:locked_to_users])
  end

  @doc """
  Changeset for archiving a scene.
  """
  def archive_changeset(scene) do
    scene
    |> change(status: :archived, archived_at: DateTime.utc_now() |> DateTime.truncate(:second))
  end

  @doc """
  Returns true if the scene is locked (private to specific users).
  """
  def locked?(%__MODULE__{locked_to_users: locked_to_users}) when is_list(locked_to_users) do
    length(locked_to_users) > 0
  end

  def locked?(_), do: false

  @doc """
  Returns true if the given user can view this scene.
  Dragon can see all scenes.
  Users can see public scenes (not locked).
  Users can see locked scenes if they're in the locked_to_users list.
  """
  def can_view?(%__MODULE__{}, %Strangepaths.Accounts.User{role: :dragon}), do: true
  def can_view?(%__MODULE__{locked_to_users: []}, %Strangepaths.Accounts.User{}), do: true

  def can_view?(%__MODULE__{locked_to_users: locked_users}, %Strangepaths.Accounts.User{
        id: user_id
      }) do
    user_id in locked_users
  end

  def can_view?(_, _), do: false
end
