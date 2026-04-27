defmodule StrangepathsWeb.LibraryLive.FolioTest do
  use StrangepathsWeb.ConnCase

  import Phoenix.LiveViewTest
  import Strangepaths.AccountsFixtures
  import Strangepaths.LibraryFixtures

  alias Strangepaths.Library

  defp dragon_fixture do
    {:ok, user} = Strangepaths.Accounts.register_dragon(valid_user_attributes())
    user
  end

  # Verifies: AC2.4 (body-only folio viewable), AC2.5 (entries-only viewable)
  describe "GET /library/:slug" do
    test "anyone can view a folio", %{conn: conn} do
      _folio = folio_fixture(nil, %{"title" => "The Grand Archive"})
      {:ok, _view, html} = live(conn, "/library/the-grand-archive")
      assert html =~ "The Grand Archive"
    end

    test "body-only folio renders body content (AC2.4)", %{conn: conn} do
      user = user_typeface_fixture()
      _folio = folio_fixture(user, %{"title" => "Body Only", "body" => "Some prose here."})

      {:ok, _view, html} = live(conn, "/library/body-only")
      assert html =~ "Some prose here."
    end

    test "folio with no body does not crash (AC2.5)", %{conn: conn} do
      _folio = folio_fixture(nil, %{"title" => "No Body Folio"})
      {:ok, _view, html} = live(conn, "/library/no-body-folio")
      assert html =~ "No Body Folio"
    end

    test "redirects with flash on unknown slug", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/library"}}} = live(conn, "/library/nonexistent-slug")
    end
  end

  # Verifies: AC5.2 (author can edit title)
  describe "title editing" do
    test "author sees edit button", %{conn: conn} do
      user = user_typeface_fixture()
      _folio = folio_fixture(user, %{"title" => "Editable Folio"})
      conn = log_in_user(conn, user)

      {:ok, _view, html} = live(conn, "/library/editable-folio")
      assert html =~ "✎"
    end

    test "author can edit title and subtitle", %{conn: conn} do
      user = user_typeface_fixture()
      _folio = folio_fixture(user, %{"title" => "Old Title"})
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, "/library/old-title")

      view |> element("button[phx-click='start_edit_title']") |> render_click()
      _html = view |> form("form", folio: %{title: "New Title", subtitle: "New Subtitle"}) |> render_submit()

      # Should push_patch to new slug URL
      assert_patch(view, "/library/new-title")
    end

    # Verifies: AC5.3 (non-author folio editor cannot edit title)
    test "non-author folio editor does not see edit button", %{conn: conn} do
      author = user_typeface_fixture()
      other_editor = user_typeface_fixture()
      _folio = folio_fixture(author, %{"title" => "Author Folio"})
      conn = log_in_user(conn, other_editor)

      {:ok, _view, html} = live(conn, "/library/author-folio")
      refute html =~ "✎"
    end

    test "dragon can edit any folio title", %{conn: conn} do
      author = user_typeface_fixture()
      _folio = folio_fixture(author, %{"title" => "Dragon Edit Test"})
      dragon = dragon_fixture()
      conn = log_in_user(conn, dragon)

      {:ok, view, html} = live(conn, "/library/dragon-edit-test")
      assert html =~ "✎"

      view |> element("button[phx-click='start_edit_title']") |> render_click()
      view |> form("form", folio: %{title: "Dragon Renamed"}) |> render_submit()

      assert_patch(view, "/library/dragon-renamed")
    end
  end

  # Verifies: AC8.3 (dragon can delete), AC8.4 (non-dragon cannot)
  describe "folio deletion" do
    test "dragon sees delete button", %{conn: conn} do
      _folio = folio_fixture(nil, %{"title" => "Dragon Delete"})
      dragon = dragon_fixture()
      conn = log_in_user(conn, dragon)

      {:ok, _view, html} = live(conn, "/library/dragon-delete")
      assert html =~ "Delete Folio"
    end

    test "non-dragon does not see delete button", %{conn: conn} do
      user = user_typeface_fixture()
      _folio = folio_fixture(user, %{"title" => "Non Dragon Delete"})
      conn = log_in_user(conn, user)

      {:ok, _view, html} = live(conn, "/library/non-dragon-delete")
      refute html =~ "Delete Folio"
    end

    test "dragon can delete a folio", %{conn: conn} do
      _folio = folio_fixture(nil, %{"title" => "To Be Deleted"})
      dragon = dragon_fixture()
      conn = log_in_user(conn, dragon)

      {:ok, view, _html} = live(conn, "/library/to-be-deleted")
      view |> element("button[phx-click='delete_folio']") |> render_click()

      assert_redirect(view, "/library")
      assert Library.get_folio_by_slug("to-be-deleted") == nil
    end
  end
end
