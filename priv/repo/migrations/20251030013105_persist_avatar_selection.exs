defmodule Strangepaths.Repo.Migrations.PersistAvatarSelection do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:selected_avatar_id, :integer)
    end
  end
end
