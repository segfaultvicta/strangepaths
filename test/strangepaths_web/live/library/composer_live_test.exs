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
end
