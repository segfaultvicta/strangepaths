defmodule Strangepaths.Scenes.Post do
  use Ecto.Schema
  import Ecto.Changeset

  schema "scene_posts" do
    field(:content, :string)
    field(:ooc_content, :string)
    field(:content_stripped, :string)
    field(:ooc_content_stripped, :string)
    field(:post_type, Ecto.Enum, values: [:character, :narrative, :system], default: :character)
    field(:narrative_author_name, :string)
    field(:color_category, :string, default: "redacted")
    field(:posted_at, :utc_datetime)

    belongs_to(:scene, Strangepaths.Scenes.Scene)
    belongs_to(:user, Strangepaths.Accounts.User)
    belongs_to(:avatar, Strangepaths.Accounts.Avatar)

    timestamps()
  end

  @doc """
  Changeset for creating a character post (regular user post with avatar).
  """
  def character_changeset(post, attrs) do
    post
    |> cast(attrs, [
      :scene_id,
      :user_id,
      :avatar_id,
      :content,
      :ooc_content,
      :narrative_author_name,
      :color_category
    ])
    |> validate_required([:scene_id, :user_id, :content])
    |> validate_length(:content, min: 1, max: 10000)
    |> validate_length(:ooc_content, max: 2000)
    |> put_change(:post_type, :character)
    |> put_change(:posted_at, DateTime.utc_now() |> DateTime.truncate(:second))
    |> foreign_key_constraint(:scene_id)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:avatar_id)
  end

  @doc """
  Changeset for creating a narrative post (Dragon post with custom attribution).
  """
  def narrative_changeset(post, attrs) do
    post
    |> cast(attrs, [:scene_id, :user_id, :avatar_id, :content, :color_category])
    |> validate_required([:scene_id, :user_id, :content])
    |> validate_length(:content, min: 1, max: 10000)
    |> validate_length(:ooc_content, max: 2000)
    |> validate_length(:narrative_author_name, max: 255)
    |> put_change(:post_type, :narrative)
    |> put_change(:posted_at, DateTime.utc_now() |> DateTime.truncate(:second))
    |> foreign_key_constraint(:scene_id)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:avatar_id)
  end

  @doc """
  Changeset for creating a system post (automated message).
  """
  def system_changeset(post, attrs) do
    post
    |> cast(attrs, [:scene_id, :content])
    |> validate_required([:scene_id, :content])
    |> validate_length(:content, min: 1, max: 10000)
    |> put_change(:post_type, :system)
    |> put_change(:posted_at, DateTime.utc_now() |> DateTime.truncate(:second))
    |> foreign_key_constraint(:scene_id)
  end
end
