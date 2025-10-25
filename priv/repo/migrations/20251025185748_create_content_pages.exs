defmodule Strangepaths.Repo.Migrations.CreateContentPages do
  use Ecto.Migration

  def change do
    create table(:content_pages) do
      add(:title, :string, null: false)
      add(:slug, :string, null: false)
      add(:body, :text, null: false)
      add(:published, :boolean, default: false, null: false)

      timestamps()
    end

    create(unique_index(:content_pages, [:slug]))
  end
end
