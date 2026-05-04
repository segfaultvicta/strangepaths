defmodule Strangepaths.Library.FolioReadMark do
  use Ecto.Schema
  import Ecto.Changeset

  schema "library_folio_read_marks" do
    field(:last_visited_at, :naive_datetime)

    belongs_to(:user, Strangepaths.Accounts.User)
    belongs_to(:folio, Strangepaths.Library.Folio)

    timestamps()
  end

  def changeset(read_mark, attrs) do
    read_mark
    |> cast(attrs, [:user_id, :folio_id, :last_visited_at])
    |> validate_required([:user_id, :folio_id, :last_visited_at])
  end
end
