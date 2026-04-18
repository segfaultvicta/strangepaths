defmodule Strangepaths.BBS.Board do
  use Ecto.Schema
  import Ecto.Changeset

  schema "bbs_boards" do
    field(:name, :string)
    field(:slug, :string)
    field(:description, :string)
    field(:image_filename, :string)
    field(:position, :integer)
    has_many(:threads, Strangepaths.BBS.Thread)

    timestamps()
  end

  def changeset(board, attrs) do
    board
    |> cast(attrs, [:name, :description, :image_filename, :position])
    |> validate_required([:name])
    |> validate_length(:name, max: 100)
    |> validate_length(:description, max: 500)
    |> put_slug()
    |> unique_constraint(:slug)
  end

  defp put_slug(changeset) do
    case get_change(changeset, :name) do
      nil -> changeset
      name -> put_change(changeset, :slug, slugify(name))
    end
  end

  defp slugify(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s-]/, "")
    |> String.replace(~r/\s+/, "-")
    |> String.trim("-")
  end
end
