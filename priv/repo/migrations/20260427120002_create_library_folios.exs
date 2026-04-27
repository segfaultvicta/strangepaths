defmodule Strangepaths.Repo.Migrations.CreateLibraryFolios do
  use Ecto.Migration

  def change do
    create table(:library_folios) do
      add(:user_id, references(:users), null: false)
      add(:title, :string, null: false)
      add(:slug, :string, null: false)
      add(:subtitle, :string)
      add(:body, :text)
      add(:body_locked_by_id, references(:users))
      add(:body_locked_at, :utc_datetime)

      timestamps()
    end

    create(unique_index(:library_folios, [:title]))
    create(unique_index(:library_folios, [:slug]))
    create(index(:library_folios, [:user_id]))
    create(index(:library_folios, [:inserted_at]))
  end
end
