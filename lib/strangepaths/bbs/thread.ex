defmodule Strangepaths.BBS.Thread do
  @moduledoc """
  Thread schema.

  **Important**: last_post_at is maintained by Strangepaths.BBS and is always set by
  BBS.create_thread/3 and BBS.create_post/3. Never insert threads directly into the database.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "bbs_threads" do
    field(:title, :string)
    field(:is_pinned, :boolean, default: false)
    field(:is_locked, :boolean, default: false)
    field(:last_post_at, :utc_datetime)
    field(:post_count, :integer, default: 0)
    field(:display_name, :string, virtual: true)
    field(:content, :string, virtual: true)
    belongs_to(:board, Strangepaths.BBS.Board)
    belongs_to(:user, Strangepaths.Accounts.User)
    has_many(:posts, Strangepaths.BBS.Post)

    timestamps()
  end

  def create_changeset(thread, attrs) do
    thread
    |> cast(attrs, [:title, :board_id, :user_id, :display_name, :content])
    |> validate_required([:title, :board_id, :user_id])
    |> validate_length(:title, min: 1, max: 255)
    |> validate_format(:title, ~r/\S/, message: "cannot be blank or whitespace only")
    |> validate_length(:display_name, max: 100)
    |> validate_format(:display_name, ~r/\A[^"\[\]\n]*\z/,
      message: "cannot contain quotes, brackets, or newlines"
    )
    |> validate_length(:content, min: 1, max: 10_000)
    |> validate_required([:content])
  end

  def dragon_changeset(thread, attrs) do
    thread
    |> cast(attrs, [:is_pinned, :is_locked])
  end
end
