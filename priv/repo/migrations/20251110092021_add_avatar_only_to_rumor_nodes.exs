defmodule Strangepaths.Repo.Migrations.AddAvatarOnlyToRumorNodes do
  use Ecto.Migration

  def change do
    alter table(:rumor_nodes) do
      add :avatar_only, :boolean, default: false, null: false
    end
  end
end
