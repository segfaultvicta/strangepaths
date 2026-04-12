defmodule Strangepaths.Repo.Migrations.AddColorCategoryToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :color_category, :string, default: "redacted"
    end
  end
end
