defmodule Strangepaths.ScenesEditTest do
  use Strangepaths.DataCase, async: true
  import Strangepaths.AccountsFixtures

  alias Strangepaths.{Repo, Scenes}
  alias Strangepaths.Scenes.{Post, Scene}

  setup do
    dragon = Repo.update!(Ecto.Changeset.change(user_fixture(), role: :dragon))
    player = user_fixture()

    scene =
      Repo.insert!(%Scene{
        name: "Edit Scene",
        slug: "edit-scene-#{System.unique_integer([:positive])}",
        owner_id: dragon.id,
        locked_to_users: [],
        status: :active
      })

    post =
      Repo.insert!(%Post{
        scene_id: scene.id,
        user_id: player.id,
        content: "original",
        post_type: :character,
        posted_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

    %{dragon: dragon, player: player, post: post}
  end

  test "author can edit their own post repeatedly", %{player: player, post: post} do
    assert {:ok, p1} = Scenes.edit_post(post.id, player, %{content: "one"})
    assert p1.content == "one"
    assert {:ok, p2} = Scenes.edit_post(post.id, player, %{content: "two"})
    assert p2.content == "two"
  end

  test "dragon edit wins and locks the post for the author", %{
    dragon: dragon,
    player: player,
    post: post
  } do
    assert {:ok, _} = Scenes.edit_post(post.id, dragon, %{content: "dragon version"})

    # Player's save from a window opened before the dragon's edit is rejected.
    assert {:error, :forbidden} = Scenes.edit_post(post.id, player, %{content: "player version"})
    assert Repo.get!(Post, post.id).content == "dragon version"

    refute Scenes.can_edit_post?(Repo.get!(Post, post.id), player)
    assert Scenes.can_edit_post?(Repo.get!(Post, post.id), dragon)
  end

  test "dragon can edit after the author has edited", %{dragon: dragon, player: player, post: post} do
    assert {:ok, _} = Scenes.edit_post(post.id, player, %{content: "player"})
    assert {:ok, p} = Scenes.edit_post(post.id, dragon, %{content: "dragon"})
    assert p.edited_by_id == dragon.id
  end

  test "other players cannot edit", %{post: post} do
    other = user_fixture()
    assert {:error, :forbidden} = Scenes.edit_post(post.id, other, %{content: "nope"})
  end

  test "editing a deleted post returns :not_found", %{player: player, post: post} do
    Repo.delete!(post)
    assert {:error, :not_found} = Scenes.edit_post(post.id, player, %{content: "late"})
  end
end
