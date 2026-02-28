defmodule Strangepaths.Repo.Migrations.AddAuthorNicknameToScenePosts do
  use Ecto.Migration

  def up do
    alter table(:scene_posts) do
      add :author_nickname, :string
    end

    # Backfill existing posts with current user nicknames
    execute """
    UPDATE scene_posts
    SET author_nickname = users.nickname
    FROM users
    WHERE scene_posts.user_id = users.id
    AND scene_posts.author_nickname IS NULL
    """
  end

  def down do
    alter table(:scene_posts) do
      remove :author_nickname
    end
  end
end
