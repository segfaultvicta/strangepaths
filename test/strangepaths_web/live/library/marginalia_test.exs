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
    test "folio editor can post marginalia on any folio", %{conn: conn} do
      author = user_typeface_fixture()
      other_editor = user_typeface_fixture()
      folio = folio_fixture(author, %{"title" => "Any Editor Marginalia"})
      entry = note_entry_fixture(folio, author)

      conn = log_in_user(conn, other_editor)
      {:ok, view, _html} = live(conn, "/library/any-editor-marginalia")

      # Expand entry thread
      view
      |> element("button[phx-click='toggle_marginalia_thread'][phx-value-entry-id='#{entry.id}']")
      |> render_click()

      # Open form
      view
      |> element("button[phx-click='open_marginalia_form'][phx-value-entry-id='#{entry.id}']")
      |> render_click()

      # Submit
      view
      |> form("form[phx-submit='submit_marginalia']",
        marginalia: %{content: "A new annotation"}
      )
      |> render_submit()

      entries = Library.list_all_marginalia_for_folio(folio.id)
      assert length(entries) == 1
      assert hd(entries).content == "A new annotation"
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
end
