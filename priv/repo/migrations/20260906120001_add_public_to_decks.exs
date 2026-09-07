defmodule Strangepaths.Repo.Migrations.AddPublicToDecks do
  use Ecto.Migration

  def change do
    alter table(:decks) do
      add :public, :boolean, default: false, null: false
    end
  end
end
