defmodule Strangepaths.Repo.Migrations.AddActorNicknameToRumorChangeLog do
  use Ecto.Migration

  def change do
    alter table(:rumor_change_log) do
      add :actor_nickname, :string
    end
  end
end
