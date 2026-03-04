defmodule Strangepaths.Site.ContentPage do
  use Ecto.Schema
  import Ecto.Changeset

  schema "content_pages" do
    field(:title, :string)
    field(:slug, :string)
    field(:body, :string)
    field(:title_stripped, :string)
    field(:body_stripped, :string)
    field(:published, :boolean, default: false)
    field(:render_mode, :string, default: "markdown")
    field(:sort_order, :integer, default: 0)

    belongs_to(:folder, Strangepaths.Site.ContentFolder, foreign_key: :folder_id)

    timestamps()
  end

  def changeset(page, attrs) do
    page
    |> cast(attrs, [:title, :slug, :body, :published, :render_mode, :sort_order, :folder_id])
    |> maybe_generate_slug()
    |> validate_required([:title, :slug, :body])
    |> validate_inclusion(:render_mode, ["markdown", "html"])
    |> unique_constraint(:slug)
  end

  defp maybe_generate_slug(changeset) do
    case get_change(changeset, :slug) do
      nil ->
        title = get_change(changeset, :title) || get_field(changeset, :title)

        case title do
          "" -> changeset
          nil -> changeset
          title -> put_change(changeset, :slug, slugify(title))
        end

      _ ->
        changeset
    end
  end

  defp slugify(title) do
    title
    |> String.downcase()
    |> String.replace(~r/[^\w\s-]/, "")
    |> String.replace(~r/\s+/, "-")
  end
end
