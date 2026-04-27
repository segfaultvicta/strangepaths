defmodule Strangepaths.Library.UserTypeface do
  use Ecto.Schema
  import Ecto.Changeset

  schema "library_user_typefaces" do
    field(:typeface_id, :string)
    belongs_to(:user, Strangepaths.Accounts.User)

    timestamps()
  end

  def changeset(user_typeface, attrs) do
    user_typeface
    |> cast(attrs, [:user_id, :typeface_id])
    |> validate_required([:user_id, :typeface_id])
    |> validate_typeface_id()
    |> unique_constraint([:user_id, :typeface_id])
  end

  defp validate_typeface_id(changeset) do
    validate_change(changeset, :typeface_id, fn :typeface_id, id ->
      if Strangepaths.Library.Typefaces.valid_id?(id) do
        []
      else
        [typeface_id: "is not a valid typeface"]
      end
    end)
  end
end
