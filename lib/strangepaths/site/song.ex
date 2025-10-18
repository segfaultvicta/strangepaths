defmodule Strangepaths.Site.Song do
  use Ecto.Schema
  import Ecto.Changeset

  schema "songs" do
    field(:link, :string)
    field(:title, :string)
    field(:text, :string)
    field(:disc, :integer)
    field(:unlocked, :boolean, default: false)

    timestamps()
  end

  def changeset(song, attrs) do
    song
    |> cast(attrs, [:title, :text, :link, :disc, :unlocked])
    |> validate_required([:title, :disc, :unlocked])
  end
end
