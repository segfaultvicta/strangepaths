defmodule StrangepathsWeb.SongControllerTest do
  use StrangepathsWeb.ConnCase

  import Strangepaths.SiteFixtures

  @create_attrs %{link: "some link", title: "some title", text: "some text", unlocked: true}
  @update_attrs %{link: "some updated link", title: "some updated title", text: "some updated text", unlocked: false}
  @invalid_attrs %{link: nil, title: nil, text: nil, unlocked: nil}

  describe "index" do
    test "lists all songs", %{conn: conn} do
      conn = get(conn, Routes.song_path(conn, :index))
      assert html_response(conn, 200) =~ "Listing Songs"
    end
  end

  describe "new song" do
    test "renders form", %{conn: conn} do
      conn = get(conn, Routes.song_path(conn, :new))
      assert html_response(conn, 200) =~ "New Song"
    end
  end

  describe "create song" do
    test "redirects to show when data is valid", %{conn: conn} do
      conn = post(conn, Routes.song_path(conn, :create), song: @create_attrs)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == Routes.song_path(conn, :show, id)

      conn = get(conn, Routes.song_path(conn, :show, id))
      assert html_response(conn, 200) =~ "Show Song"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.song_path(conn, :create), song: @invalid_attrs)
      assert html_response(conn, 200) =~ "New Song"
    end
  end

  describe "edit song" do
    setup [:create_song]

    test "renders form for editing chosen song", %{conn: conn, song: song} do
      conn = get(conn, Routes.song_path(conn, :edit, song))
      assert html_response(conn, 200) =~ "Edit Song"
    end
  end

  describe "update song" do
    setup [:create_song]

    test "redirects when data is valid", %{conn: conn, song: song} do
      conn = put(conn, Routes.song_path(conn, :update, song), song: @update_attrs)
      assert redirected_to(conn) == Routes.song_path(conn, :show, song)

      conn = get(conn, Routes.song_path(conn, :show, song))
      assert html_response(conn, 200) =~ "some updated link"
    end

    test "renders errors when data is invalid", %{conn: conn, song: song} do
      conn = put(conn, Routes.song_path(conn, :update, song), song: @invalid_attrs)
      assert html_response(conn, 200) =~ "Edit Song"
    end
  end

  describe "delete song" do
    setup [:create_song]

    test "deletes chosen song", %{conn: conn, song: song} do
      conn = delete(conn, Routes.song_path(conn, :delete, song))
      assert redirected_to(conn) == Routes.song_path(conn, :index)

      assert_error_sent 404, fn ->
        get(conn, Routes.song_path(conn, :show, song))
      end
    end
  end

  defp create_song(_) do
    song = song_fixture()
    %{song: song}
  end
end
