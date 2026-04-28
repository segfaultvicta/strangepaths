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
      |> element("input[phx-change='set_filter']")
      |> render_change(%{"q" => "nonexistent_xyz_term"})

      # Just verify it doesn't crash and recomputes
      html = render(view)
      assert html =~ "Scene Browser"
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
    test "selecting and grouping entries assigns same group_id to both", %{conn: conn} do
      user = user_typeface_fixture()
      folio = folio_fixture(user, %{"title" => "Group Test"})
      entry1 = note_entry_fixture(folio, user, %{"content" => "Entry 1"})
      entry2 = note_entry_fixture(folio, user, %{"content" => "Entry 2"})
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, "/library/#{folio.slug}/compose")

      # Select first entry
      view
      |> element("div#composer-entry-list")
      |> render_hook("toggle_entry_selection", %{"entry-id" => to_string(entry1.id)})

      # Select second entry
      view
      |> element("div#composer-entry-list")
      |> render_hook("toggle_entry_selection", %{"entry-id" => to_string(entry2.id)})

      # Group selected entries
      view
      |> element("div#composer-entry-list")
      |> render_hook("group_selected_entries", %{})

      # Verify both entries have the same non-nil group_id
      entries = Library.list_entries(folio.id)
      assert length(entries) == 2
      entry1_grouped = Enum.find(entries, &(&1.id == entry1.id))
      entry2_grouped = Enum.find(entries, &(&1.id == entry2.id))
      assert entry1_grouped.group_id != nil
      assert entry1_grouped.group_id == entry2_grouped.group_id
    end

    test "grouping with less than 2 entries selected returns error flash", %{conn: conn} do
      user = user_typeface_fixture()
      folio = folio_fixture(user, %{"title" => "Group One Test"})
      _entry = note_entry_fixture(folio, user, %{"content" => "Only Entry"})
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, "/library/#{folio.slug}/compose")

      # Select only one entry
      view
      |> element("div#composer-entry-list")
      |> render_hook("toggle_entry_selection", %{"entry-id" => "1"})

      # Try to group (should fail)
      html = view
      |> element("div#composer-entry-list")
      |> render_hook("group_selected_entries", %{})

      # Verify error message appears
      assert String.contains?(html, ["at least 2", "Select at least 2"]) or
             render(view) =~ "Select at least 2"
    end

    test "unauthorized user cannot group entries", %{conn: conn} do
      author = user_typeface_fixture()
      folio = folio_fixture(author, %{"title" => "Unauthorized Group Test"})
      other_user = user_typeface_fixture()
      entry1 = note_entry_fixture(folio, author, %{"content" => "Entry 1"})
      entry2 = note_entry_fixture(folio, author, %{"content" => "Entry 2"})
      conn = log_in_user(conn, other_user)

      {:ok, view, _html} = live(conn, "/library/#{folio.slug}/compose")

      # Select entries
      view
      |> element("div#composer-entry-list")
      |> render_hook("toggle_entry_selection", %{"entry-id" => to_string(entry1.id)})

      view
      |> element("div#composer-entry-list")
      |> render_hook("toggle_entry_selection", %{"entry-id" => to_string(entry2.id)})

      # Try to group (should fail)
      html = view
      |> element("div#composer-entry-list")
      |> render_hook("group_selected_entries", %{})

      # Verify entries were not grouped
      entries = Library.list_entries(folio.id)
      entry1_result = Enum.find(entries, &(&1.id == entry1.id))
      entry2_result = Enum.find(entries, &(&1.id == entry2.id))
      assert entry1_result.group_id == nil
      assert entry2_result.group_id == nil

      # Verify error message appears
      assert String.contains?(html, "Unauthorized") or render(view) =~ "Unauthorized"
    end

    test "ungrouping selected entries clears group_id on all selected entries", %{conn: conn} do
      user = user_typeface_fixture()
      folio = folio_fixture(user, %{"title" => "Ungroup Test"})
      entry1 = note_entry_fixture(folio, user, %{"content" => "Entry 1"})
      entry2 = note_entry_fixture(folio, user, %{"content" => "Entry 2"})
      conn = log_in_user(conn, user)

      # First, group the entries via direct API call
      group_id = Ecto.UUID.generate()
      Library.update_entry_group(entry1, group_id)
      Library.update_entry_group(entry2, group_id)

      # Verify they are grouped
      entries = Library.list_entries(folio.id)
      entry1_grouped = Enum.find(entries, &(&1.id == entry1.id))
      entry2_grouped = Enum.find(entries, &(&1.id == entry2.id))
      assert entry1_grouped.group_id == group_id
      assert entry2_grouped.group_id == group_id

      # Mount composer
      {:ok, view, _html} = live(conn, "/library/#{folio.slug}/compose")

      # Select both entries
      view
      |> element("div#composer-entry-list")
      |> render_hook("toggle_entry_selection", %{"entry-id" => to_string(entry1.id)})

      view
      |> element("div#composer-entry-list")
      |> render_hook("toggle_entry_selection", %{"entry-id" => to_string(entry2.id)})

      # Ungroup them
      view
      |> element("div#composer-entry-list")
      |> render_hook("ungroup_selected_entries", %{})

      # Verify both entries now have group_id == nil
      entries = Library.list_entries(folio.id)
      entry1_ungrouped = Enum.find(entries, &(&1.id == entry1.id))
      entry2_ungrouped = Enum.find(entries, &(&1.id == entry2.id))
      assert entry1_ungrouped.group_id == nil
      assert entry2_ungrouped.group_id == nil

      # Verify selection is cleared
      html = render(view)
      refute html =~ "selected"
    end

    test "unauthorized user cannot ungroup entries", %{conn: conn} do
      author = user_typeface_fixture()
      folio = folio_fixture(author, %{"title" => "Unauthorized Ungroup Test"})
      other_user = user_typeface_fixture()
      entry1 = note_entry_fixture(folio, author, %{"content" => "Entry 1"})
      entry2 = note_entry_fixture(folio, author, %{"content" => "Entry 2"})

      # Group the entries
      group_id = Ecto.UUID.generate()
      Library.update_entry_group(entry1, group_id)
      Library.update_entry_group(entry2, group_id)

      conn = log_in_user(conn, other_user)
      {:ok, view, _html} = live(conn, "/library/#{folio.slug}/compose")

      # Select entries
      view
      |> element("div#composer-entry-list")
      |> render_hook("toggle_entry_selection", %{"entry-id" => to_string(entry1.id)})

      view
      |> element("div#composer-entry-list")
      |> render_hook("toggle_entry_selection", %{"entry-id" => to_string(entry2.id)})

      # Try to ungroup (should fail)
      html = view
      |> element("div#composer-entry-list")
      |> render_hook("ungroup_selected_entries", %{})

      # Verify entries are still grouped
      entries = Library.list_entries(folio.id)
      entry1_result = Enum.find(entries, &(&1.id == entry1.id))
      entry2_result = Enum.find(entries, &(&1.id == entry2.id))
      assert entry1_result.group_id == group_id
      assert entry2_result.group_id == group_id

      # Verify error message appears
      assert String.contains?(html, "Unauthorized") or render(view) =~ "Unauthorized"
    end
  end
end
