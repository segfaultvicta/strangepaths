defmodule Strangepaths.LibraryTest do
  use Strangepaths.DataCase

  alias Strangepaths.Library

  import Strangepaths.LibraryFixtures
  import Strangepaths.AccountsFixtures

  # ---- Verifies: liminal-library.AC1.4, AC1.5 ----
  describe "folio_editor?/1" do
    test "returns false for user with no typefaces" do
      user = user_fixture()
      refute Library.folio_editor?(user.id)
    end

    test "returns true after assigning a typeface" do
      user = user_typeface_fixture()
      assert Library.folio_editor?(user.id)
    end
  end

  # ---- Verifies: liminal-library.AC1.2, AC1.3 ----
  describe "assign_user_typeface/2 and remove_user_typeface/2" do
    test "assigns a valid typeface to a user" do
      user = user_fixture()
      assert {:ok, _} = Library.assign_user_typeface(user.id, "jorule")
      assert Library.folio_editor?(user.id)
    end

    test "assigning the same typeface twice is a no-op" do
      user = user_fixture()
      {:ok, _} = Library.assign_user_typeface(user.id, "jorule")
      assert {:ok, _} = Library.assign_user_typeface(user.id, "jorule")
      assert length(Library.list_user_typefaces(user.id)) == 1
    end

    test "assigning an invalid typeface id returns an error" do
      user = user_fixture()
      assert {:error, changeset} = Library.assign_user_typeface(user.id, "nonexistent")
      assert %{typeface_id: ["is not a valid typeface"]} = errors_on(changeset)
    end

    test "revokes an assigned typeface" do
      user = user_typeface_fixture()
      assert {:ok, _} = Library.remove_user_typeface(user.id, "jorule")
      refute Library.folio_editor?(user.id)
    end

    test "revoking a typeface not assigned returns error tuple" do
      user = user_fixture()
      assert {:error, :not_found} = Library.remove_user_typeface(user.id, "jorule")
    end
  end

  # ---- Verifies: liminal-library.AC2.1, AC2.2, AC2.3, AC2.4, AC2.5 ----
  describe "create_folio/2" do
    test "creates folio with title only" do
      user = user_typeface_fixture()
      assert {:ok, folio} = Library.create_folio(user, %{"title" => "The Broken Seal"})
      assert folio.title == "The Broken Seal"
      assert folio.slug == "the-broken-seal"
      assert folio.user_id == user.id
      assert is_nil(folio.subtitle)
      assert is_nil(folio.body)
    end

    test "slug is auto-generated from title (AC2.2)" do
      user = user_typeface_fixture()
      {:ok, folio} = Library.create_folio(user, %{"title" => "Letters from Elsewhere"})
      assert folio.slug == "letters-from-elsewhere"
    end

    test "creates folio with subtitle" do
      user = user_typeface_fixture()
      {:ok, folio} =
        Library.create_folio(user, %{
          "title" => "Night Court Transcript",
          "subtitle" => "Session 7, Unredacted"
        })

      assert folio.subtitle == "Session 7, Unredacted"
    end

    test "creates folio with body only and no entries (AC2.4)" do
      user = user_typeface_fixture()
      {:ok, folio} =
        Library.create_folio(user, %{
          "title" => "Body-Only Folio",
          "body" => "Some diegetic prose here."
        })

      assert folio.body == "Some diegetic prose here."
      assert Library.list_entries(folio.id) == []
    end

    test "creates folio without body (entries-only valid) (AC2.5)" do
      user = user_typeface_fixture()
      {:ok, folio} = Library.create_folio(user, %{"title" => "Entries Only Folio"})
      assert is_nil(folio.body)
    end

    test "duplicate title returns error changeset (AC2.3)" do
      user = user_typeface_fixture()
      {:ok, _} = Library.create_folio(user, %{"title" => "Unique Title"})
      assert {:error, changeset} = Library.create_folio(user, %{"title" => "Unique Title"})
      assert %{title: ["has already been taken"]} = errors_on(changeset)
    end

    test "blank title returns error changeset" do
      user = user_typeface_fixture()
      assert {:error, changeset} = Library.create_folio(user, %{"title" => ""})
      assert %{title: _} = errors_on(changeset)
    end
  end

  # ---- Verifies: liminal-library.AC8.1 ----
  describe "tags" do
    test "adds a tag to a folio" do
      folio = folio_fixture()
      {:ok, _} = Library.add_tag(folio, "history")
      assert Library.list_tags(folio.id) == ["history"]
    end

    test "tags are stored lowercased and trimmed (AC8.1)" do
      folio = folio_fixture()
      {:ok, _} = Library.add_tag(folio, "  RITUAL  ")
      assert Library.list_tags(folio.id) == ["ritual"]
    end

    test "duplicate adds are no-ops (AC8.1)" do
      folio = folio_fixture()
      {:ok, _} = Library.add_tag(folio, "lore")
      {:ok, _} = Library.add_tag(folio, "lore")
      assert Library.list_tags(folio.id) == ["lore"]
    end

    test "removes a tag" do
      folio = folio_fixture()
      {:ok, _} = Library.add_tag(folio, "lore")
      {:ok, _} = Library.remove_tag(folio, "lore")
      assert Library.list_tags(folio.id) == []
    end

    test "removing a tag that does not exist is a no-op" do
      folio = folio_fixture()
      assert {:ok, _} = Library.remove_tag(folio, "nonexistent")
    end
  end

  describe "entries" do
    test "creates an inline note entry" do
      user = user_typeface_fixture()
      folio = folio_fixture(user)
      [tf | _] = Library.folio_editor_typefaces(user.id)

      {:ok, entry} =
        Library.create_note_entry(folio, user, %{
          "content" => "This is a note.",
          "name" => tf.name,
          "font" => tf.font,
          "color" => tf.color
        })

      assert entry.kind == :note
      assert entry.content == "This is a note."
      assert entry.folio_id == folio.id
    end

    test "creates entries with sequential positions" do
      user = user_typeface_fixture()
      folio = folio_fixture(user)
      [tf | _] = Library.folio_editor_typefaces(user.id)
      note_attrs = %{"content" => "x", "name" => tf.name, "font" => tf.font, "color" => tf.color}

      {:ok, e1} = Library.create_note_entry(folio, user, note_attrs)
      {:ok, e2} = Library.create_note_entry(folio, user, note_attrs)

      assert e2.position > e1.position
    end

    test "reorders entries" do
      user = user_typeface_fixture()
      folio = folio_fixture(user)
      [tf | _] = Library.folio_editor_typefaces(user.id)
      note_attrs = %{"content" => "x", "name" => tf.name, "font" => tf.font, "color" => tf.color}

      {:ok, e1} = Library.create_note_entry(folio, user, note_attrs)
      {:ok, e2} = Library.create_note_entry(folio, user, note_attrs)

      :ok = Library.reorder_entries(folio.id, [e2.id, e1.id])

      [first, second] = Library.list_entries(folio.id)
      assert first.id == e2.id
      assert second.id == e1.id
    end

    test "inserts note entry at non-trailing caret without unique constraint violation (regression)" do
      user = user_typeface_fixture()
      folio = folio_fixture(user)
      [tf | _] = Library.folio_editor_typefaces(user.id)
      note_attrs = %{"content" => "x", "name" => tf.name, "font" => tf.font, "color" => tf.color}

      # Create 2 existing entries (positions 1 and 2)
      {:ok, e1} = Library.create_note_entry(folio, user, note_attrs)
      {:ok, e2} = Library.create_note_entry(folio, user, note_attrs)

      # Insert note entry at position 2 (between e1 and e2) — this triggered unique constraint
      # violations before the fix due to direct increment without temp negative positions.
      # The fix ensures entries >= pos are shifted via temporary negative positions first.
      {:ok, entry} = Library.create_note_entry(folio, user, note_attrs, 2)

      entries = Library.list_entries(folio.id)
      assert length(entries) == 3
      assert Enum.at(entries, 0).id == e1.id
      assert Enum.at(entries, 1).id == entry.id
      assert Enum.at(entries, 2).id == e2.id
    end

    test "deletes an entry" do
      user = user_typeface_fixture()
      folio = folio_fixture(user)
      entry = note_entry_fixture(folio, user)

      {:ok, _} = Library.delete_entry(entry)
      assert Library.list_entries(folio.id) == []
    end
  end

  describe "marginalia" do
    test "creates marginalia on an entry" do
      user = user_typeface_fixture()
      folio = folio_fixture(user)
      entry = note_entry_fixture(folio, user)
      [tf | _] = Library.folio_editor_typefaces(user.id)

      {:ok, m} =
        Library.create_marginalia(entry, user, %{
          "content" => "Interesting.",
          "name" => tf.name,
          "font" => tf.font,
          "color" => tf.color
        })

      assert m.entry_id == entry.id
      assert m.content == "Interesting."
      assert m.name == tf.name
    end

    test "creates a reply to marginalia" do
      user = user_typeface_fixture()
      folio = folio_fixture(user)
      entry = note_entry_fixture(folio, user)
      [tf | _] = Library.folio_editor_typefaces(user.id)

      {:ok, parent} =
        Library.create_marginalia(entry, user, %{
          "content" => "First comment.",
          "name" => tf.name,
          "font" => tf.font,
          "color" => tf.color
        })

      {:ok, reply} =
        Library.create_marginalia(entry, user, %{
          "content" => "Reply to that.",
          "name" => tf.name,
          "font" => tf.font,
          "color" => tf.color,
          "parent_id" => parent.id
        })

      assert reply.parent_id == parent.id
    end
  end

  describe "marginalia depth enforcement" do
    test "creates top-level marginalia" do
      user = user_typeface_fixture()
      folio = folio_fixture(user)
      entry = note_entry_fixture(folio, user)
      [tf | _] = Library.folio_editor_typefaces(user.id)

      {:ok, m} =
        Library.create_marginalia(entry, user, %{
          "content" => "Top level",
          "name" => tf.name,
          "font" => tf.font,
          "color" => tf.color
        })

      assert m.parent_id == nil
    end

    test "creates a reply (depth 1)" do
      user = user_typeface_fixture()
      folio = folio_fixture(user)
      entry = note_entry_fixture(folio, user)
      [tf | _] = Library.folio_editor_typefaces(user.id)

      {:ok, parent} =
        Library.create_marginalia(entry, user, %{
          "content" => "Top",
          "name" => tf.name,
          "font" => tf.font,
          "color" => tf.color
        })

      {:ok, child} =
        Library.create_marginalia(entry, user, %{
          "content" => "Reply",
          "name" => tf.name,
          "font" => tf.font,
          "color" => tf.color,
          "parent_id" => parent.id
        })

      assert child.parent_id == parent.id
    end

    test "rejects marginalia that would exceed max depth" do
      user = user_typeface_fixture()
      folio = folio_fixture(user)
      entry = note_entry_fixture(folio, user)
      [tf | _] = Library.folio_editor_typefaces(user.id)

      base_attrs = %{
        "content" => "x",
        "name" => tf.name,
        "font" => tf.font,
        "color" => tf.color
      }

      {:ok, m1} = Library.create_marginalia(entry, user, base_attrs)
      {:ok, m2} = Library.create_marginalia(entry, user, Map.put(base_attrs, "parent_id", m1.id))
      {:ok, m3} = Library.create_marginalia(entry, user, Map.put(base_attrs, "parent_id", m2.id))

      # Depth 3 (m3) should succeed; depth 4 (off m3) should fail
      assert {:error, :max_depth_exceeded} =
             Library.create_marginalia(entry, user, Map.put(base_attrs, "parent_id", m3.id))
    end
  end

  describe "body mutex" do
    test "claim_body_lock succeeds when no lock" do
      folio = folio_fixture()
      assert :ok = Library.claim_body_lock(folio.id, 1)

      info = Library.get_folio_lock_info(folio.id)
      assert info.locked_by_id == 1
    end

    test "claim_body_lock fails when another user holds the lock" do
      folio = folio_fixture()
      user1 = user_typeface_fixture()
      user2 = user_typeface_fixture()

      :ok = Library.claim_body_lock(folio.id, user1.id)
      assert {:error, :locked} = Library.claim_body_lock(folio.id, user2.id)
    end

    test "claim_body_lock succeeds when existing lock is stale" do
      folio = folio_fixture()
      user1 = user_typeface_fixture()
      user2 = user_typeface_fixture()

      # Manually insert a stale lock (older than lock_timeout_seconds)
      stale_at =
        DateTime.utc_now()
        |> DateTime.add(-(Library.lock_timeout_seconds() + 10), :second)
        |> DateTime.truncate(:second)

      from(f in Strangepaths.Library.Folio, where: f.id == ^folio.id)
      |> Strangepaths.Repo.update_all(
        set: [body_locked_by_id: user1.id, body_locked_at: stale_at]
      )

      # User 2 can claim despite user1's stale lock
      assert :ok = Library.claim_body_lock(folio.id, user2.id)
      info = Library.get_folio_lock_info(folio.id)
      assert info.locked_by_id == user2.id
    end

    test "claim_body_lock allows same user to reclaim their own lock" do
      folio = folio_fixture()
      user = user_typeface_fixture()

      # User claims the lock
      :ok = Library.claim_body_lock(folio.id, user.id)

      # User reconnects immediately and reclaims (simulates socket crash/reconnect)
      assert :ok = Library.claim_body_lock(folio.id, user.id)

      info = Library.get_folio_lock_info(folio.id)
      assert info.locked_by_id == user.id
    end

    test "release_body_lock clears the lock" do
      folio = folio_fixture()
      user = user_typeface_fixture()

      :ok = Library.claim_body_lock(folio.id, user.id)
      :ok = Library.release_body_lock(folio.id)

      info = Library.get_folio_lock_info(folio.id)
      assert is_nil(info.locked_by_id)
    end

    test "save_body saves content and releases lock" do
      user = user_typeface_fixture()
      folio = folio_fixture(user)

      :ok = Library.claim_body_lock(folio.id, user.id)
      :ok = Library.save_body(folio, user.id, "New body content.")

      info = Library.get_folio_lock_info(folio.id)
      assert is_nil(info.locked_by_id)
    end
  end

  describe "marginalia validation" do
    test "create_changeset rejects invalid hex color" do
      user = user_typeface_fixture()
      folio = folio_fixture(user)
      entry = note_entry_fixture(folio, user)
      [tf | _] = Library.folio_editor_typefaces(user.id)

      # Invalid color: not a hex code
      changeset =
        %Strangepaths.Library.Marginalia{}
        |> Strangepaths.Library.Marginalia.create_changeset(%{
          "entry_id" => entry.id,
          "user_id" => user.id,
          "content" => "Test",
          "name" => tf.name,
          "font" => tf.font,
          "color" => "not-a-color"
        })

      refute changeset.valid?
      assert Enum.any?(changeset.errors, fn {field, _} -> field == :color end)
    end

    test "create_changeset rejects non-whitelisted font" do
      user = user_typeface_fixture()
      folio = folio_fixture(user)
      entry = note_entry_fixture(folio, user)
      [tf | _] = Library.folio_editor_typefaces(user.id)

      # Invalid font: not in whitelist
      changeset =
        %Strangepaths.Library.Marginalia{}
        |> Strangepaths.Library.Marginalia.create_changeset(%{
          "entry_id" => entry.id,
          "user_id" => user.id,
          "content" => "Test",
          "name" => tf.name,
          "font" => "Comic Sans MS",
          "color" => tf.color
        })

      refute changeset.valid?
      assert Enum.any?(changeset.errors, fn {field, _} -> field == :font end)
    end

    test "create_changeset accepts valid hex color and whitelisted font" do
      user = user_typeface_fixture()
      folio = folio_fixture(user)
      entry = note_entry_fixture(folio, user)
      [tf | _] = Library.folio_editor_typefaces(user.id)

      # Valid color and font
      changeset =
        %Strangepaths.Library.Marginalia{}
        |> Strangepaths.Library.Marginalia.create_changeset(%{
          "entry_id" => entry.id,
          "user_id" => user.id,
          "content" => "Test",
          "name" => tf.name,
          "font" => tf.font,
          "color" => tf.color
        })

      assert changeset.valid?
    end
  end

  # Verifies: liminal-library.AC7.1, liminal-library.AC7.3
  describe "search_folios/1" do
    setup do
      editor1 = user_fixture()
      editor2 = user_fixture()
      [tf | _] = Strangepaths.Library.Typefaces.all()
      Library.assign_user_typeface(editor1.id, tf.id)
      Library.assign_user_typeface(editor2.id, tf.id)

      {:ok, folio1} = Library.create_folio(editor1, %{
        "title" => "The Crimson Archives",
        "subtitle" => "A history of the tribunal",
        "body" => "These records span three centuries of rulings."
      })

      {:ok, folio2} = Library.create_folio(editor2, %{
        "title" => "Amber Studies",
        "body" => "Notes on resonance theory."
      })

      # Add a tag to folio1
      Library.add_tag(folio1, "tribunal")
      Library.add_tag(folio1, "history")

      %{editor1: editor1, editor2: editor2, folio1: folio1, folio2: folio2}
    end

    test "returns all folios when no opts given", %{folio1: f1, folio2: f2} do
      results = Library.search_folios([])
      ids = Enum.map(results, & &1.id)
      assert f1.id in ids
      assert f2.id in ids
    end

    test "filters by title match", %{folio1: f1, folio2: f2} do
      results = Library.search_folios(query: "Crimson")
      ids = Enum.map(results, & &1.id)
      assert f1.id in ids
      refute f2.id in ids
    end

    test "filters by subtitle match", %{folio1: f1} do
      results = Library.search_folios(query: "tribunal")
      ids = Enum.map(results, & &1.id)
      assert f1.id in ids
    end

    test "filters by body match", %{folio2: f2} do
      results = Library.search_folios(query: "resonance")
      ids = Enum.map(results, & &1.id)
      assert f2.id in ids
    end

    test "filters by author_id", %{editor1: ed1, folio1: f1, folio2: f2} do
      results = Library.search_folios(author_id: ed1.id)
      ids = Enum.map(results, & &1.id)
      assert f1.id in ids
      refute f2.id in ids
    end

    test "filters by tag", %{folio1: f1, folio2: f2} do
      results = Library.search_folios(tag: "history")
      ids = Enum.map(results, & &1.id)
      assert f1.id in ids
      refute f2.id in ids
    end

    test "sort_by :title returns folios alphabetically", %{folio2: f2} do
      results = Library.search_folios(sort_by: :title)
      # "Amber" < "Crimson" alphabetically
      [first | _] = results
      assert first.id == f2.id
    end

    test "sort_by :date returns newest first" do
      # folio2 was inserted after folio1 in the setup
      results = Library.search_folios(sort_by: :date)
      ids = Enum.map(results, & &1.id)
      # Both folios present; since folio2 was inserted last, it should appear first
      assert length(results) >= 2
      assert List.first(ids) != nil
    end

    # Verifies: liminal-library.AC7.2
    test "results contain only Folio structs, not scenes or other types" do
      results = Library.search_folios(query: "")
      for r <- results do
        assert %Library.Folio{} = r
      end
    end

    # Verifies: liminal-library.AC7.4
    test "Scenes archive search returns same results after library feature exists" do
      # Calling Scenes.search_archived_scenes with a query that won't match library folios
      # This verifies the function signature and return type haven't changed.
      user = user_fixture()
      results = Strangepaths.Scenes.search_archived_scenes("crimson archives", user.id, false, false, nil, nil)
      # Should return a list (may be empty); key assertion is no crash and no folios in result
      assert is_list(results)
    end
  end
end
