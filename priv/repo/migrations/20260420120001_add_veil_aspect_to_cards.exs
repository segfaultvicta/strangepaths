defmodule Strangepaths.Repo.Migrations.AddVeilAspectToCards do
  use Ecto.Migration

  def change do
    alter table(:cards) do
      add :veil_aspect_id, :integer, null: true
    end
  end
end
