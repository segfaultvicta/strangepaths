defmodule Strangepaths.Scenes do
  @moduledoc """
  The Scenes context for managing interactive story scenes.
  """

  import Ecto.Query, warn: false
  alias Strangepaths.Repo
  alias Strangepaths.Scenes.{Scene, Post}
  alias Strangepaths.Accounts.User

  ## Scene functions

  @doc """
  Returns the list of active scenes visible to the given user.
  Dragon sees all scenes. Regular users see public scenes and locked scenes they're permitted to view.
  """
  def list_active_scenes(%User{role: :dragon}) do
    Scene
    |> where([s], s.status == :active)
    |> order_by([s], desc: s.inserted_at)
    |> preload(:owner)
    |> Repo.all()
    |> sort_scenes()
  end

  def list_active_scenes(%User{id: user_id}) do
    Scene
    |> where([s], s.status == :active)
    |> where([s],
      fragment("? = '{}'", s.locked_to_users) or
      fragment("? = ANY(?)", ^user_id, s.locked_to_users)
    )
    |> order_by([s], desc: s.inserted_at)
    |> preload(:owner)
    |> Repo.all()
    |> sort_scenes()
  end

  @doc """
  Sorts scenes in the following order:
  1. Elsewhere (always first)
  2. Non-locked scenes (alphabetically)
  3. Locked scenes (alphabetically)
  """
  def sort_scenes(scenes) do
    scenes
    |> Enum.sort_by(fn scene ->
      cond do
        # Elsewhere always comes first (sort key: 0)
        scene.is_elsewhere -> {0, ""}

        # Non-locked scenes come second, sorted alphabetically (sort key: 1, name)
        !Scene.locked?(scene) -> {1, String.downcase(scene.name)}

        # Locked scenes come last, sorted alphabetically (sort key: 2, name)
        true -> {2, String.downcase(scene.name)}
      end
    end)
  end

  @doc """
  Returns the list of archived scenes visible to the given user.
  """
  def list_archived_scenes(%User{role: :dragon}) do
    Scene
    |> where([s], s.status == :archived)
    |> order_by([s], desc: s.archived_at)
    |> preload(:owner)
    |> Repo.all()
  end

  def list_archived_scenes(%User{id: user_id}) do
    Scene
    |> where([s], s.status == :archived)
    |> where([s],
      fragment("? = '{}'", s.locked_to_users) or
      fragment("? = ANY(?)", ^user_id, s.locked_to_users) or
      s.is_elsewhere == true
    )
    |> order_by([s], desc: s.archived_at)
    |> preload(:owner)
    |> Repo.all()
  end

  @doc """
  Gets a single scene by ID.
  """
  def get_scene(id) do
    Repo.get(Scene, id)
    |> Repo.preload(:owner)
  end

  @doc """
  Gets the Elsewhere scene (OOC chat).
  """
  def get_elsewhere_scene do
    Repo.get_by(Scene, is_elsewhere: true)
    |> Repo.preload(:owner)
  end

  @doc """
  Creates a scene.
  """
  def create_scene(attrs \\ %{}) do
    %Scene{}
    |> Scene.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Ensures the Elsewhere scene exists. Creates it if it doesn't.
  Returns {:ok, scene} if it exists or was created successfully.
  """
  def ensure_elsewhere_scene do
    case get_elsewhere_scene() do
      nil ->
        # Find a dragon user to own it, or use first user
        owner = Repo.get_by(User, role: :dragon) || Repo.one(from u in User, limit: 1)

        if owner do
          create_scene(%{
            name: "Elsewhere",
            owner_id: owner.id,
            is_elsewhere: true,
            locked_to_users: []
          })
        else
          {:error, "No users exist to own the Elsewhere scene"}
        end

      scene ->
        {:ok, scene}
    end
  end

  @doc """
  Archives a scene. Only the Dragon or the scene owner can archive.
  Elsewhere cannot be archived.
  """
  def archive_scene(%Scene{is_elsewhere: true}, _user) do
    {:error, "Cannot archive the Elsewhere scene"}
  end

  def archive_scene(%Scene{} = scene, %User{role: :dragon}) do
    scene
    |> Scene.archive_changeset()
    |> Repo.update()
  end

  def archive_scene(%Scene{owner_id: owner_id} = scene, %User{id: user_id}) when owner_id == user_id do
    scene
    |> Scene.archive_changeset()
    |> Repo.update()
  end

  def archive_scene(_scene, _user) do
    {:error, "Only the Dragon or scene owner can archive this scene"}
  end

  ## Post functions

  @doc """
  Lists the most recent posts for a scene, limited and ordered by posted_at descending.
  Default limit is 30.
  """
  def list_posts(scene_id, limit \\ 30, offset \\ 0) do
    Post
    |> where([p], p.scene_id == ^scene_id)
    |> order_by([p], desc: p.posted_at)
    |> limit(^limit)
    |> offset(^offset)
    |> preload([:user, :avatar])
    |> Repo.all()
  end

  @doc """
  Lists posts for a scene with date range filtering (useful for Elsewhere weekly archives).
  """
  def list_posts_by_date_range(scene_id, start_date, end_date, limit \\ 100, offset \\ 0) do
    Post
    |> where([p], p.scene_id == ^scene_id)
    |> where([p], p.posted_at >= ^start_date and p.posted_at < ^end_date)
    |> order_by([p], desc: p.posted_at)
    |> limit(^limit)
    |> offset(^offset)
    |> preload([:user, :avatar])
    |> Repo.all()
  end

  @doc """
  Gets post count for a scene.
  """
  def count_posts(scene_id) do
    Repo.one(from p in Post, where: p.scene_id == ^scene_id, select: count(p.id))
  end

  @doc """
  Creates a character post (regular user post).
  """
  def create_character_post(attrs \\ %{}) do
    %Post{}
    |> Post.character_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a narrative post (Dragon post with custom attribution).
  """
  def create_narrative_post(attrs \\ %{}) do
    %Post{}
    |> Post.narrative_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a system post (automated message).
  """
  def create_system_post(attrs \\ %{}) do
    %Post{}
    |> Post.system_changeset(attrs)
    |> Repo.insert()
  end

  ## Permission helpers

  @doc """
  Checks if a user can view a scene.
  """
  def can_view_scene?(%Scene{} = scene, %User{} = user) do
    Scene.can_view?(scene, user)
  end

  @doc """
  Checks if a user can post in a scene.
  Users can post if:
  - They have public_ascension: true, OR
  - The scene is Elsewhere (OOC chat)
  """
  def can_post_in_scene?(%Scene{is_elsewhere: true}, %User{}), do: true
  def can_post_in_scene?(%Scene{}, %User{public_ascension: true}), do: true
  def can_post_in_scene?(%Scene{}, %User{role: :dragon}), do: true
  def can_post_in_scene?(_scene, _user), do: false

  @doc """
  Checks if a user can create scenes (Dragon only).
  """
  def can_create_scene?(%User{role: :dragon}), do: true
  def can_create_scene?(_user), do: false

  @doc """
  Groups Elsewhere posts by week for archive display.
  Returns a map of %{week_start_date => [posts]}.
  """
  def group_elsewhere_posts_by_week(scene_id) do
    posts =
      Post
      |> where([p], p.scene_id == ^scene_id)
      |> order_by([p], desc: p.posted_at)
      |> preload([:user, :avatar])
      |> Repo.all()

    posts
    |> Enum.group_by(fn post ->
      # Get the Monday of the week this post was made
      posted_date = DateTime.to_date(post.posted_at)
      day_of_week = Date.day_of_week(posted_date)
      days_to_subtract = day_of_week - 1
      Date.add(posted_date, -days_to_subtract)
    end)
    |> Enum.sort_by(fn {week_start, _posts} -> week_start end, {:desc, Date})
    |> Enum.into(%{})
  end
end
