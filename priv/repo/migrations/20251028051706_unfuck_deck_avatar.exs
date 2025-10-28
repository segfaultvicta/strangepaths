defmodule Strangepaths.Repo.Migrations.UnfuckDeckAvatar do
  use Ecto.Migration

  def change do
    alter table(:decks) do
      remove(:avatar)
      add(:avatar_id, references(:avatars))
    end
  end
end
