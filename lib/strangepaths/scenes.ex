defmodule Strangepaths.Scenes do
  @moduledoc """
  The Scenes context for managing interactive story scenes.
  """

  require Logger

  import Ecto.Query, warn: false
  alias Strangepaths.Repo
  alias Strangepaths.Scenes.{Scene, Post, SceneReadMark}
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
    |> where(
      [s],
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
    |> where(
      [s],
      fragment("? = '{}'", s.locked_to_users) or
        fragment("? = ANY(?)", ^user_id, s.locked_to_users) or
        s.is_elsewhere == true
    )
    |> order_by([s], desc: s.archived_at)
    |> preload(:owner)
    |> Repo.all()
  end

  @doc """
  Returns the most recently archived scenes visible to the given user, up to `limit`.
  """
  def list_recent_archived_scenes(%User{role: :dragon}, limit) do
    Scene
    |> where([s], s.status == :archived)
    |> where([s], s.is_elsewhere == false)
    |> order_by([s], desc: s.archived_at)
    |> limit(^limit)
    |> preload(:owner)
    |> Repo.all()
  end

  def list_recent_archived_scenes(%User{id: user_id}, limit) do
    Scene
    |> where([s], s.status == :archived)
    |> where([s], s.is_elsewhere == false)
    |> where(
      [s],
      fragment("? = '{}'", s.locked_to_users) or
        fragment("? = ANY(?)", ^user_id, s.locked_to_users)
    )
    |> order_by([s], desc: s.archived_at)
    |> limit(^limit)
    |> preload(:owner)
    |> Repo.all()
  end

  def list_recent_archived_scenes(nil, _limit), do: []

  @doc """
  Gets a single scene by ID.
  """
  def get_scene(id) do
    Repo.get(Scene, id)
    |> Repo.preload(:owner)
  end

  @doc """
  Gets a scene by its slug.
  """
  def get_scene_by_slug(slug) do
    Repo.get_by(Scene, slug: slug)
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
        owner = Repo.get_by(User, role: :dragon) || Repo.one(from(u in User, limit: 1))

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

  def update_scene_locked_users(scene_id, user_ids) do
    scene = get_scene(scene_id)

    scene
    |> Scene.update_locked_users_changeset(%{locked_to_users: user_ids})
    |> Repo.update()
  end

  @doc """
  Unlocks an archived scene by clearing its locked_to_users list.
  Makes the scene publicly viewable. Only available for archived scenes.
  """
  def unlock_archived_scene(%Scene{status: :archived} = scene) do
    scene
    |> Scene.update_locked_users_changeset(%{locked_to_users: []})
    |> Repo.update()
  end

  def unlock_archived_scene(_scene) do
    {:error, "Can only unlock archived scenes"}
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

  def archive_scene(%Scene{owner_id: owner_id} = scene, %User{id: user_id})
      when owner_id == user_id do
    scene
    |> Scene.archive_changeset()
    |> Repo.update()
  end

  def archive_scene(_scene, _user) do
    {:error, "Only the Dragon or scene owner can archive this scene"}
  end

  @doc """
  Updates the name of an archived scene.
  Only the Dragon can update archived scene names.
  """
  def update_archived_scene_name(%Scene{archived_at: archived_at} = scene, new_name)
      when not is_nil(archived_at) do
    scene
    |> Scene.update_name_changeset(%{name: new_name})
    |> Repo.update()
  end

  def update_archived_scene_name(_scene, _new_name) do
    {:error, "Scene is not archived"}
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

  def list_posts_for_archive(scene_id) do
    Post
    |> where([p], p.scene_id == ^scene_id)
    |> order_by([p], asc: p.posted_at)
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
    Repo.one(from(p in Post, where: p.scene_id == ^scene_id, select: count(p.id)))
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

  @doc """
  Updates an existing post's content.
  """
  def update_post(%Post{} = post, attrs) do
    post
    |> Post.edit_changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, post} -> {:ok, Repo.preload(post, [:user, :avatar])}
      error -> error
    end
  end

  ## Read marks (persistent unread tracking)

  @doc """
  Upserts a read mark for the given user and scene to the current time.
  """
  def upsert_read_mark(user_id, scene_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    %SceneReadMark{}
    |> SceneReadMark.changeset(%{user_id: user_id, scene_id: scene_id, last_read_at: now})
    |> Repo.insert(
      on_conflict: [set: [last_read_at: now]],
      conflict_target: [:user_id, :scene_id]
    )
  end

  @doc """
  Returns a map of %{scene_id => unread_count} for all active scenes visible to the user.
  Counts posts with posted_at > last_read_at (or all posts if no read mark exists).
  """
  def unread_counts_for_user(%User{} = user, scene_ids) when is_list(scene_ids) do
    if scene_ids == [] do
      %{}
    else
      # Get read marks for this user across all requested scenes
      read_marks =
        from(rm in SceneReadMark,
          where: rm.user_id == ^user.id and rm.scene_id in ^scene_ids,
          select: {rm.scene_id, rm.last_read_at}
        )
        |> Repo.all()
        |> Map.new()

      # For each scene, count posts after the read mark (or all posts if no mark)
      scene_ids
      |> Enum.map(fn scene_id ->
        last_read = Map.get(read_marks, scene_id)

        count =
          if last_read do
            Repo.one(
              from(p in Post,
                where: p.scene_id == ^scene_id and p.posted_at > ^last_read,
                select: count(p.id)
              )
            )
          else
            # No read mark = never visited; count all posts
            Repo.one(
              from(p in Post,
                where: p.scene_id == ^scene_id,
                select: count(p.id)
              )
            )
          end

        {scene_id, count}
      end)
      |> Enum.filter(fn {_id, count} -> count > 0 end)
      |> Map.new()
    end
  end

  def system_message(msg, also_to_elsewhere?, scene_id) do
    post_attrs = %{
      scene_id: scene_id,
      content: String.trim(msg),
      copy_elsewhere: also_to_elsewhere?
    }

    case create_system_post(post_attrs) do
      {:ok, post} ->
        post = Strangepaths.Repo.preload(post, [:user, :avatar])
        Strangepaths.Scenes.SceneServer.broadcast_post(scene_id, post)

        if also_to_elsewhere? and scene_id != get_elsewhere_scene().id do
          Strangepaths.Scenes.SceneServer.broadcast_post(get_elsewhere_scene().id, post)
        end

        :ok

      {:error, changeset} ->
        Logger.error("Failed to post system message: #{inspect(changeset)}")
        {:error, "Failed to post system message."}
    end
  end

  def system_message(msg) do
    # Send message to ALL non-locked scenes, including Elsewhere
    scenes = Repo.all(from(s in Scene, where: s.locked_to_users == [] and s.status == :active))
    Enum.each(scenes, fn scene -> system_message(msg, false, scene.id) end)
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

  Technically this should also be checking to make sure the user is an allowed user,
  if it's a locked scene, but I think given the UX around that it's fine to not care.
  Actually this is *strictly identical to* "user in rhs_eligible" and I can probably
  just replace this with that, I think? Much to consider.
  """
  def can_post_in_scene?(%Scene{is_elsewhere: true}, %User{}), do: true
  def can_post_in_scene?(%Scene{}, %User{public_ascension: true}), do: true
  def can_post_in_scene?(%Scene{}, %User{role: :dragon}), do: true
  def can_post_in_scene?(_scene, _user), do: false

  def post_eligible(user, scene) do
    rhs_users_by_id = rhs_eligible(scene) |> Enum.map(& &1.id)
    user.id in rhs_users_by_id
  end

  @doc """
  Checks if a user can create scenes (Dragon only).
  """
  def can_create_scene?(%User{role: :dragon}), do: true
  def can_create_scene?(_user), do: false

  @doc """
  Returns a list of users who can post in the given scene.
  - Elsewhere: all users
  - Locked scenes: Dragon + whitelisted users
  - Normal scenes: all users with public_ascension: true
  """
  def rhs_eligible(scene) do
    list = _rhs_eligible(scene)

    list
    |> Enum.map(fn user ->
      techne =
        case user.techne do
          nil ->
            [{"", ""}]

          _ ->
            Enum.map(user.techne, fn techne ->
              case String.split(techne, ":", parts: 2) do
                [name, desc] -> %{name: String.trim(name), desc: String.trim(desc)}
                [name] -> %{name: String.trim(name), desc: ""}
              end
            end)
        end

      %{user | techne: techne}
    end)
  end

  defp _rhs_eligible(%Scene{is_elsewhere: true}) do
    Strangepaths.Accounts.list_users()
  end

  defp _rhs_eligible(%Scene{locked_to_users: locked_users})
       when is_list(locked_users) and length(locked_users) > 0 do
    # Get the Dragon user
    dragon_query = from(u in User, where: u.role == :dragon)
    dragon_users = Repo.all(dragon_query)

    # Get whitelisted users
    permitted_query = from(u in User, where: u.id in ^locked_users)
    permitted_users = Repo.all(permitted_query)

    # Combine and remove duplicates
    (dragon_users ++ permitted_users)
    |> Enum.uniq_by(& &1.id)
  end

  defp _rhs_eligible(%Scene{}) do
    # Normal public scene: all users with public_ascension
    from(u in User, where: u.public_ascension == true)
    |> Repo.all()
  end

  @doc """
  Groups Elsewhere posts by week for archive display.
  Returns a map of %{week_start_date => [posts]}.
  """
  def group_elsewhere_posts_by_week(scene_id) do
    posts =
      Post
      |> where([p], p.scene_id == ^scene_id)
      |> order_by([p], asc: p.posted_at)
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

  @doc """
  Searches archived scenes by name using ILIKE pattern matching.
  Returns list of maps with scene_id, scene_name, and scene_slug.

  Filters:
  - my_scenes_filter: only return scenes where user has posted
  - hide_elsewhere_filter: exclude the Elsewhere scene
  - author_filter: filter by user nickname or narrative_author_name (only applies to post search)
  """
  def search_archived_scenes(
        query,
        user_id,
        my_scenes_filter,
        hide_elsewhere_filter,
        elsewhere_scene_id,
        _author_filter
      ) do
    search_pattern = "%#{query}%"

    base_query =
      from(s in Scene,
        where: s.status == :archived or s.is_elsewhere == true,
        where: ilike(s.name, ^search_pattern),
        select: %{
          scene_id: s.id,
          scene_name: s.name,
          scene_slug: s.slug
        }
      )

    # Apply elsewhere filter
    base_query =
      if hide_elsewhere_filter && elsewhere_scene_id do
        where(base_query, [s], s.id != ^elsewhere_scene_id)
      else
        base_query
      end

    # Apply my_scenes filter
    base_query =
      if my_scenes_filter do
        from([s] in base_query,
          join: p in Post,
          on: p.scene_id == s.id and p.user_id == ^user_id,
          distinct: s.id
        )
      else
        base_query
      end

    # Apply permissions (same logic as list_archived_scenes)
    dragon_query = from(u in User, where: u.id == ^user_id and u.role == :dragon, select: u.id)
    is_dragon = Repo.exists?(dragon_query)

    final_query =
      if is_dragon do
        base_query
      else
        from([s] in base_query,
          where:
            fragment("? = '{}'", s.locked_to_users) or
              fragment("? = ANY(?)", ^user_id, s.locked_to_users) or
              s.is_elsewhere == true
        )
      end

    Repo.all(final_query)
  end

  @doc """
  Searches archived posts by content (IC and OOC) using ILIKE pattern matching.
  Returns list of maps with scene info and post snippets showing matching content.

  Filters:
  - my_scenes_filter: only return scenes where user has posted
  - hide_elsewhere_filter: exclude the Elsewhere scene
  - hide_system_filter: exclude system posts
  - author_filter: filter by user nickname or narrative_author_name
  """
  def search_archived_posts(
        query,
        user_id,
        my_scenes_filter,
        hide_elsewhere_filter,
        hide_system_filter,
        elsewhere_scene_id,
        author_filter
      ) do
    search_pattern = "%#{query}%"
    # Lower threshold = more fuzzy matches. Try 0.1-0.3 range.
    # 0.3 = default (strict), 0.2 = medium, 0.1 = loose
    similarity_threshold = 0.15

    # Check if user is dragon
    dragon_query = from(u in User, where: u.id == ^user_id and u.role == :dragon, select: u.id)
    is_dragon = Repo.exists?(dragon_query)

    # Try to find user by nickname for author filter
    author_user_id =
      if author_filter != "" do
        case Repo.get_by(User, nickname: author_filter) do
          nil -> nil
          user -> user.id
        end
      else
        nil
      end

    # Build complete query with dynamic conditions
    Post
    |> join(:inner, [p], s in Scene, as: :scene, on: p.scene_id == s.id)
    |> where([p, scene: s], s.status == :archived or s.is_elsewhere == true)
    |> where(
      [p, scene: s],
      # Exact substring matching (fast path using ILIKE)
      # Fuzzy matching for typos (uses GIN trigram indexes)
      # similarity() is bidirectional and better for typo matching than word_similarity()
      ilike(p.content_stripped, ^search_pattern) or
        ilike(p.ooc_content_stripped, ^search_pattern) or
        fragment("similarity(?, ?) > ?", p.content_stripped, ^query, ^similarity_threshold) or
        fragment("similarity(?, ?) > ?", p.ooc_content_stripped, ^query, ^similarity_threshold)
    )
    |> filter_elsewhere(hide_elsewhere_filter, elsewhere_scene_id)
    |> filter_my_scenes(my_scenes_filter, user_id)
    |> filter_system_posts(hide_system_filter)
    |> filter_author(author_filter, author_user_id)
    |> filter_permissions(is_dragon, user_id)
    |> join(:left, [p], u in User, on: p.user_id == u.id, as: :user)
    |> select([p, scene: s, user: u], %{
      scene_id: s.id,
      scene_name: s.name,
      scene_slug: s.slug,
      post_id: p.id,
      content: p.content_stripped,
      ooc_content: p.ooc_content_stripped,
      posted_at: p.posted_at,
      locked_to_users: s.locked_to_users,
      is_elsewhere: s.is_elsewhere,
      post_type: p.post_type,
      user_nickname: u.nickname,
      narrative_author_name: p.narrative_author_name
    })
    |> Repo.all()
    |> group_and_create_snippets(query)
  end

  # Helper functions for search_archived_posts
  defp filter_elsewhere(query, true, elsewhere_scene_id) when not is_nil(elsewhere_scene_id) do
    where(query, [scene: s], s.id != ^elsewhere_scene_id)
  end

  defp filter_elsewhere(query, _, _), do: query

  defp filter_my_scenes(query, true, user_id) do
    where(
      query,
      [scene: s],
      exists(
        from(p2 in Post, where: p2.scene_id == parent_as(:scene).id and p2.user_id == ^user_id)
      )
    )
  end

  defp filter_my_scenes(query, _, _), do: query

  defp filter_system_posts(query, true) do
    where(query, [p], p.post_type != :system)
  end

  defp filter_system_posts(query, _), do: query

  # Filter by author - if user_id is found, filter by that; otherwise filter by narrative_author_name
  defp filter_author(query, author_filter, author_user_id) when author_filter != "" do
    if author_user_id do
      # Found a user with this nickname - filter by user_id
      where(query, [p], p.user_id == ^author_user_id)
    else
      # No user found - filter by narrative_author_name
      where(query, [p], ilike(p.narrative_author_name, ^"%#{author_filter}%"))
    end
  end

  defp filter_author(query, _, _), do: query

  defp filter_permissions(query, true, _user_id), do: query

  defp filter_permissions(query, false, user_id) do
    where(
      query,
      [scene: s],
      fragment("? = '{}'", s.locked_to_users) or
        fragment("? = ANY(?)", ^user_id, s.locked_to_users) or
        s.is_elsewhere == true
    )
  end

  defp group_and_create_snippets(posts, query) do
    posts
    |> Enum.group_by(& &1.scene_id)
    |> Enum.map(fn {scene_id, scene_posts} ->
      # Take up to 3 most recent matching posts
      snippets =
        scene_posts
        |> Enum.sort_by(& &1.posted_at, {:desc, DateTime})
        |> Enum.take(3)
        |> Enum.map(fn post ->
          # Extract snippet around the match
          content =
            cond do
              post.content &&
                  String.contains?(String.downcase(post.content), String.downcase(query)) ->
                post.content

              post.ooc_content &&
                  String.contains?(String.downcase(post.ooc_content), String.downcase(query)) ->
                post.ooc_content

              true ->
                post.content || post.ooc_content
            end

          snippet = extract_snippet(content, query, 150)

          # Determine author display: user nickname, narrative author, or post type label
          author =
            cond do
              post.user_nickname ->
                post.user_nickname

              post.narrative_author_name && post.narrative_author_name != "" ->
                post.narrative_author_name

              post.post_type == :narrative ->
                "narration"

              post.post_type == :system ->
                "system"

              true ->
                "unknown"
            end

          %{
            post_id: post.post_id,
            snippet: snippet,
            posted_at: post.posted_at,
            author: author,
            post_type: post.post_type
          }
        end)

      first_post = List.first(scene_posts)

      # Calculate week for Elsewhere posts
      week_date =
        if first_post.is_elsewhere do
          posted_date = DateTime.to_date(first_post.posted_at)
          day_of_week = Date.day_of_week(posted_date)
          days_to_subtract = day_of_week - 1
          Date.add(posted_date, -days_to_subtract)
        else
          nil
        end

      %{
        scene_id: scene_id,
        scene_name: first_post.scene_name,
        scene_slug: first_post.scene_slug,
        is_elsewhere: first_post.is_elsewhere,
        week_date: week_date,
        snippets: snippets
      }
    end)
  end

  # Helper function to extract a snippet around the search term
  defp extract_snippet(content, query, max_length) do
    content = content || ""
    query_lower = String.downcase(query)
    content_lower = String.downcase(content)

    case :binary.match(content_lower, query_lower) do
      {pos, len} ->
        # Calculate start and end positions for snippet
        start_pos = max(0, pos - div(max_length - len, 2))
        end_pos = min(String.length(content), start_pos + max_length)

        # Adjust start_pos if we're at the end
        start_pos = max(0, end_pos - max_length)

        snippet = String.slice(content, start_pos, max_length)

        # Add ellipsis if truncated
        snippet =
          cond do
            start_pos > 0 && end_pos < String.length(content) -> "..." <> snippet <> "..."
            start_pos > 0 -> "..." <> snippet
            end_pos < String.length(content) -> snippet <> "..."
            true -> snippet
          end

        snippet

      :nomatch ->
        # Fallback: return first max_length characters
        content
        |> String.slice(0, max_length)
        |> then(fn s -> if String.length(content) > max_length, do: s <> "...", else: s end)
    end
  end
end
