defmodule Strangepaths.Library.FolioTag do
  use Ecto.Schema
  import Ecto.Changeset

  schema "library_folio_tags" do
    field(:tag, :string)
    belongs_to(:folio, Strangepaths.Library.Folio)

    timestamps()
  end

  def changeset(folio_tag, attrs) do
    folio_tag
    |> cast(attrs, [:folio_id, :tag])
    |> validate_required([:folio_id, :tag])
    |> validate_length(:tag, min: 1, max: 100)
    |> unique_constraint([:folio_id, :tag])
  end
end
