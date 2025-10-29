defmodule Strangepaths.Repo.Migrations.AddRoleToUsers do
  use Ecto.Migration

  def change do
    create_query = "CREATE TYPE user_role AS ENUM ('user', 'dragon')"
    drop_query = "DROP TYPE user_role"
    execute(create_query, drop_query)

    alter table(:users) do
      add(:role, :user_role)
      add(:nickname, :string)
    end
  end
end
