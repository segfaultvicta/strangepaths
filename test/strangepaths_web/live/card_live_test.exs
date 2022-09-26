defmodule StrangepathsWeb.CardLiveTest do
  use StrangepathsWeb.ConnCase

  import Phoenix.LiveViewTest
  import Strangepaths.CardsFixtures

  @create_attrs %{img: "some img", name: "some name", principle: :Dragon, rules: "some rules", type: :Rite}
  @update_attrs %{img: "some updated img", name: "some updated name", principle: :Stillness, rules: "some updated rules", type: :Grace}
  @invalid_attrs %{img: nil, name: nil, principle: nil, rules: nil, type: nil}

  defp create_card(_) do
    card = card_fixture()
    %{card: card}
  end

  describe "Index" do
    setup [:create_card]

    test "lists all cards", %{conn: conn, card: card} do
      {:ok, _index_live, html} = live(conn, Routes.card_index_path(conn, :index))

      assert html =~ "Listing Cards"
      assert html =~ card.img
    end

    test "saves new card", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, Routes.card_index_path(conn, :index))

      assert index_live |> element("a", "New Card") |> render_click() =~
               "New Card"

      assert_patch(index_live, Routes.card_index_path(conn, :new))

      assert index_live
             |> form("#card-form", card: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      {:ok, _, html} =
        index_live
        |> form("#card-form", card: @create_attrs)
        |> render_submit()
        |> follow_redirect(conn, Routes.card_index_path(conn, :index))

      assert html =~ "Card created successfully"
      assert html =~ "some img"
    end

    test "updates card in listing", %{conn: conn, card: card} do
      {:ok, index_live, _html} = live(conn, Routes.card_index_path(conn, :index))

      assert index_live |> element("#card-#{card.id} a", "Edit") |> render_click() =~
               "Edit Card"

      assert_patch(index_live, Routes.card_index_path(conn, :edit, card))

      assert index_live
             |> form("#card-form", card: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      {:ok, _, html} =
        index_live
        |> form("#card-form", card: @update_attrs)
        |> render_submit()
        |> follow_redirect(conn, Routes.card_index_path(conn, :index))

      assert html =~ "Card updated successfully"
      assert html =~ "some updated img"
    end

    test "deletes card in listing", %{conn: conn, card: card} do
      {:ok, index_live, _html} = live(conn, Routes.card_index_path(conn, :index))

      assert index_live |> element("#card-#{card.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#card-#{card.id}")
    end
  end

  describe "Show" do
    setup [:create_card]

    test "displays card", %{conn: conn, card: card} do
      {:ok, _show_live, html} = live(conn, Routes.card_show_path(conn, :show, card))

      assert html =~ "Show Card"
      assert html =~ card.img
    end

    test "updates card within modal", %{conn: conn, card: card} do
      {:ok, show_live, _html} = live(conn, Routes.card_show_path(conn, :show, card))

      assert show_live |> element("a", "Edit") |> render_click() =~
               "Edit Card"

      assert_patch(show_live, Routes.card_show_path(conn, :edit, card))

      assert show_live
             |> form("#card-form", card: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      {:ok, _, html} =
        show_live
        |> form("#card-form", card: @update_attrs)
        |> render_submit()
        |> follow_redirect(conn, Routes.card_show_path(conn, :show, card))

      assert html =~ "Card updated successfully"
      assert html =~ "some updated img"
    end
  end
end
