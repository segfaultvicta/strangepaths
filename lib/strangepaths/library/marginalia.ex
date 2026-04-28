defmodule Strangepaths.Library.Marginalia do
  use Ecto.Schema
  import Ecto.Changeset

  schema "library_marginalia" do
    field(:content, :string)
    field(:name, :string)
    field(:font, :string)
    field(:color, :string)
    # bare :id field (not belongs_to) to avoid circular preload; depth computed via Repo.get in Library.marginalia_depth/1
    field(:parent_id, :id)

    belongs_to(:entry, Strangepaths.Library.Entry)
    belongs_to(:user, Strangepaths.Accounts.User)

    timestamps(updated_at: false)
  end

  def create_changeset(marginalia, attrs) do
    marginalia
    |> cast(attrs, [:entry_id, :user_id, :parent_id, :content, :name, :font, :color])
    |> validate_required([:entry_id, :user_id, :content, :name, :font, :color])
    |> validate_color()
    |> validate_font()
    |> validate_length(:content, min: 1, max: 10_000)
  end

  defp validate_color(changeset) do
    validate_format(changeset, :color, ~r/\A#([0-9a-fA-F]{3}|[0-9a-fA-F]{4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})\z/, message: "must be a hex color (3, 4, 6, or 8 digits)")
  end

  defp validate_font(changeset) do
    validate_change(changeset, :font, fn :font, font ->
      valid_fonts = Enum.map(Strangepaths.Library.Typefaces.all(), & &1.font)
      if font in valid_fonts, do: [], else: [font: "must be a valid typeface font"]
    end)
  end
end
