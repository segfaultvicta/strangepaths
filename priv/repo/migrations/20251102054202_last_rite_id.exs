defmodule Strangepaths.Repo.Migrations.LastRiteId do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:last_rite_id, :integer)
    end
  end
end
