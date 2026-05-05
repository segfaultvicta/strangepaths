defmodule Strangepaths.Repo.Migrations.CreateLibraryMarginaliaReadMarks do
  use Ecto.Migration

  def change do
    create table(:library_marginalia_read_marks) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :marginalia_id, references(:library_marginalia, on_delete: :delete_all), null: false
      timestamps(updated_at: false)
    end

    create unique_index(:library_marginalia_read_marks, [:user_id, :marginalia_id])
    create index(:library_marginalia_read_marks, [:marginalia_id])
  end
end
