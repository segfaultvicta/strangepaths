defmodule Strangepaths.Repo.Migrations.AddColorCategoryToScenePosts do
  use Ecto.Migration

  def change do
    alter table(:scene_posts) do
      add :color_category, :string, default: "redacted", null: false
    end

    create constraint(:scene_posts, :color_category_must_be_valid,
             check: "color_category IN ('red', 'green', 'blue', 'white', 'black', 'redacted')")
  end
end
