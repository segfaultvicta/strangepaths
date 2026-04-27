defmodule Strangepaths.Library.Marginalia do
  use Ecto.Schema
  import Ecto.Changeset

  schema "library_marginalia" do
    field(:content, :string)
    field(:name, :string)
    field(:font, :string)
    field(:color, :string)
    field(:parent_id, :id)

    belongs_to(:entry, Strangepaths.Library.Entry)
    belongs_to(:user, Strangepaths.Accounts.User)

    timestamps(updated_at: false)
  end

  def create_changeset(marginalia, attrs) do
    marginalia
    |> cast(attrs, [:entry_id, :user_id, :parent_id, :content, :name, :font, :color])
    |> validate_required([:entry_id, :user_id, :content, :name, :font, :color])
    |> validate_length(:content, min: 1, max: 10_000)
  end
end
