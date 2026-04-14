defmodule Strangepaths.BBS do
  @moduledoc """
  The BBS context for managing forum boards, threads, and posts.
  """

  import Ecto.Query
  alias Strangepaths.Repo
  alias Strangepaths.BBS.{Board, Thread, Post, UserThreadSticky, ThreadReadMark}

  # === BOARDS ===

  @doc """
  Returns all boards with thread counts and last post times.
  Results are ordered by board name.
  """
  def list_boards() do
    from(b in Board,
      left_join: t in Thread,
      on: t.board_id == b.id,
      group_by: b.id,
      select: %{board: b, thread_count: count(t.id), last_post_at: max(t.last_post_at)},
      order_by: [asc: b.name]
    )
    |> Repo.all()
  end

  @doc """
  Gets a single board by id.
  Raises Ecto.NoResultsError if not found.
  """
  def get_board!(id), do: Repo.get!(Board, id)

  @doc """
  Gets a single board by slug.
  Returns nil if not found.
  """
  def get_board_by_slug(slug) do
    Repo.get_by(Board, slug: slug)
  end

  @doc """
  Gets a single board by slug.
  Raises Ecto.NoResultsError if not found.
  """
  def get_board_by_slug!(slug) do
    Repo.get_by!(Board, slug: slug)
  end

  @doc """
  Creates a new board with the given attributes.
  """
  def create_board(attrs) do
    %Board{}
    |> Board.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns a changeset for board creation/update.
  """
  def change_board(board \\ %Board{}, attrs \\ %{}) do
    Board.changeset(board, attrs)
  end

  # === THREADS ===

  @doc """
  Lists all threads in a board.
  For unauthenticated users: threads ordered pinned first, then by last_post_at descending.
  For authenticated users: threads ordered pinned first, stickied by user second, then by last_post_at descending.
  """
  def list_threads(%Board{} = board, nil) do
    from(t in Thread,
      where: t.board_id == ^board.id,
      order_by: [desc: t.is_pinned, desc: t.last_post_at],
      preload: [:user]
    )
    |> Repo.all()
  end

  def list_threads(%Board{} = board, user) do
    user_id = user.id

    from(t in Thread,
      left_join: s in UserThreadSticky,
      on: s.thread_id == t.id and s.user_id == ^user_id,
      where: t.board_id == ^board.id,
      order_by: [desc: t.is_pinned, desc: not is_nil(s.id), desc: t.last_post_at],
      preload: [:user]
    )
    |> Repo.all()
  end

  @doc """
  Lists threads with unread post counts.
  For guests: all threads have unread_count: 0.
  For authenticated users: unread count calculated as posts after last_read_post_id or total count if no read mark.
  """
  def list_threads_with_unread_counts(%Board{} = board, nil) do
    from(t in Thread,
      where: t.board_id == ^board.id,
      order_by: [desc: t.is_pinned, desc: t.last_post_at],
      preload: [:user]
    )
    |> Repo.all()
    |> Enum.map(fn thread -> %{thread: thread, is_stickied: false, unread_count: 0} end)
  end

  def list_threads_with_unread_counts(%Board{} = board, user) do
    user_id = user.id

    from(t in Thread,
      left_join: s in UserThreadSticky,
      on: s.thread_id == t.id and s.user_id == ^user_id,
      left_join: rm in ThreadReadMark,
      on: rm.thread_id == t.id and rm.user_id == ^user_id,
      where: t.board_id == ^board.id,
      order_by: [desc: t.is_pinned, desc: not is_nil(s.id), desc: t.last_post_at],
      select: %{
        thread: t,
        is_stickied: not is_nil(s.id),
        unread_count:
          fragment(
            "CASE WHEN ? IS NULL THEN ? ELSE (SELECT COUNT(*) FROM bbs_posts p WHERE p.thread_id = ? AND p.id > ?) END",
            rm.id,
            t.post_count,
            t.id,
            rm.last_read_post_id
          )
      },
      preload: [thread: :user]
    )
    |> Repo.all()
  end

  @doc """
  Gets a single thread by id.
  Returns nil if not found.
  """
  def get_thread(id) do
    Repo.get(Thread, id) |> Repo.preload(:board)
  end

  @doc """
  Gets a single thread by id.
  Raises Ecto.NoResultsError if not found.
  """
  def get_thread!(id), do: Repo.get!(Thread, id) |> Repo.preload(:board)

  @doc """
  Creates a new thread in the given board by the given user.
  Also creates the first post in the thread.
  Returns {:ok, {thread, post}} on success.
  """
  def create_thread(%Board{} = board, user, attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    thread_attrs = Map.merge(attrs, %{"board_id" => board.id, "user_id" => user.id})

    Repo.transaction(fn ->
      thread =
        %Thread{}
        |> Thread.create_changeset(thread_attrs)
        |> Ecto.Changeset.put_change(:last_post_at, now)
        |> Ecto.Changeset.put_change(:post_count, 1)
        |> Repo.insert!()

      post_attrs = %{
        "thread_id" => thread.id,
        "user_id" => user.id,
        "display_name" => attrs["display_name"] || attrs[:display_name] || user.nickname,
        "character_name" => user.nickname,
        "content" => attrs["content"] || attrs[:content] || "",
        "posted_at" => now
      }

      post =
        %Post{}
        |> Post.create_changeset(post_attrs)
        |> Repo.insert!()

      {thread, post}
    end)
  end

  @doc """
  Returns a changeset for thread creation.
  """
  def change_thread(thread \\ %Thread{}, attrs \\ %{}) do
    Thread.create_changeset(thread, attrs)
  end

  @doc """
  Returns a changeset for post creation/validation.
  """
  def change_post(post \\ %Post{}, attrs \\ %{}) do
    Post.create_changeset(post, attrs)
  end

  # === POSTS ===

  @doc """
  Lists all posts in a thread, ordered by posted_at ascending.
  """
  def list_posts(thread_id) do
    from(p in Post,
      where: p.thread_id == ^thread_id,
      order_by: [asc: p.posted_at],
      preload: [:user, :edited_by]
    )
    |> Repo.all()
  end

  @doc """
  Creates a new post in the given thread by the given user.
  Updates the thread's last_post_at and post_count.
  Broadcasts "new_post" event on bbs_thread:{thread_id}.
  Returns {:ok, post} on success.
  """
  def create_post(%Thread{} = thread, user, attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    post_attrs = %{
      "thread_id" => thread.id,
      "user_id" => user.id,
      "display_name" => attrs["display_name"] || attrs[:display_name] || user.nickname,
      "character_name" => user.nickname,
      "content" => attrs["content"] || attrs[:content],
      "posted_at" => now
    }

    result =
      Repo.transaction(fn ->
        # Lock the thread row to prevent concurrent post_count drift
        Repo.one!(from(t in Thread, where: t.id == ^thread.id, lock: "FOR UPDATE"))

        post =
          %Post{}
          |> Post.create_changeset(post_attrs)
          |> Repo.insert!()

        from(t in Thread, where: t.id == ^thread.id)
        |> Repo.update_all(set: [last_post_at: now], inc: [post_count: 1])

        Repo.preload(post, :user)
      end)

    case result do
      {:ok, post} ->
        StrangepathsWeb.Endpoint.broadcast("bbs_thread:#{thread.id}", "new_post", %{post: post})
        {:ok, post}

      error ->
        error
    end
  end

  @doc """
  Updates a post with new content and marks it as edited.
  Preloads user and edited_by associations on the updated post.
  Returns {:ok, updated_post} on success.
  """
  def update_post(%Post{} = post, editor, attrs) do
    # Normalize all keys to strings to match changeset expectations
    edit_attrs =
      attrs
      |> Map.new(fn {k, v} -> {to_string(k), v} end)
      |> Map.put("edited_by_id", editor.id)

    case post |> Post.edit_changeset(edit_attrs) |> Repo.update() do
      {:ok, updated_post} ->
        {:ok, Repo.preload(updated_post, [:user, :edited_by])}

      error ->
        error
    end
  end

  @doc """
  Deletes a post and decrements the thread's post_count.
  Recomputes last_post_at from remaining posts.
  Returns {:error, :would_empty_thread} if this is the only post in the thread.
  """
  def delete_post(%Post{} = post) do
    # Check if this is the only post in the thread
    if post_is_only_one?(post.thread_id) do
      {:error, :would_empty_thread}
    else
      Repo.transaction(fn ->
        thread_id = post.thread_id

        # Lock the thread row to prevent concurrent post_count drift
        Repo.one!(from(t in Thread, where: t.id == ^thread_id, lock: "FOR UPDATE"))

        Repo.delete!(post)

        from(t in Thread, where: t.id == ^thread_id)
        |> Repo.update_all(inc: [post_count: -1])

        # Recompute last_post_at from remaining posts
        new_last =
          from(p in Post, where: p.thread_id == ^thread_id, select: max(p.posted_at))
          |> Repo.one()

        if new_last do
          from(t in Thread, where: t.id == ^thread_id)
          |> Repo.update_all(set: [last_post_at: new_last])
        end
      end)
    end
  end

  defp post_is_only_one?(thread_id) do
    from(p in Post, where: p.thread_id == ^thread_id, select: count(p.id))
    |> Repo.one() == 1
  end

  @doc """
  Gets a single post by id with user and edited_by preloaded.
  Raises Ecto.NoResultsError if not found.
  """
  def get_post!(id), do: Repo.get!(Post, id) |> Repo.preload([:user, :edited_by])

  @doc """
  Gets a post for quote context (board slug, thread id, content, etc.).
  Returns a map with relevant quote information.
  """
  def get_post_for_quote(post_id) do
    from(p in Post,
      where: p.id == ^post_id,
      join: t in Thread,
      on: t.id == p.thread_id,
      join: b in Board,
      on: b.id == t.board_id,
      select: %{
        id: p.id,
        display_name: p.display_name,
        character_name: p.character_name,
        content: p.content,
        thread_id: t.id,
        board_slug: b.slug
      }
    )
    |> Repo.one()
  end

  # === STICKIES ===

  @doc """
  Toggles the sticky status of a thread for a user.
  If sticky exists, deletes it. Otherwise creates it.
  Returns {:ok, sticky} or {:ok, :deleted}.
  """
  def toggle_sticky(user_id, thread_id) do
    case Repo.get_by(UserThreadSticky, user_id: user_id, thread_id: thread_id) do
      nil ->
        %UserThreadSticky{}
        |> UserThreadSticky.changeset(%{user_id: user_id, thread_id: thread_id})
        |> Repo.insert()

      sticky ->
        Repo.delete(sticky)
    end
  end

  @doc """
  Returns a MapSet of all thread IDs stickied by the given user.
  """
  def user_sticky_thread_ids(user_id) do
    from(s in UserThreadSticky, where: s.user_id == ^user_id, select: s.thread_id)
    |> Repo.all()
    |> MapSet.new()
  end

  # === DRAGON MODERATION ===

  @doc """
  Pins a thread (dragon only).
  """
  def pin_thread(%Thread{} = thread) do
    thread |> Thread.dragon_changeset(%{is_pinned: true}) |> Repo.update()
  end

  @doc """
  Unpins a thread (dragon only).
  """
  def unpin_thread(%Thread{} = thread) do
    thread |> Thread.dragon_changeset(%{is_pinned: false}) |> Repo.update()
  end

  @doc """
  Locks a thread (dragon only).
  """
  def lock_thread(%Thread{} = thread) do
    thread |> Thread.dragon_changeset(%{is_locked: true}) |> Repo.update()
  end

  @doc """
  Unlocks a thread (dragon only).
  """
  def unlock_thread(%Thread{} = thread) do
    thread |> Thread.dragon_changeset(%{is_locked: false}) |> Repo.update()
  end

  @doc """
  Deletes a thread and all its posts (dragon only).
  """
  def delete_thread(%Thread{} = thread) do
    Repo.delete(thread)
  end

  # === READ MARKS ===

  @doc """
  Upserts a read mark for the given user and thread to the current wall-clock time.
  Sets last_read_post_id to the ID of the latest post in the thread.
  Used when user visits/opens a thread.
  """
  def upsert_read_mark(user_id, thread_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    latest_post_id =
      from(p in Post,
        where: p.thread_id == ^thread_id,
        select: max(p.id)
      )
      |> Repo.one()

    fields = %{
      user_id: user_id,
      thread_id: thread_id,
      last_read_at: now,
      last_read_post_id: latest_post_id
    }

    update_query =
      from(rm in ThreadReadMark,
        update: [
          set: [
            last_read_at: ^now,
            last_read_post_id:
              fragment(
                "GREATEST(EXCLUDED.last_read_post_id, ?)",
                rm.last_read_post_id
              )
          ]
        ]
      )

    %ThreadReadMark{}
    |> ThreadReadMark.changeset(fields)
    |> Repo.insert(
      on_conflict: update_query,
      conflict_target: [:user_id, :thread_id]
    )
  end

  @doc """
  Advances a read mark to a specific post, using that post's posted_at as the timestamp.
  Used when user scrolls to view a specific post.
  Preserves unread count for posts newer than this post.
  """
  def advance_read_mark(user_id, thread_id, post_id, %DateTime{} = posted_at) do
    posted_at_trunc = DateTime.truncate(posted_at, :second)

    fields = %{
      user_id: user_id,
      thread_id: thread_id,
      last_read_at: posted_at_trunc,
      last_read_post_id: post_id
    }

    update_query =
      from(rm in ThreadReadMark,
        update: [
          set: [
            last_read_at: ^posted_at_trunc,
            last_read_post_id:
              fragment(
                "GREATEST(EXCLUDED.last_read_post_id, ?)",
                rm.last_read_post_id
              )
          ]
        ]
      )

    %ThreadReadMark{}
    |> ThreadReadMark.changeset(fields)
    |> Repo.insert(
      on_conflict: update_query,
      conflict_target: [:user_id, :thread_id]
    )
  end

  @doc """
  Gets the read mark for a user/thread pair, or nil if none exists.
  """
  def get_read_mark(user_id, thread_id) do
    Repo.get_by(ThreadReadMark, user_id: user_id, thread_id: thread_id)
  end
end
