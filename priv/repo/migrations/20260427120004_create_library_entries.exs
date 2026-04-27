defmodule Strangepaths.Repo.Migrations.CreateLibraryEntries do
  use Ecto.Migration

  def change do
    create table(:library_entries) do
      add(:folio_id, references(:library_folios, on_delete: :delete_all), null: false)
      add(:user_id, references(:users), null: false)
      add(:position, :integer, null: false, default: 0)
      add(:kind, :string, null: false)
      add(:scene_post_id, references(:scene_posts, on_delete: :nilify_all))
      add(:content, :text)
      add(:name, :string)
      add(:font, :string)
      add(:color, :string)
      add(:group_id, :string)

      timestamps(updated_at: false)
    end

    create(index(:library_entries, [:folio_id, :position]))
    create(index(:library_entries, [:group_id]))
  end
end
