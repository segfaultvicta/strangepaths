defmodule StrangepathsWeb.LibraryLive.FolioListTest do
  use StrangepathsWeb.ConnCase

  import Phoenix.LiveViewTest
  import Strangepaths.AccountsFixtures
  import Strangepaths.LibraryFixtures

  alias Strangepaths.Library

  # Verifies: liminal-library.AC2.4, AC2.5 (library index shows folios)
  describe "GET /library" do
    test "shows empty state when no folios exist", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/library")
      assert html =~ "archive awaits"
    end

    test "shows existing folios", %{conn: conn} do
      _folio = folio_fixture(nil, %{"title" => "Test Folio Title"})
      {:ok, _view, html} = live(conn, "/library")
      assert html =~ "Test Folio Title"
    end

    test "shows New Folio button for folio editors", %{conn: conn} do
      user = user_typeface_fixture()
      conn = log_in_user(conn, user)
      {:ok, _view, html} = live(conn, "/library")
      assert html =~ "New Folio"
    end

    test "does not show New Folio button for non-editors", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      {:ok, _view, html} = live(conn, "/library")
      refute html =~ "New Folio"
    end
  end

  # Verifies: liminal-library.AC2.6
  describe "GET /library/new — permission enforcement" do
    test "non-folio-editor is redirected with flash", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      assert {:error, {:live_redirect, %{to: "/library"}}} = live(conn, "/library/new")
    end

    test "unauthenticated user is redirected", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/library"}}} = live(conn, "/library/new")
    end

    test "folio editor can access creation form", %{conn: conn} do
      user = user_typeface_fixture()
      conn = log_in_user(conn, user)

      {:ok, _view, html} = live(conn, "/library/new")
      assert html =~ "New Folio"
      assert html =~ "Title"
    end
  end

  # Verifies: liminal-library.AC2.1, AC2.2
  describe "create_folio event" do
    test "creates folio and redirects to view page", %{conn: conn} do
      user = user_typeface_fixture()
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, "/library/new")

      _html =
        view
        |> form("form[phx-submit='create_folio']", folio: %{title: "The Weight of Names", subtitle: "A Collection"})
        |> render_submit()

      # Should redirect to the folio view
      assert {path, _flash} = assert_redirect(view)
      assert path =~ "/library/the-weight-of-names"

      # Folio exists in DB
      assert Library.get_folio_by_slug("the-weight-of-names")
    end

    # Verifies: liminal-library.AC2.2
    test "slug is auto-generated from title" do
      user = user_typeface_fixture()
      {:ok, folio} = Library.create_folio(user, %{"title" => "Letters From Afar"})
      assert folio.slug == "letters-from-afar"
    end

    # Verifies: liminal-library.AC2.3
    test "duplicate title shows validation error", %{conn: conn} do
      user = user_typeface_fixture()
      folio_fixture(user, %{"title" => "Duplicate Title"})

      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, "/library/new")

      html =
        view
        |> form("form[phx-submit='create_folio']", folio: %{title: "Duplicate Title"})
        |> render_submit()

      assert html =~ "has already been taken"
    end
  end
end
