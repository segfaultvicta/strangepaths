defmodule Strangepaths.Site.Song do
  use Ecto.Schema
  import Ecto.Changeset

  schema "songs" do
    field(:link, :string)
    field(:title, :string)
    field(:text, :string)
    field(:disc, :integer)
    field(:order, :integer)
    field(:unlocked, :boolean, default: false)
    field(:lyrics_unlocked, :boolean, default: false)
    field(:file_guid, :string)
    field(:font_style, :string, default: "default")

    timestamps()
  end

  def changeset(song, attrs) do
    song
    |> cast(attrs, [:title, :text, :link, :disc, :order, :unlocked, :lyrics_unlocked, :file_guid, :font_style])
    |> validate_required([:title, :disc])
    |> validate_inclusion(:font_style, ["default", "alternate"])
    |> unique_constraint(:file_guid)
  end
end
