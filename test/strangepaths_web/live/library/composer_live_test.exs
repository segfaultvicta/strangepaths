defmodule StrangepathsWeb.LibraryLive.ComposerTest do
  use StrangepathsWeb.ConnCase

  import Phoenix.LiveViewTest
  import Strangepaths.AccountsFixtures
  import Strangepaths.LibraryFixtures

  alias Strangepaths.Library

  # Verifies: liminal-library.AC4.1
  describe "GET /library/:slug/compose" do
    test "folio editor can access composer", %{conn: conn} do
      user = user_typeface_fixture()
      folio = folio_fixture(user, %{"title" => "Composer Access Test"})
      conn = log_in_user(conn, user)

      {:ok, _view, html} = live(conn, "/library/#{folio.slug}/compose")
      assert html =~ "Scene Browser"
      assert html =~ "Composing: Composer Access Test"
    end

    test "non-folio-editor is redirected", %{conn: conn} do
      author = user_typeface_fixture()
      folio = folio_fixture(author, %{"title" => "Composer Redirect Test"})
      other_user = user_fixture()
      conn = log_in_user(conn, other_user)

      # Non-editors get rejected at mount with a redirect error
      result = live(conn, "/library/#{folio.slug}/compose")
      assert {:error, {:live_redirect, %{to: "/library/" <> _}}} = result
    end

    test "unauthenticated user is redirected", %{conn: conn} do
      user = user_typeface_fixture()
      folio = folio_fixture(user, %{"title" => "Composer Auth Test"})

      # Unauthenticated users get rejected at mount with a redirect error
      result = live(conn, "/library/#{folio.slug}/compose")
      assert {:error, {:live_redirect, %{to: "/library/" <> _}}} = result
    end
  end

  # Verifies: liminal-library.AC4.2 (filter)
  describe "scene filtering" do
    test "filter input is present and responds to events", %{conn: conn} do
      user = user_typeface_fixture()
      folio = folio_fixture(user, %{"title" => "Filter Test Folio"})
      conn = log_in_user(conn, user)

      {:ok, view, html} = live(conn, "/library/#{folio.slug}/compose")

      # Verify filter input exists
      assert html =~ "Filter by title or tag..."

      # Trigger filter change by sending an event to the input
      view
      |> element("form[phx-change='set_filter']")
      |> render_change(%{"q" => "nonexistent_xyz_term"})

      # Just verify it doesn't crash and recomputes
      html = render(view)
      assert html =~ "Scene Browser"
    end

    # Verifies: liminal-library.AC4.2 — full-cast-session tag always shows in filter_scenes logic
    test "filter_scenes logic preserves full-cast-session scenes", %{conn: conn} do
      user = user_typeface_fixture()
      other_user = user_typeface_fixture()
      folio = folio_fixture(user, %{"title" => "Filter Logic Test"})
      conn = log_in_user(conn, user)

      # Create a full-cast-session scene (should survive filter)
      {:ok, full_cast_scene} = Strangepaths.Scenes.create_scene(%{
        name: "Visible Cast Scene",
        owner_id: user.id,
        locked_to_users: []
      })
      # Tags are not cast in create_changeset; apply them via add_tag_to_scene/2
      {:ok, full_cast_scene} = Strangepaths.Scenes.add_tag_to_scene(full_cast_scene, "full cast session")
      {:ok, _full_cast_post} = Strangepaths.Scenes.create_character_post(%{
        scene_id: full_cast_scene.id,
        user_id: user.id,
        content: "Full cast post",
        author_nickname: user.nickname
      })

      # Create a non-full-cast scene (should be filtered out)
      {:ok, hidden_scene} = Strangepaths.Scenes.create_scene(%{
        name: "Hidden Scene",
        owner_id: other_user.id,
        locked_to_users: []
      })
      {:ok, _hidden_post} = Strangepaths.Scenes.create_character_post(%{
        scene_id: hidden_scene.id,
        user_id: other_user.id,
        content: "Hidden post",
        author_nickname: other_user.nickname
      })

      {:ok, view, html} = live(conn, "/library/#{folio.slug}/compose")

      # Both scenes should be visible initially (no filter applied)
      assert html =~ "Visible Cast Scene"
      assert html =~ "Hidden Scene"

      # Apply a filter query that matches neither scene name
      view
      |> element("form[phx-change='set_filter']")
      |> render_change(%{"q" => "zzznomatch"})

      # Render the view after filter change to see updated state
      html = render(view)

      # Full-cast scene should survive filter even though name doesn't match query
      assert html =~ "Visible Cast Scene"
      # Non-full-cast scene should be filtered out because its name doesn't match and it's not full-cast
      refute html =~ "Hidden Scene"
    end
  end

  # Verifies: liminal-library.AC4.3 (full-cast scene CSS class in template)
  describe "full-cast scene styling" do
    test "template conditional renders bg-emerald classes when full cast session in tags", %{conn: conn} do
      user = user_typeface_fixture()
      other_user = user_typeface_fixture()
      folio = folio_fixture(user, %{"title" => "Full Cast CSS Test"})
      conn = log_in_user(conn, user)

      # Create one full-cast-session scene with a post
      {:ok, full_cast_scene} = Strangepaths.Scenes.create_scene(%{
        name: "Full Cast Styled Scene",
        owner_id: user.id,
        locked_to_users: []
      })
      # Tags are not cast in create_changeset; apply them via add_tag_to_scene/2
      {:ok, full_cast_scene} = Strangepaths.Scenes.add_tag_to_scene(full_cast_scene, "full cast session")
      {:ok, _full_cast_post} = Strangepaths.Scenes.create_character_post(%{
        scene_id: full_cast_scene.id,
        user_id: user.id,
        content: "Full cast content",
        author_nickname: user.nickname
      })

      # Create one non-full-cast scene with a post
      {:ok, ordinary_scene} = Strangepaths.Scenes.create_scene(%{
        name: "Ordinary Scene",
        owner_id: other_user.id,
        locked_to_users: []
      })
      {:ok, _ordinary_post} = Strangepaths.Scenes.create_character_post(%{
        scene_id: ordinary_scene.id,
        user_id: other_user.id,
        content: "Ordinary content",
        author_nickname: other_user.nickname
      })

      {:ok, _view, html} = live(conn, "/library/#{folio.slug}/compose")

      # The full-cast scene should have the emerald styling classes
      assert html =~ "Full Cast Styled Scene"
      assert html =~ "bg-emerald-950/30"
      assert html =~ "border-emerald-900/50"

      # The ordinary scene should also be rendered
      assert html =~ "Ordinary Scene"

      # Verify the emerald classes appear in the full-cast section only
      # Split by the full-cast scene name and check the before section has the classes
      [before_cast, _after_cast] = String.split(html, "Full Cast Styled Scene")
      assert before_cast =~ "bg-emerald-950/30"

      # Count how many times bg-emerald-950/30 appears: should be just 1 time total
      emerald_count = html |> String.split("bg-emerald-950/30") |> length() |> Kernel.-(1)
      assert emerald_count == 1
    end
  end

  # Verifies: liminal-library.AC4.5 (add_post at caret position)
  describe "add_post event" do
    test "creates a post_ref entry at the current caret position", %{conn: conn} do
      user = user_typeface_fixture()
      folio = folio_fixture(user, %{"title" => "Add Post Position Test"})
      conn = log_in_user(conn, user)

      # Create a scene with a post
      {:ok, scene} = Strangepaths.Scenes.create_scene(%{
        name: "Test Scene",
        owner_id: user.id,
        locked_to_users: [],
        tags: []
      })
      {:ok, scene_post} = Strangepaths.Scenes.create_character_post(%{
        scene_id: scene.id,
        user_id: user.id,
        content: "Test post content",
        author_nickname: user.nickname
      })

      {:ok, view, html} = live(conn, "/library/#{folio.slug}/compose")

      # Caret should start at position 1 (after zero entries)
      assert html =~ "Caret at position 1"

      # Expand the scene first to see the posts in the browser using expand_scene button
      view
      |> element("button[phx-click='expand_scene'][phx-value-scene-id='#{scene.id}']")
      |> render_click()

      # Trigger add_post event with the scene post id at current caret position 1
      view
      |> element("div#composer-entry-list")
      |> render_hook("add_post", %{"post-id" => to_string(scene_post.id)})

      # Verify entry was created in the database at position 1
      entries = Library.list_entries(folio.id)
      assert length(entries) == 1
      entry = hd(entries)
      assert entry.kind == :post_ref
      assert entry.scene_post_id == scene_post.id
      assert entry.position == 1
    end
  end

  # Verifies: liminal-library.AC4.6 (shift-click range selection)
  describe "shift-click range selection" do
    test "shift-click from anchor to post inserts contiguous post_ref entries", %{conn: conn} do
      user = user_typeface_fixture()
      folio = folio_fixture(user, %{"title" => "Range Select Test"})
      conn = log_in_user(conn, user)

      # Create a scene with 3 posts
      {:ok, scene} = Strangepaths.Scenes.create_scene(%{
        name: "Test Scene",
        owner_id: user.id,
        locked_to_users: [],
        tags: []
      })

      post_ids = for i <- 1..3 do
        {:ok, post} = Strangepaths.Scenes.create_character_post(%{
          scene_id: scene.id,
          user_id: user.id,
          content: "Post #{i}",
          author_nickname: user.nickname
        })
        post.id
      end

      {:ok, view, _html} = live(conn, "/library/#{folio.slug}/compose")

      # Expand the scene to load the posts into the cache using expand_scene button
      view
      |> element("button[phx-click='expand_scene'][phx-value-scene-id='#{scene.id}']")
      |> render_click()

      # Set anchor to first post
      view
      |> element("div#composer-entry-list")
      |> render_hook("set_range_anchor", %{"post-id" => to_string(Enum.at(post_ids, 0))})

      # Shift-click to the third post to select the range
      view
      |> element("div#composer-entry-list")
      |> render_hook("shift_select_post", %{
        "post-id" => to_string(Enum.at(post_ids, 2)),
        "scene-id" => to_string(scene.id)
      })

      # Verify 3 post_ref entries were created with contiguous positions
      entries = Library.list_entries(folio.id)
      assert length(entries) == 3

      # Check that positions are 1, 2, 3 (contiguous)
      positions = entries |> Enum.map(& &1.position) |> Enum.sort()
      assert positions == [1, 2, 3]

      # Verify all are post_ref entries
      Enum.each(entries, fn entry ->
        assert entry.kind == :post_ref
      end)
    end
  end

  # Verifies: liminal-library.AC5.1 (any folio editor can add entries)
  describe "adding entries" do
    test "folio editor can see the note form when caret is positioned", %{conn: conn} do
      user = user_typeface_fixture()
      folio = folio_fixture(user, %{"title" => "Note Add Test"})
      _note = note_entry_fixture(folio, user, %{"content" => "First entry"})
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, "/library/#{folio.slug}/compose")

      # Initially caret is at position 2 (after the first entry)
      # Click the second caret slot to move caret to position 2
      view
      |> element("div[phx-value-position='2']")
      |> render_click()

      # Now the form should appear
      html = render(view)
      assert html =~ "Add inline note..."
    end

    test "adding a note via server event creates entry in database", %{conn: conn} do
      user = user_typeface_fixture()
      folio = folio_fixture(user, %{"title" => "Note Create Test"})
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, "/library/#{folio.slug}/compose")

      # Verify initially no entries
      entries = Library.list_entries(folio.id)
      assert length(entries) == 0

      # Trigger the add_note event on the LiveView directly
      view
      |> element("div#composer-entry-list")
      |> render_hook("add_note", %{
        "note" => %{"content" => "My test note"},
        "position" => "1"
      })

      # Verify entry was created
      entries = Library.list_entries(folio.id)
      assert length(entries) == 1
      assert hd(entries).kind == :note
      assert hd(entries).content == "My test note"
    end
  end

  # Verifies: liminal-library.AC5.2 and AC5.3 (entry deletion permissions)
  describe "entry deletion permissions" do
    test "author can see and delete their entries", %{conn: conn} do
      user = user_typeface_fixture()
      folio = folio_fixture(user, %{"title" => "Author Delete Test"})
      _entry = note_entry_fixture(folio, user)
      conn = log_in_user(conn, user)

      {:ok, view, html} = live(conn, "/library/#{folio.slug}/compose")
      # Author should see the delete button (✕)
      assert html =~ "✕"

      # Delete the entry
      view
      |> element("button[phx-click='delete_entry']")
      |> render_click()

      assert Library.list_entries(folio.id) == []
    end

    test "non-author folio editor does not see delete button (AC5.3)", %{conn: conn} do
      author = user_typeface_fixture()
      other_editor = user_typeface_fixture()
      folio = folio_fixture(author, %{"title" => "Non Author Delete"})
      _entry = note_entry_fixture(folio, author)
      conn = log_in_user(conn, other_editor)

      {:ok, _view, html} = live(conn, "/library/#{folio.slug}/compose")
      # Non-author should NOT see the delete button
      refute html =~ "✕"
    end

    test "folio author can delete via server event (AC5.2)", %{conn: conn} do
      user = user_typeface_fixture()
      folio = folio_fixture(user, %{"title" => "Delete Via Event Test"})
      entry = note_entry_fixture(folio, user)
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, "/library/#{folio.slug}/compose")

      # Trigger delete_entry event on the LiveView
      view
      |> element("div#composer-entry-list")
      |> render_hook("delete_entry", %{
        "entry-id" => to_string(entry.id)
      })

      # Verify entry was deleted
      assert Library.list_entries(folio.id) == []
    end
  end

  # Verifies: liminal-library.AC4.4 (my scenes toggle filter)
  describe "my scenes toggle" do
    test "toggle_my_scenes event filters to only scenes where user has posted", %{conn: conn} do
      user = user_typeface_fixture()
      other_user = user_typeface_fixture()
      folio = folio_fixture(user, %{"title" => "My Scenes Test"})
      conn = log_in_user(conn, user)

      # Create a scene with a post by the logged-in user
      {:ok, user_scene} = Strangepaths.Scenes.create_scene(%{
        name: "My Scene",
        owner_id: user.id,
        locked_to_users: [],
        tags: []
      })
      {:ok, _post} = Strangepaths.Scenes.create_character_post(%{
        scene_id: user_scene.id,
        user_id: user.id,
        content: "My post",
        author_nickname: user.nickname
      })

      # Create a scene with a post by another user (not the logged-in user)
      {:ok, other_scene} = Strangepaths.Scenes.create_scene(%{
        name: "Other User Scene",
        owner_id: other_user.id,
        locked_to_users: [],
        tags: []
      })
      {:ok, _other_post} = Strangepaths.Scenes.create_character_post(%{
        scene_id: other_scene.id,
        user_id: other_user.id,
        content: "Other post",
        author_nickname: other_user.nickname
      })

      {:ok, view, html} = live(conn, "/library/#{folio.slug}/compose")

      # Initially both scenes should be visible
      assert html =~ "My Scene"
      assert html =~ "Other User Scene"

      # Toggle "Scenes I was in"
      view
      |> element("input[phx-click='toggle_my_scenes']")
      |> render_click()

      html = render(view)

      # Now only the user's scene should appear
      assert html =~ "My Scene"
      refute html =~ "Other User Scene"
    end
  end

  # Verifies: liminal-library.AC4.9 (insertion caret is placeable and persists)
  describe "caret positioning" do
    test "caret position displays and updates", %{conn: conn} do
      user = user_typeface_fixture()
      folio = folio_fixture(user, %{"title" => "Caret Position Test"})
      _note = note_entry_fixture(folio, user)
      conn = log_in_user(conn, user)

      {:ok, view, html} = live(conn, "/library/#{folio.slug}/compose")

      # Initial caret should be at position 2 (after first entry)
      assert html =~ "Caret at position 2"

      # Click the first caret slot to move to position 1
      view
      |> element("div[phx-value-position='1']")
      |> render_click()

      # Verify caret moved
      html = render(view)
      assert html =~ "Caret at position 1"
    end
  end

  # Verifies: liminal-library.AC4.7 (entries can be reordered)
  describe "entry reordering" do
    test "reorder_entries event processes order changes", %{conn: conn} do
      user = user_typeface_fixture()
      folio = folio_fixture(user, %{"title" => "Reorder Test"})
      note1 = note_entry_fixture(folio, user, %{"content" => "First"})
      note2 = note_entry_fixture(folio, user, %{"content" => "Second"})
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, "/library/#{folio.slug}/compose")

      # Verify both entries exist in original order (positions 1, 2)
      entries = Library.list_entries(folio.id)
      assert length(entries) == 2
      assert Enum.map(entries, & &1.id) == [note1.id, note2.id]

      # Simulate drag reorder by reversing the IDs
      view
      |> element("div#composer-entry-list")
      |> render_hook("reorder_entries", %{ids: "#{note2.id},#{note1.id}"})

      # Entries should be reordered with note2 first, then note1
      entries = Library.list_entries(folio.id)
      assert length(entries) == 2
      assert Enum.map(entries, & &1.id) == [note2.id, note1.id]
    end
  end

  # Verifies: liminal-library.AC4.7 (entry grouping)
  describe "entry grouping" do
    test "toggle_entry_group adds ungrouped entry to the group", %{conn: conn} do
      user = user_typeface_fixture()
      folio = folio_fixture(user, %{"title" => "Group Test"})
      entry1 = note_entry_fixture(folio, user, %{"content" => "Entry 1"})
      entry2 = note_entry_fixture(folio, user, %{"content" => "Entry 2"})
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, "/library/#{folio.slug}/compose")

      # Toggle entry1 in — creates a new group_id
      view
      |> element("div#composer-entry-list")
      |> render_hook("toggle_entry_group", %{"entry-id" => to_string(entry1.id)})

      # Toggle entry2 in — joins the existing group_id
      view
      |> element("div#composer-entry-list")
      |> render_hook("toggle_entry_group", %{"entry-id" => to_string(entry2.id)})

      entries = Library.list_entries(folio.id)
      e1 = Enum.find(entries, &(&1.id == entry1.id))
      e2 = Enum.find(entries, &(&1.id == entry2.id))
      assert e1.group_id != nil
      assert e1.group_id == e2.group_id
    end

    test "toggle_entry_group removes entry from group when already grouped", %{conn: conn} do
      user = user_typeface_fixture()
      folio = folio_fixture(user, %{"title" => "Ungroup Single Test"})
      entry1 = note_entry_fixture(folio, user, %{"content" => "Entry 1"})
      entry2 = note_entry_fixture(folio, user, %{"content" => "Entry 2"})
      group_id = Ecto.UUID.generate()
      Library.update_entry_group(entry1, group_id)
      Library.update_entry_group(entry2, group_id)
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, "/library/#{folio.slug}/compose")

      # Toggle entry1 out of the group
      view
      |> element("div#composer-entry-list")
      |> render_hook("toggle_entry_group", %{"entry-id" => to_string(entry1.id)})

      entries = Library.list_entries(folio.id)
      e1 = Enum.find(entries, &(&1.id == entry1.id))
      e2 = Enum.find(entries, &(&1.id == entry2.id))
      assert e1.group_id == nil
      assert e2.group_id == group_id
    end

    test "ungroup_all clears group_id on all grouped entries", %{conn: conn} do
      user = user_typeface_fixture()
      folio = folio_fixture(user, %{"title" => "Ungroup All Test"})
      entry1 = note_entry_fixture(folio, user, %{"content" => "Entry 1"})
      entry2 = note_entry_fixture(folio, user, %{"content" => "Entry 2"})
      group_id = Ecto.UUID.generate()
      Library.update_entry_group(entry1, group_id)
      Library.update_entry_group(entry2, group_id)
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, "/library/#{folio.slug}/compose")

      view
      |> element("div#composer-entry-list")
      |> render_hook("ungroup_all", %{})

      entries = Library.list_entries(folio.id)
      assert Enum.all?(entries, &(&1.group_id == nil))
    end

    test "unauthorized user cannot toggle entry group", %{conn: conn} do
      author = user_typeface_fixture()
      folio = folio_fixture(author, %{"title" => "Unauthorized Toggle Test"})
      entry = note_entry_fixture(folio, author, %{"content" => "Entry"})
      other_user = user_typeface_fixture()
      conn = log_in_user(conn, other_user)

      {:ok, view, _html} = live(conn, "/library/#{folio.slug}/compose")

      html =
        view
        |> element("div#composer-entry-list")
        |> render_hook("toggle_entry_group", %{"entry-id" => to_string(entry.id)})

      e = Library.list_entries(folio.id) |> Enum.find(&(&1.id == entry.id))
      assert e.group_id == nil
      assert html =~ "Unauthorized"
    end

    test "unauthorized user cannot ungroup_all", %{conn: conn} do
      author = user_typeface_fixture()
      folio = folio_fixture(author, %{"title" => "Unauthorized Ungroup All Test"})
      entry1 = note_entry_fixture(folio, author, %{"content" => "Entry 1"})
      entry2 = note_entry_fixture(folio, author, %{"content" => "Entry 2"})
      group_id = Ecto.UUID.generate()
      Library.update_entry_group(entry1, group_id)
      Library.update_entry_group(entry2, group_id)
      other_user = user_typeface_fixture()
      conn = log_in_user(conn, other_user)

      {:ok, view, _html} = live(conn, "/library/#{folio.slug}/compose")

      html =
        view
        |> element("div#composer-entry-list")
        |> render_hook("ungroup_all", %{})

      entries = Library.list_entries(folio.id)
      assert Enum.all?(entries, &(&1.group_id == group_id))
      assert html =~ "Unauthorized"
    end
  end
end
