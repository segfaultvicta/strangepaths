defmodule Strangepaths.BBS.ThreadReadMark do
  use Ecto.Schema
  import Ecto.Changeset

  schema "bbs_thread_read_marks" do
    field(:last_read_post_id, :integer)
    field(:last_read_at, :utc_datetime)
    belongs_to(:user, Strangepaths.Accounts.User)
    belongs_to(:thread, Strangepaths.BBS.Thread)

    timestamps()
  end

  def changeset(mark, attrs) do
    mark
    |> cast(attrs, [:user_id, :thread_id, :last_read_post_id, :last_read_at])
    |> validate_required([:user_id, :thread_id, :last_read_at])
    |> unique_constraint([:user_id, :thread_id])
  end
end
