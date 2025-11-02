defmodule Strangepaths.Repo.Migrations.LastRiteIsAGuidYouDipshit do
  use Ecto.Migration

  def change do
    alter table(:users) do
      remove(:last_rite_id)
      add(:last_rite_id, :string)
    end
  end
end
