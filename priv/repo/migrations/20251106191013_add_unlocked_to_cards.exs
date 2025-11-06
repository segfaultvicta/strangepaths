defmodule Strangepaths.Repo.Migrations.AddUnlockedToCards do
  use Ecto.Migration

  def change do
    alter table(:cards) do
      add :unlocked, :boolean, default: true, null: false
    end

    # Set all Alethic cards (those with gnosis) to unlocked: false by default
    execute(
      "UPDATE cards SET unlocked = false WHERE gnosis IS NOT NULL AND gnosis != ''",
      "UPDATE cards SET unlocked = true WHERE gnosis IS NOT NULL AND gnosis != ''"
    )
  end
end
