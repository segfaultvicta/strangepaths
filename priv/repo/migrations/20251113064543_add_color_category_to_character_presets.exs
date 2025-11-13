defmodule Strangepaths.Repo.Migrations.AddColorCategoryToCharacterPresets do
  use Ecto.Migration

  def change do
    alter table(:character_presets) do
      add :color_category, :string, default: "redacted", null: false
    end

    create constraint(:character_presets, :color_category_must_be_valid,
             check: "color_category IN ('red', 'green', 'blue', 'white', 'black', 'redacted')")
  end
end
