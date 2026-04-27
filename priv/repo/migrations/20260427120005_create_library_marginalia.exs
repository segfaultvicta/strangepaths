defmodule Strangepaths.Repo.Migrations.CreateLibraryMarginalia do
  use Ecto.Migration

  def change do
    create table(:library_marginalia) do
      add(:entry_id, references(:library_entries, on_delete: :delete_all), null: false)
      add(:parent_id, references(:library_marginalia, on_delete: :delete_all))
      add(:user_id, references(:users), null: false)
      add(:content, :text, null: false)
      add(:name, :string, null: false)
      add(:font, :string, null: false)
      add(:color, :string, null: false)

      timestamps(updated_at: false)
    end

    create(index(:library_marginalia, [:entry_id]))
    create(index(:library_marginalia, [:parent_id]))
  end
end
