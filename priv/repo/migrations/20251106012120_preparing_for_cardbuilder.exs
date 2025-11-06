defmodule Strangepaths.Repo.Migrations.PreparingForCardbuilder do
  use Ecto.Migration

  def change do
    alter table(:cards) do
      add(:cardart, :string)
      add(:statusline, :string)
      add(:flavortext, :string)
    end
  end
end
