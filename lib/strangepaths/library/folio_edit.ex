defmodule Strangepaths.Library.FolioEdit do
  use Ecto.Schema

  schema "library_folio_edits" do
    field :kind, :string
    field :summary, :string
    field :detail, :string
    field :inserted_at, :naive_datetime
    belongs_to :folio, Strangepaths.Library.Folio
    belongs_to :editor, Strangepaths.Accounts.User
  end
end
