defmodule Strangepaths.Library.Folio do
  use Ecto.Schema
  import Ecto.Changeset

  schema "library_folios" do
    field(:title, :string)
    field(:slug, :string)
    field(:subtitle, :string)
    field(:body, :string)
    field(:body_locked_at, :utc_datetime)

    belongs_to(:user, Strangepaths.Accounts.User)
    belongs_to(:body_locked_by, Strangepaths.Accounts.User, foreign_key: :body_locked_by_id)
    has_many(:entries, Strangepaths.Library.Entry)
    has_many(:tags, Strangepaths.Library.FolioTag)

    timestamps()
  end

  def create_changeset(folio, attrs) do
    folio
    |> cast(attrs, [:user_id, :title, :subtitle, :body])
    |> validate_required([:user_id, :title])
    |> validate_length(:title, min: 1, max: 200)
    |> validate_length(:subtitle, max: 400)
    |> put_slug()
    |> unique_constraint(:title)
    |> unique_constraint(:slug)
  end

  def title_changeset(folio, attrs) do
    folio
    |> cast(attrs, [:title, :subtitle])
    |> validate_required([:title])
    |> validate_length(:title, min: 1, max: 200)
    |> validate_length(:subtitle, max: 400)
    |> put_slug()
    |> unique_constraint(:title)
    |> unique_constraint(:slug)
  end

  def body_changeset(folio, attrs) do
    folio
    |> cast(attrs, [:body, :body_locked_by_id, :body_locked_at])
  end

  defp put_slug(changeset) do
    case get_change(changeset, :title) do
      nil -> changeset
      title -> put_change(changeset, :slug, Slug.slugify(title))
    end
  end
end
