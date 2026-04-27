defmodule Strangepaths.Repo.Migrations.CreateLibraryUserTypefaces do
  use Ecto.Migration

  def change do
    create table(:library_user_typefaces) do
      add(:user_id, references(:users, on_delete: :delete_all), null: false)
      add(:typeface_id, :string, null: false)

      timestamps()
    end

    create(index(:library_user_typefaces, [:user_id]))
    create(unique_index(:library_user_typefaces, [:user_id, :typeface_id]))
  end
end
