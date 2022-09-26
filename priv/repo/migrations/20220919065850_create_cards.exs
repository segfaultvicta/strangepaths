defmodule Strangepaths.Repo.Migrations.CreateCards do
  use Ecto.Migration

  def change do
    create table(:cards) do
      add(:name, :string)
      add(:img, :string)
      add(:rules, :text)
      add(:principle, :string)
      add(:type, :string)
      add(:alt, references(:cards, on_delete: :delete_all))
      add(:aspect_id, references(:aspect, on_delete: :nothing))
      add(:glorified, :boolean)

      timestamps()
    end

    create(index(:cards, [:alt]))
    create(index(:cards, [:aspect_id]))
  end
end
