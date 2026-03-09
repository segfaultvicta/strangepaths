defmodule Strangepaths.Repo.Migrations.AddGrantedUserIdToAvatars do
  use Ecto.Migration

  def change do
    alter table(:avatars) do
      add :granted_user_id, references(:users, on_delete: :nilify_all), null: true
    end
  end
end
