defmodule Strangepaths.BBS.UserThreadSticky do
  use Ecto.Schema
  import Ecto.Changeset

  schema "bbs_user_thread_stickies" do
    belongs_to :user, Strangepaths.Accounts.User
    belongs_to :thread, Strangepaths.BBS.Thread

    timestamps(updated_at: false)
  end

  def changeset(sticky, attrs) do
    sticky
    |> cast(attrs, [:user_id, :thread_id])
    |> validate_required([:user_id, :thread_id])
    |> unique_constraint([:user_id, :thread_id])
  end
end
