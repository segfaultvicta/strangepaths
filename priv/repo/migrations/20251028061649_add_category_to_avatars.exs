defmodule Strangepaths.Repo.Migrations.AddCategoryToAvatars do
  use Ecto.Migration

  def change do
    alter table(:avatars) do
      add(:category, :string, default: "general")
      add(:display_name, :string)
      remove(:owner_id)
    end
  end
end
