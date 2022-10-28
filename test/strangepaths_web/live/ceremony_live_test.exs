defmodule StrangepathsWeb.CeremonyLiveTest do
  use StrangepathsWeb.ConnCase

  import Phoenix.LiveViewTest
  import Strangepaths.CardsFixtures

  @create_attrs %{name: "some name"}
  @update_attrs %{name: "some updated name"}
  @invalid_attrs %{name: nil}

  defp create_ceremony(_) do
    ceremony = ceremony_fixture()
    %{ceremony: ceremony}
  end

  describe "Index" do
    setup [:create_ceremony]

    test "lists all ceremonies", %{conn: conn, ceremony: ceremony} do
      {:ok, _index_live, html} = live(conn, Routes.ceremony_index_path(conn, :index))

      assert html =~ "Listing Ceremonies"
      assert html =~ ceremony.name
    end

    test "saves new ceremony", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, Routes.ceremony_index_path(conn, :index))

      assert index_live |> element("a", "New Ceremony") |> render_click() =~
               "New Ceremony"

      assert_patch(index_live, Routes.ceremony_index_path(conn, :new))

      assert index_live
             |> form("#ceremony-form", ceremony: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      {:ok, _, html} =
        index_live
        |> form("#ceremony-form", ceremony: @create_attrs)
        |> render_submit()
        |> follow_redirect(conn, Routes.ceremony_index_path(conn, :index))

      assert html =~ "Ceremony created successfully"
      assert html =~ "some name"
    end

    test "updates ceremony in listing", %{conn: conn, ceremony: ceremony} do
      {:ok, index_live, _html} = live(conn, Routes.ceremony_index_path(conn, :index))

      assert index_live |> element("#ceremony-#{ceremony.id} a", "Edit") |> render_click() =~
               "Edit Ceremony"

      assert_patch(index_live, Routes.ceremony_index_path(conn, :edit, ceremony))

      assert index_live
             |> form("#ceremony-form", ceremony: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      {:ok, _, html} =
        index_live
        |> form("#ceremony-form", ceremony: @update_attrs)
        |> render_submit()
        |> follow_redirect(conn, Routes.ceremony_index_path(conn, :index))

      assert html =~ "Ceremony updated successfully"
      assert html =~ "some updated name"
    end

    test "deletes ceremony in listing", %{conn: conn, ceremony: ceremony} do
      {:ok, index_live, _html} = live(conn, Routes.ceremony_index_path(conn, :index))

      assert index_live |> element("#ceremony-#{ceremony.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#ceremony-#{ceremony.id}")
    end
  end

  describe "Show" do
    setup [:create_ceremony]

    test "displays ceremony", %{conn: conn, ceremony: ceremony} do
      {:ok, _show_live, html} = live(conn, Routes.ceremony_show_path(conn, :show, ceremony))

      assert html =~ "Show Ceremony"
      assert html =~ ceremony.name
    end

    test "updates ceremony within modal", %{conn: conn, ceremony: ceremony} do
      {:ok, show_live, _html} = live(conn, Routes.ceremony_show_path(conn, :show, ceremony))

      assert show_live |> element("a", "Edit") |> render_click() =~
               "Edit Ceremony"

      assert_patch(show_live, Routes.ceremony_show_path(conn, :edit, ceremony))

      assert show_live
             |> form("#ceremony-form", ceremony: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      {:ok, _, html} =
        show_live
        |> form("#ceremony-form", ceremony: @update_attrs)
        |> render_submit()
        |> follow_redirect(conn, Routes.ceremony_show_path(conn, :show, ceremony))

      assert html =~ "Ceremony updated successfully"
      assert html =~ "some updated name"
    end
  end
end
