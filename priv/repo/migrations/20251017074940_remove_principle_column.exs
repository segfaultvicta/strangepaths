defmodule Strangepaths.Repo.Migrations.RemovePrincipleColumn do
  use Ecto.Migration

  def change do
    alter table(:cards) do
      remove(:principle, :string)
    end

    alter table(:decks) do
      remove(:principle, :string)
    end
  end
end
