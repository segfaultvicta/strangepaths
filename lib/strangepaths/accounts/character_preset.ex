defmodule Strangepaths.Accounts.CharacterPreset do
  use Ecto.Schema
  import Ecto.Changeset

  schema "character_presets" do
    field(:name, :string)
    field(:selected_avatar_id, :integer)
    field(:narrative_author_name, :string)
    field(:arete, :integer, default: 0)

    # Primary dice
    field(:primary_red, :integer, default: 4)
    field(:primary_green, :integer, default: 4)
    field(:primary_blue, :integer, default: 4)
    field(:primary_white, :integer, default: 4)
    field(:primary_black, :integer, default: 4)
    field(:primary_void, :integer, default: 4)

    # Alethic dice
    field(:alethic_red, :integer, default: 0)
    field(:alethic_green, :integer, default: 0)
    field(:alethic_blue, :integer, default: 0)
    field(:alethic_white, :integer, default: 0)
    field(:alethic_black, :integer, default: 0)
    field(:alethic_void, :integer, default: 0)

    field(:techne, {:array, :string}, default: [])

    belongs_to(:user, Strangepaths.Accounts.User)

    timestamps()
  end

  @doc false
  def changeset(preset, attrs) do
    preset
    |> cast(attrs, [
      :name,
      :selected_avatar_id,
      :narrative_author_name,
      :arete,
      :primary_red,
      :primary_green,
      :primary_blue,
      :primary_white,
      :primary_black,
      :primary_void,
      :alethic_red,
      :alethic_green,
      :alethic_blue,
      :alethic_white,
      :alethic_black,
      :alethic_void,
      :techne,
      :user_id
    ])
    |> validate_required([:name, :user_id])
    |> validate_length(:name, min: 1, max: 255)
  end
end

defimpl Inspect, for: Strangepaths.Accounts.CharacterPreset do
  def inspect(preset, _opts) do
    """
    #{preset.name} (ID: #{preset.id})
    Avatar Selected: #{preset.selected_avatar_id}
    Narrative Author: #{preset.narrative_author_name}
    Arete: #{preset.arete}
    R #{preset.primary_red} G #{preset.primary_green} U #{preset.primary_blue}
    W #{preset.primary_white} B #{preset.primary_black} V #{preset.primary_void}
    R*#{preset.alethic_red} G*#{preset.alethic_green} U*#{preset.alethic_blue}
    W*#{preset.alethic_white} B*#{preset.alethic_black} V*#{preset.alethic_void}
    Techne: #{inspect(preset.techne)}
    """
  end
end
