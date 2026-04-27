defmodule StrangepathsWeb.LibraryLive.AdminTest do
  use StrangepathsWeb.ConnCase

  import Phoenix.LiveViewTest
  import Strangepaths.AccountsFixtures

  alias Strangepaths.Library

  defp dragon_fixture do
    {:ok, user} = Strangepaths.Accounts.register_dragon(valid_user_attributes())
    user
  end

  # Verifies: liminal-library.AC1.1
  describe "GET /library/admin" do
    test "dragon can view the admin page", %{conn: conn} do
      dragon = dragon_fixture()
      conn = log_in_user(conn, dragon)

      {:ok, _view, html} = live(conn, "/library/admin")

      assert html =~ "Library Admin"
      assert html =~ "Typeface Assignments"
    end

    test "non-dragon is redirected", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      assert {:error, {:live_redirect, %{to: "/"}}} = live(conn, "/library/admin")
    end

    test "unauthenticated user is redirected", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/"}}} = live(conn, "/library/admin")
    end
  end

  # Verifies: liminal-library.AC1.2
  describe "assign typeface" do
    test "dragon can assign a typeface to a user", %{conn: conn} do
      dragon = dragon_fixture()
      target_user = user_fixture()
      [tf | _] = Library.Typefaces.all()

      conn = log_in_user(conn, dragon)
      {:ok, view, _html} = live(conn, "/library/admin")

      refute Library.folio_editor?(target_user.id)

      view
      |> element("button[phx-value-user-id='#{target_user.id}'][phx-value-typeface-id='#{tf.id}']")
      |> render_click()

      assert Library.folio_editor?(target_user.id)
    end

    test "dragon can assign typeface to themselves", %{conn: conn} do
      dragon = dragon_fixture()
      [tf | _] = Library.Typefaces.all()

      conn = log_in_user(conn, dragon)
      {:ok, view, _html} = live(conn, "/library/admin")

      view
      |> element("button[phx-value-user-id='#{dragon.id}'][phx-value-typeface-id='#{tf.id}']")
      |> render_click()

      assert Library.folio_editor?(dragon.id)
    end
  end

  # Verifies: liminal-library.AC1.3
  describe "revoke typeface" do
    test "dragon can revoke a typeface from a user", %{conn: conn} do
      dragon = dragon_fixture()
      target_user = user_fixture()
      [tf | _] = Library.Typefaces.all()

      # Pre-assign
      Library.assign_user_typeface(target_user.id, tf.id)
      assert Library.folio_editor?(target_user.id)

      conn = log_in_user(conn, dragon)
      {:ok, view, _html} = live(conn, "/library/admin")

      # Click the same button to toggle off
      view
      |> element("button[phx-value-user-id='#{target_user.id}'][phx-value-typeface-id='#{tf.id}']")
      |> render_click()

      refute Library.folio_editor?(target_user.id)
    end
  end
end
