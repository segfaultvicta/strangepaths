defmodule Strangepaths.Library.Entry do
  use Ecto.Schema
  import Ecto.Changeset

  schema "library_entries" do
    field(:position, :integer, default: 0)
    field(:kind, Ecto.Enum, values: [:post_ref, :note])
    field(:content, :string)
    field(:name, :string)
    field(:font, :string)
    field(:color, :string)
    field(:group_id, :string)

    belongs_to(:folio, Strangepaths.Library.Folio)
    belongs_to(:user, Strangepaths.Accounts.User)
    belongs_to(:scene_post, Strangepaths.Scenes.Post, foreign_key: :scene_post_id)
    has_many(:marginalia, Strangepaths.Library.Marginalia)

    timestamps(updated_at: false)
  end

  def post_ref_changeset(entry, attrs) do
    entry
    |> cast(attrs, [:folio_id, :user_id, :position, :scene_post_id, :group_id])
    |> validate_required([:folio_id, :user_id, :scene_post_id])
    |> put_change(:kind, :post_ref)
  end

  def note_changeset(entry, attrs) do
    entry
    |> cast(attrs, [:folio_id, :user_id, :position, :content, :name, :font, :color, :group_id])
    |> validate_required([:folio_id, :user_id, :content, :name, :font, :color])
    |> put_change(:kind, :note)
    |> validate_length(:content, min: 1, max: 10_000)
  end
end
