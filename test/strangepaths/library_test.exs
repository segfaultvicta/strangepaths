defmodule Strangepaths.LibraryTest do
  use Strangepaths.DataCase

  alias Strangepaths.Library

  import Strangepaths.LibraryFixtures
  import Strangepaths.AccountsFixtures

  # ---- Verifies: liminal-library.AC1.4, AC1.5 ----
  describe "is_folio_editor?/1" do
    test "returns false for user with no typefaces" do
      user = user_fixture()
      refute Library.is_folio_editor?(user.id)
    end

    test "returns true after assigning a typeface" do
      user = user_typeface_fixture()
      assert Library.is_folio_editor?(user.id)
    end
  end

  # ---- Verifies: liminal-library.AC1.2, AC1.3 ----
  describe "assign_user_typeface/2 and remove_user_typeface/2" do
    test "assigns a valid typeface to a user" do
      user = user_fixture()
      assert {:ok, _} = Library.assign_user_typeface(user.id, "jorule")
      assert Library.is_folio_editor?(user.id)
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
      refute Library.is_folio_editor?(user.id)
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
end
