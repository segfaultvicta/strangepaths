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
    |> validate_parent_entry(attrs)
  end

  defp validate_parent_entry(changeset, attrs) do
    parent_id = Map.get(attrs, "parent_id") || Map.get(attrs, :parent_id)
    entry_id = get_field(changeset, :entry_id)

    if parent_id && entry_id do
      case Strangepaths.Repo.get(Strangepaths.Library.Marginalia, parent_id) do
        nil ->
          add_error(changeset, :parent_id, "does not exist")
        parent ->
          if parent.entry_id == entry_id,
            do: changeset,
            else: add_error(changeset, :parent_id, "must belong to the same entry")
      end
    else
      changeset
    end
  end
end
