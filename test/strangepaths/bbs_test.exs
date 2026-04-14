defmodule Strangepaths.BBSTest do
  use Strangepaths.DataCase

  alias Strangepaths.BBS
  alias Strangepaths.Accounts

  import Strangepaths.BBSFixtures

  describe "boards" do
    test "list_boards/0 returns all boards" do
      board = board_fixture(%{name: "General"})
      results = BBS.list_boards()

      # Check that at least our board is in the list
      board_names = Enum.map(results, & &1.board.name)
      assert "General" in board_names
    end

    test "get_board!/1 returns board by id" do
      board = board_fixture(%{name: "Test Board"})
      retrieved = BBS.get_board!(board.id)

      assert retrieved.id == board.id
      assert retrieved.name == "Test Board"
    end

    test "get_board_by_slug!/1 returns board by slug" do
      board = board_fixture(%{name: "Test Board"})
      retrieved = BBS.get_board_by_slug!(board.slug)

      assert retrieved.id == board.id
      assert retrieved.slug == "test-board"
    end

    test "create_board/1 with valid data creates a board" do
      {:ok, board} = BBS.create_board(%{name: "New Board", description: "A new board"})

      assert board.name == "New Board"
      assert board.slug == "new-board"
      assert board.description == "A new board"
    end

    test "create_board/1 with invalid data returns error changeset" do
      {:error, changeset} = BBS.create_board(%{name: ""})

      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "change_board/1 returns a board changeset" do
      board = board_fixture()
      changeset = BBS.change_board(board)

      assert %Ecto.Changeset{} = changeset
    end
  end

  describe "threads" do
    test "list_threads/2 returns all threads for a board (nil user)" do
      board = board_fixture()
      user = user_fixture()
      thread1 = thread_fixture(board, user, %{"title" => "Thread 1"})
      thread2 = thread_fixture(board, user, %{"title" => "Thread 2"})

      threads = BBS.list_threads(board, nil)
      thread_titles = Enum.map(threads, & &1.title)

      assert "Thread 1" in thread_titles
      assert "Thread 2" in thread_titles
    end

    test "list_threads/2 returns threads for authenticated user" do
      board = board_fixture()
      user = user_fixture()
      thread = thread_fixture(board, user)

      threads = BBS.list_threads(board, user)

      assert Enum.count(threads) >= 1
      assert Enum.any?(threads, &(&1.id == thread.id))
    end

    test "list_threads_with_unread_counts/2 returns unread counts for guest" do
      board = board_fixture()
      user = user_fixture()
      _thread = thread_fixture(board, user)

      results = BBS.list_threads_with_unread_counts(board, nil)

      assert Enum.all?(results, &(&1.unread_count == 0))
    end

    test "list_threads_with_unread_counts/2 returns unread counts for user" do
      board = board_fixture()
      user = user_fixture()
      thread = thread_fixture(board, user)

      results = BBS.list_threads_with_unread_counts(board, user)

      # Should have at least the thread we created
      thread_result = Enum.find(results, &(&1.thread.id == thread.id))
      assert thread_result is not nil
    end

    test "get_thread!/1 returns thread by id" do
      thread = thread_fixture()
      retrieved = BBS.get_thread!(thread.id)

      assert retrieved.id == thread.id
    end

    test "create_thread/3 creates a thread and first post" do
      board = board_fixture()
      user = user_fixture()

      {:ok, {thread, post}} =
        BBS.create_thread(board, user, %{
          "title" => "New Thread",
          "content" => "Thread content",
          "display_name" => "DisplayName"
        })

      assert thread.title == "New Thread"
      assert thread.board_id == board.id
      assert thread.user_id == user.id
      assert thread.post_count == 1
      assert post.content == "Thread content"
      assert post.display_name == "DisplayName"
    end

    test "change_thread/1 returns a thread changeset" do
      thread = thread_fixture()
      changeset = BBS.change_thread(thread)

      assert %Ecto.Changeset{} = changeset
    end
  end

  describe "posts" do
    test "list_posts/1 returns all posts in a thread" do
      thread = thread_fixture()
      user = user_fixture()
      _post1 = post_fixture(thread, user, %{"content" => "Post 1"})
      _post2 = post_fixture(thread, user, %{"content" => "Post 2"})

      posts = BBS.list_posts(thread.id)

      assert Enum.count(posts) == 3  # 1 from thread creation + 2 new posts
      contents = Enum.map(posts, & &1.content)
      assert "Post 1" in contents
      assert "Post 2" in contents
    end

    test "get_post!/1 returns post by id" do
      post = post_fixture()
      retrieved = BBS.get_post!(post.id)

      assert retrieved.id == post.id
    end

    test "create_post/3 creates a post and updates thread" do
      thread = thread_fixture()
      user = user_fixture()

      {:ok, post} =
        BBS.create_post(thread, user, %{
          "content" => "New post",
          "display_name" => "User123"
        })

      assert post.content == "New post"
      assert post.thread_id == thread.id
      assert post.user_id == user.id

      updated_thread = BBS.get_thread!(thread.id)
      assert updated_thread.post_count == 2  # 1 from creation + 1 new
    end

    test "update_post/3 updates post content and marks as edited" do
      post = post_fixture()
      user = user_fixture()

      {:ok, updated_post} = BBS.update_post(post, user, %{"content" => "Updated content"})

      assert updated_post.content == "Updated content"
      assert updated_post.edited_by_id == user.id
      assert updated_post.edited_at is not nil
    end

    test "delete_post/1 deletes post and decrements thread count" do
      thread = thread_fixture()
      post = post_fixture(thread)

      initial_count = thread.post_count
      BBS.delete_post(post)
      updated_thread = BBS.get_thread!(thread.id)

      assert updated_thread.post_count == initial_count - 1
    end

    test "get_post_for_quote/1 returns post with quote context" do
      thread = thread_fixture()
      post = post_fixture(thread, nil, %{"content" => "Quote me"})

      quote_info = BBS.get_post_for_quote(post.id)

      assert quote_info.id == post.id
      assert quote_info.content == "Quote me"
      assert quote_info.thread_id == thread.id
    end
  end

  describe "stickies" do
    test "toggle_sticky/2 creates sticky when none exists" do
      user = user_fixture()
      thread = thread_fixture()

      {:ok, sticky} = BBS.toggle_sticky(user.id, thread.id)

      assert sticky.user_id == user.id
      assert sticky.thread_id == thread.id
    end

    test "toggle_sticky/2 deletes sticky when exists" do
      user = user_fixture()
      thread = thread_fixture()

      {:ok, _sticky} = BBS.toggle_sticky(user.id, thread.id)
      {:ok, _} = BBS.toggle_sticky(user.id, thread.id)

      # Verify it was deleted by trying to toggle again (should create new)
      {:ok, new_sticky} = BBS.toggle_sticky(user.id, thread.id)
      assert new_sticky.id is not nil
    end

    test "user_sticky_thread_ids/1 returns set of stickied thread ids" do
      user = user_fixture()
      thread1 = thread_fixture()
      thread2 = thread_fixture()

      {:ok, _} = BBS.toggle_sticky(user.id, thread1.id)
      {:ok, _} = BBS.toggle_sticky(user.id, thread2.id)

      sticky_ids = BBS.user_sticky_thread_ids(user.id)

      assert MapSet.member?(sticky_ids, thread1.id)
      assert MapSet.member?(sticky_ids, thread2.id)
    end
  end

  describe "dragon moderation" do
    test "pin_thread/1 pins a thread" do
      thread = thread_fixture()

      {:ok, pinned} = BBS.pin_thread(thread)

      assert pinned.is_pinned == true
    end

    test "unpin_thread/1 unpins a thread" do
      thread = thread_fixture()
      {:ok, pinned} = BBS.pin_thread(thread)

      {:ok, unpinned} = BBS.unpin_thread(pinned)

      assert unpinned.is_pinned == false
    end

    test "lock_thread/1 locks a thread" do
      thread = thread_fixture()

      {:ok, locked} = BBS.lock_thread(thread)

      assert locked.is_locked == true
    end

    test "unlock_thread/1 unlocks a thread" do
      thread = thread_fixture()
      {:ok, locked} = BBS.lock_thread(thread)

      {:ok, unlocked} = BBS.unlock_thread(locked)

      assert unlocked.is_locked == false
    end

    test "delete_thread/1 deletes a thread" do
      thread = thread_fixture()

      {:ok, _} = BBS.delete_thread(thread)

      assert_raise Ecto.NoResultsError, fn ->
        BBS.get_thread!(thread.id)
      end
    end
  end

  describe "read marks" do
    test "upsert_read_mark/2 creates a new read mark" do
      user = user_fixture()
      thread = thread_fixture()

      {:ok, mark} = BBS.upsert_read_mark(user.id, thread.id)

      assert mark.user_id == user.id
      assert mark.thread_id == thread.id
      assert mark.last_read_at is not nil
    end

    test "upsert_read_mark/2 updates existing read mark" do
      user = user_fixture()
      thread = thread_fixture()

      {:ok, mark1} = BBS.upsert_read_mark(user.id, thread.id)
      :timer.sleep(10)
      {:ok, mark2} = BBS.upsert_read_mark(user.id, thread.id)

      assert mark1.id == mark2.id
      # mark2's timestamp should be newer or equal
      assert DateTime.compare(mark2.last_read_at, mark1.last_read_at) in [:eq, :gt]
    end

    test "advance_read_mark/4 updates read mark with specific post" do
      user = user_fixture()
      thread = thread_fixture()
      post = post_fixture(thread)

      {:ok, mark} = BBS.advance_read_mark(user.id, thread.id, post.id, post.posted_at)

      assert mark.last_read_post_id == post.id
    end

    test "get_read_mark/2 returns read mark" do
      user = user_fixture()
      thread = thread_fixture()

      {:ok, _mark} = BBS.upsert_read_mark(user.id, thread.id)
      retrieved = BBS.get_read_mark(user.id, thread.id)

      assert retrieved is not nil
      assert retrieved.user_id == user.id
      assert retrieved.thread_id == thread.id
    end

    test "get_read_mark/2 returns nil when no read mark" do
      user = user_fixture()
      thread = thread_fixture()

      result = BBS.get_read_mark(user.id, thread.id)

      assert result is nil
    end
  end
end
