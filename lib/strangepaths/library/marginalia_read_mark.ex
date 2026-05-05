defmodule Strangepaths.Library.MarginaliaReadMark do
  use Ecto.Schema

  schema "library_marginalia_read_marks" do
    belongs_to :user, Strangepaths.Accounts.User
    belongs_to :marginalia, Strangepaths.Library.Marginalia

    timestamps(updated_at: false)
  end
end
