defmodule Strangepaths.Repo.Migrations.CreateCharacterPresets do
  use Ecto.Migration

  def change do
    create table(:character_presets) do
      add :name, :string, null: false
      add :selected_avatar_id, :integer
      add :narrative_author_name, :string
      add :arete, :integer, default: 0

      # Primary dice
      add :primary_red, :integer, default: 4
      add :primary_green, :integer, default: 4
      add :primary_blue, :integer, default: 4
      add :primary_white, :integer, default: 4
      add :primary_black, :integer, default: 4
      add :primary_void, :integer, default: 4

      # Alethic dice
      add :alethic_red, :integer, default: 0
      add :alethic_green, :integer, default: 0
      add :alethic_blue, :integer, default: 0
      add :alethic_white, :integer, default: 0
      add :alethic_black, :integer, default: 0
      add :alethic_void, :integer, default: 0

      add :techne, {:array, :string}, default: []
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:character_presets, [:user_id])
  end
end
