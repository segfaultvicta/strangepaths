defmodule Strangepaths.BBS.Thread do
  use Ecto.Schema
  import Ecto.Changeset

  schema "bbs_threads" do
    field :title, :string
    field :is_pinned, :boolean, default: false
    field :is_locked, :boolean, default: false
    field :last_post_at, :utc_datetime
    field :post_count, :integer, default: 0
    belongs_to :board, Strangepaths.BBS.Board
    belongs_to :user, Strangepaths.Accounts.User
    has_many :posts, Strangepaths.BBS.Post

    timestamps()
  end

  def create_changeset(thread, attrs) do
    thread
    |> cast(attrs, [:title, :board_id, :user_id])
    |> validate_required([:title, :board_id, :user_id])
    |> validate_length(:title, min: 1, max: 255)
  end

  def dragon_changeset(thread, attrs) do
    thread
    |> cast(attrs, [:is_pinned, :is_locked])
  end
end
