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

    timestamps()
  end

  def changeset(song, attrs) do
    song
    |> cast(attrs, [:title, :text, :link, :disc, :order, :unlocked, :lyrics_unlocked, :file_guid])
    |> validate_required([:title, :disc])
    |> unique_constraint(:file_guid)
  end
end
