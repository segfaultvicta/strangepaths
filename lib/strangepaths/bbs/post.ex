defmodule Strangepaths.BBS.Post do
  use Ecto.Schema
  import Ecto.Changeset

  schema "bbs_posts" do
    field(:display_name, :string)
    field(:character_name, :string)
    field(:content, :string)
    field(:posted_at, :utc_datetime)
    field(:edited_at, :utc_datetime)
    belongs_to(:thread, Strangepaths.BBS.Thread)
    belongs_to(:user, Strangepaths.Accounts.User)
    belongs_to(:edited_by, Strangepaths.Accounts.User, foreign_key: :edited_by_id)

    timestamps()
  end

  def create_changeset(post, attrs) do
    post
    |> cast(attrs, [:thread_id, :user_id, :display_name, :character_name, :content, :posted_at])
    |> validate_required([
      :thread_id,
      :user_id,
      :display_name,
      :character_name,
      :content,
      :posted_at
    ])
    |> validate_length(:display_name, min: 1, max: 100)
    |> validate_length(:content, min: 1, max: 10_000)
  end

  def edit_changeset(post, attrs) do
    post
    |> cast(attrs, [:content, :edited_by_id])
    |> validate_required([:content])
    |> validate_length(:content, min: 1, max: 10_000)
    |> put_change(:edited_at, DateTime.utc_now() |> DateTime.truncate(:second))
  end
end
