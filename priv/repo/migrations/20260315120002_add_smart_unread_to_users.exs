defmodule Strangepaths.Repo.Migrations.AddSmartUnreadToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :smart_unread, :boolean, default: true, null: false
    end
  end
end
