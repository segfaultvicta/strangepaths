defmodule Strangepaths.Repo.Migrations.AddContentFolders do
  use Ecto.Migration

  def change do
    create table(:content_folders) do
      add :name, :string, null: false
      add :slug, :string, null: false
      add :parent_id, references(:content_folders, on_delete: :restrict), null: true
      add :sort_order, :integer, null: false, default: 0

      timestamps()
    end

    create unique_index(:content_folders, [:slug])
    create index(:content_folders, [:parent_id, :sort_order])

    alter table(:content_pages) do
      add :folder_id, references(:content_folders, on_delete: :nilify_all), null: true
      add :sort_order, :integer, null: false, default: 0
    end

    create index(:content_pages, [:folder_id, :sort_order])

    # Backfill sort_order for existing pages
    execute(
      "UPDATE content_pages SET sort_order = sub.row_num FROM (SELECT id, ROW_NUMBER() OVER (ORDER BY id) AS row_num FROM content_pages) sub WHERE content_pages.id = sub.id",
      "SELECT 1"
    )
  end
end
