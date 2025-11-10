defmodule Strangepaths.Repo.Migrations.CreateRumorNodes do
  use Ecto.Migration

  def change do
    create table(:rumor_nodes) do
      add :x, :float, null: false
      add :y, :float, null: false
      add :z_index, :integer, default: 0, null: false
      add :scale, :float, default: 1.0, null: false
      add :title, :string, null: false
      add :content, :text
      add :color_category, :string, null: false
      add :is_anchor, :boolean, default: false, null: false
      add :avatar_id, references(:avatars, on_delete: :nilify_all)
      add :created_by_id, references(:users, on_delete: :nilify_all)

      timestamps()
    end

    create index(:rumor_nodes, [:avatar_id])
    create index(:rumor_nodes, [:created_by_id])
    create index(:rumor_nodes, [:is_anchor])
    create index(:rumor_nodes, [:color_category])
  end
end
