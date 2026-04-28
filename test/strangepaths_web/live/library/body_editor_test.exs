defmodule StrangepathsWeb.LibraryLive.BodyEditorTest do
  use StrangepathsWeb.ConnCase

  import Phoenix.LiveViewTest
  import Strangepaths.AccountsFixtures
  import Strangepaths.LibraryFixtures

  alias Strangepaths.Library

  # Verifies: liminal-library.AC3.1
  describe "body editor access" do
    test "folio editor can open body editor", %{conn: conn} do
      user = user_typeface_fixture()
      _folio = folio_fixture(user, %{"title" => "Editable Body Folio"})
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, "/library/editable-body-folio")

      html = view |> element("button[phx-click='claim_body_lock']") |> render_click()
      assert html =~ "Save Body"
      assert html =~ "Cancel"
    end

    test "non-folio-editor does not see edit body button", %{conn: conn} do
      author = user_typeface_fixture()
      _folio = folio_fixture(author, %{"title" => "Non Editor Body"})
      other_user = user_fixture()
      conn = log_in_user(conn, other_user)

      {:ok, _view, html} = live(conn, "/library/non-editor-body")
      refute html =~ "Edit body"
      refute html =~ "Add body"
    end
  end

  # Verifies: liminal-library.AC3.2
  describe "mutex — locked state" do
    test "second editor sees locked flash when first holds the mutex", %{conn: conn} do
      user1 = user_typeface_fixture()
      user2 = user_typeface_fixture()
      folio = folio_fixture(user1, %{"title" => "Mutex Test Folio"})

      # User 1 claims the lock directly via context
      Library.claim_body_lock(folio.id, user1.id)

      # User 2 tries to open the editor
      conn2 = log_in_user(conn, user2)
      {:ok, view, _html} = live(conn2, "/library/mutex-test-folio")

      html = view |> element("button[phx-click='claim_body_lock']") |> render_click()

      assert html =~ "Another editor"
    end
  end

  # Verifies: liminal-library.AC3.3
  describe "mutex release" do
    test "save_body releases the lock" do
      user = user_typeface_fixture()
      folio = folio_fixture(user, %{"title" => "Save Release Test"})

      Library.claim_body_lock(folio.id, user.id)
      Library.save_body(folio, user.id, "Saved content")

      info = Library.get_folio_lock_info(folio.id)
      assert is_nil(info.locked_by_id)
    end

    test "release_body_lock releases on cancel" do
      user = user_typeface_fixture()
      folio = folio_fixture(user)

      Library.claim_body_lock(folio.id, user.id)
      Library.release_body_lock(folio.id)

      info = Library.get_folio_lock_info(folio.id)
      assert is_nil(info.locked_by_id)
    end
  end

  # Verifies: liminal-library.AC3.7
  describe "live preview" do
    test "update_preview event updates preview html", %{conn: conn} do
      user = user_typeface_fixture()
      _folio = folio_fixture(user, %{"title" => "Preview Test Folio"})

      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, "/library/preview-test-folio")

      # Open editor
      view |> element("button[phx-click='claim_body_lock']") |> render_click()

      # Trigger preview update
      html =
        view
        |> element("form")
        |> render_change(%{folio: %{body: "**preview content**"}})

      assert html =~ "<strong>preview content</strong>"
    end
  end
end
