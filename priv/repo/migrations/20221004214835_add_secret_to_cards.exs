defmodule Strangepaths.Repo.Migrations.AddSecretToCards do
  use Ecto.Migration

  def change do
    execute("INSERT INTO aspect (name) VALUES ('Alethic')")

    alter table(:cards) do
      add(:gnosis, :string)
    end
  end
end
