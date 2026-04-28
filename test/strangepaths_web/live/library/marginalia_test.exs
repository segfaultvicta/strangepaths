defmodule StrangepathsWeb.LibraryLive.MarginaliaTest do
  use StrangepathsWeb.ConnCase

  import Phoenix.LiveViewTest
  import Strangepaths.AccountsFixtures
  import Strangepaths.LibraryFixtures

  alias Strangepaths.Library

  # Verifies: liminal-library.AC6.4 (collapsed by default)
  describe "marginalia collapse state" do
    test "marginalia threads are collapsed by default", %{conn: conn} do
      user = user_typeface_fixture()
      folio = folio_fixture(user, %{"title" => "Marginalia Collapse Test"})
      entry = note_entry_fixture(folio, user)
      m = marginalia_fixture(entry, user)

      conn2 = log_in_user(conn, user)
      {:ok, _view, html} = live(conn2, "/library/marginalia-collapse-test")

      # Count badge visible but content not rendered
      assert html =~ "1 marginalia"
      refute html =~ m.content
    end

    test "expanding a thread shows marginalia content (AC6.5)", %{conn: conn} do
      user = user_typeface_fixture()
      folio = folio_fixture(user, %{"title" => "Marginalia Expand Test"})
      entry = note_entry_fixture(folio, user)
      _m = marginalia_fixture(entry, user, %{"content" => "Unique marginalia content xyz"})

      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, "/library/marginalia-expand-test")

      html =
        view
        |> element("button[phx-click='toggle_marginalia_thread'][phx-value-entry-id='#{entry.id}']")
        |> render_click()

      assert html =~ "Unique marginalia content xyz"
    end
  end

  # Verifies: liminal-library.AC6.1 (any folio editor can add)
  describe "adding marginalia" do
    test "folio editor can post marginalia via context function", %{conn: conn} do
      author = user_typeface_fixture()
      other_editor = user_typeface_fixture()
      folio = folio_fixture(author, %{"title" => "Any Editor Marginalia"})
      entry = note_entry_fixture(folio, author)
      [tf | _] = Library.folio_editor_typefaces(other_editor.id)

      # Create marginalia as an editor
      {:ok, m} =
        Library.create_marginalia(entry, other_editor, %{
          "content" => "A new annotation",
          "name" => tf.name,
          "font" => tf.font,
          "color" => tf.color
        })

      entries = Library.list_all_marginalia_for_folio(folio.id)
      assert length(entries) == 1
      assert hd(entries).content == "A new annotation"
      assert hd(entries).user_id == other_editor.id
    end

    # Verifies: typeface selection with string IDs (AC6.2 regression test)
    test "folio editor can submit marginalia with specific typeface selected (string ID)", %{conn: conn} do
      author = user_typeface_fixture()
      # Create an editor with two typefaces assigned
      other_editor = user_typeface_fixture(user_fixture(), "jorule")
      Library.assign_user_typeface(other_editor.id, "seraph")

      folio = folio_fixture(author, %{"title" => "Typeface Selection Test"})
      entry = note_entry_fixture(folio, author)

      # Get the editor's typefaces (should be string IDs like "jorule", "seraph", etc.)
      typefaces = Library.folio_editor_typefaces(other_editor.id)
      assert length(typefaces) >= 2

      # Take the second typeface for this test
      second_tf = Enum.at(typefaces, 1)
      assert is_binary(second_tf.id), "Typeface ID must be a string"

      conn = log_in_user(conn, other_editor)
      {:ok, view, _html} = live(conn, "/library/typeface-selection-test")

      # Expand the marginalia thread for this entry
      view
      |> element("button[phx-click='toggle_marginalia_thread'][phx-value-entry-id='#{entry.id}']")
      |> render_click()

      # Open the marginalia form
      view
      |> element("button[phx-click='open_marginalia_form'][phx-value-entry-id='#{entry.id}']")
      |> render_click()

      # Submit with the second typeface's ID (a string like "seraph")
      view
      |> form("form[phx-submit='submit_marginalia']", marginalia: %{
        "content" => "Comment with second typeface",
        "typeface_id" => second_tf.id
      })
      |> render_submit()

      # Verify the marginalia was created with the correct typeface
      all_marginalia = Library.list_all_marginalia_for_folio(folio.id)
      assert length(all_marginalia) == 1
      m = hd(all_marginalia)
      assert m.content == "Comment with second typeface"
      assert m.font == second_tf.font
      assert m.color == second_tf.color
    end
  end

  # Verifies: liminal-library.AC6.7 (non-editor cannot add)
  describe "permission enforcement" do
    test "non-folio-editor does not see annotate button", %{conn: conn} do
      author = user_typeface_fixture()
      non_editor = user_fixture()
      folio = folio_fixture(author, %{"title" => "Non Editor View"})
      entry = note_entry_fixture(folio, author)

      conn = log_in_user(conn, non_editor)
      {:ok, view, _html} = live(conn, "/library/non-editor-view")

      html =
        view
        |> element("button[phx-click='toggle_marginalia_thread'][phx-value-entry-id='#{entry.id}']")
        |> render_click()

      refute html =~ "Annotate"
      refute html =~ "open_marginalia_form"
    end

    # AC6.7: Verify server-side rejection when non-editor attempts to create marginalia via LiveView
    test "non-editor is blocked by LiveView guard when submitting marginalia", %{conn: conn} do
      author = user_typeface_fixture()
      non_editor = user_fixture()
      folio = folio_fixture(author, %{"title" => "Non Editor Malicious"})
      entry = note_entry_fixture(folio, author)

      # Log in as non-editor and mount the folio LiveView
      conn = log_in_user(conn, non_editor)
      {:ok, view, _html} = live(conn, "/library/non-editor-malicious")

      # Attempt to submit a marginalia event directly (bypassing the form button check)
      render_hook(view, "submit_marginalia", %{
        "marginalia" => %{
          "content" => "Malicious marginalia",
          "typeface_id" => ""
        }
      })

      # Verify the submission is rejected with "Unauthorized." flash
      assert render(view) =~ "Unauthorized."

      # Verify no marginalia was created in the database
      assert Library.list_all_marginalia_for_folio(folio.id) == []
    end
  end

  # Verifies: liminal-library.AC6.6 (real-time)
  describe "real-time delivery" do
    test "new marginalia appear in real-time for other viewers", %{conn: conn} do
      author = user_typeface_fixture()
      other_editor = user_typeface_fixture()
      folio = folio_fixture(author, %{"title" => "Realtime Test Folio"})
      entry = note_entry_fixture(folio, author)

      # Open viewer session
      viewer_conn = log_in_user(conn, author)
      {:ok, viewer_view, _} = live(viewer_conn, "/library/realtime-test-folio")

      # Expand the entry thread
      viewer_view
      |> element("button[phx-click='toggle_marginalia_thread'][phx-value-entry-id='#{entry.id}']")
      |> render_click()

      # Create marginalia from the context directly (simulating another user)
      [tf | _] = Library.folio_editor_typefaces(other_editor.id)

      {:ok, _} =
        Library.create_marginalia(entry, other_editor, %{
          "content" => "Real-time annotation",
          "name" => tf.name,
          "font" => tf.font,
          "color" => tf.color
        })

      # LiveView should have received the broadcast
      html = render(viewer_view)
      assert html =~ "Real-time annotation"
    end
  end

  # Verifies: liminal-library.AC6.5 (replies indented by depth)
  describe "indentation and nesting" do
    test "replies render with depth-based indentation margins", %{conn: conn} do
      user = user_typeface_fixture()
      folio = folio_fixture(user, %{"title" => "Indentation Test"})
      entry = note_entry_fixture(folio, user)
      [tf | _] = Library.folio_editor_typefaces(user.id)

      # Create a parent marginalia (depth 0)
      {:ok, parent} =
        Library.create_marginalia(entry, user, %{
          "content" => "Parent comment",
          "name" => tf.name,
          "font" => tf.font,
          "color" => tf.color
        })

      # Create a child reply (depth 1)
      {:ok, child} =
        Library.create_marginalia(entry, user, %{
          "content" => "Child reply",
          "name" => tf.name,
          "font" => tf.font,
          "color" => tf.color,
          "parent_id" => parent.id
        })

      # Create a grandchild reply (depth 2)
      {:ok, _grandchild} =
        Library.create_marginalia(entry, user, %{
          "content" => "Grandchild reply",
          "name" => tf.name,
          "font" => tf.font,
          "color" => tf.color,
          "parent_id" => child.id
        })

      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, "/library/indentation-test")

      # Expand the thread
      html =
        view
        |> element("button[phx-click='toggle_marginalia_thread'][phx-value-entry-id='#{entry.id}']")
        |> render_click()

      # Verify parent is rendered at margin-left: 0px
      assert html =~ "margin-left: 0px"
      assert html =~ "Parent comment"

      # Verify child is rendered at margin-left: 16px
      assert html =~ "margin-left: 16px"
      assert html =~ "Child reply"

      # Verify grandchild is rendered at margin-left: 32px
      assert html =~ "margin-left: 32px"
      assert html =~ "Grandchild reply"
    end
  end
end
