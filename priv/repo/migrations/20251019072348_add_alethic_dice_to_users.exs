defmodule Strangepaths.Repo.Migrations.AddAlethicDiceToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:primary_void, :integer, default: 4)
      add(:alethic_void, :integer, default: 0)
    end
  end
end
