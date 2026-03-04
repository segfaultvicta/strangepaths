defmodule Strangepaths.Site.ContentFolder do
  use Ecto.Schema
  import Ecto.Changeset

  schema "content_folders" do
    field(:name, :string)
    field(:slug, :string)
    field(:sort_order, :integer, default: 0)

    belongs_to(:parent, __MODULE__, foreign_key: :parent_id)
    has_many(:subfolders, __MODULE__, foreign_key: :parent_id)
    has_many(:pages, Strangepaths.Site.ContentPage, foreign_key: :folder_id)

    timestamps()
  end

  def changeset(folder, attrs) do
    folder
    |> cast(attrs, [:name, :slug, :parent_id, :sort_order])
    |> maybe_generate_slug()
    |> validate_required([:name, :slug])
    |> unique_constraint(:slug)
  end

  defp maybe_generate_slug(changeset) do
    case get_change(changeset, :slug) do
      nil ->
        name = get_change(changeset, :name) || get_field(changeset, :name)

        case name do
          "" -> changeset
          nil -> changeset
          name -> put_change(changeset, :slug, slugify(name))
        end

      _ ->
        changeset
    end
  end

  defp slugify(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^\w\s-]/, "")
    |> String.replace(~r/\s+/, "-")
  end
end
