defmodule Strangepaths.Repo.Migrations.AddAscensionToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:public_ascension, :boolean, default: false)
      add(:arete, :integer, default: 0)
      add(:primary_red, :integer, default: 4)
      add(:primary_green, :integer, default: 4)
      add(:primary_blue, :integer, default: 4)
      add(:primary_white, :integer, default: 4)
      add(:primary_black, :integer, default: 4)
      add(:alethic_red, :integer, default: 0)
      add(:alethic_green, :integer, default: 0)
      add(:alethic_blue, :integer, default: 0)
      add(:alethic_white, :integer, default: 0)
      add(:alethic_black, :integer, default: 0)
      add(:techne, {:array, :string}, default: [])
    end
  end
end
