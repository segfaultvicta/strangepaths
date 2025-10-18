defmodule Strangepaths.SiteTest do
  use Strangepaths.DataCase

  alias Strangepaths.Site

  describe "songs" do
    alias Strangepaths.Site.Song

    import Strangepaths.SiteFixtures

    @invalid_attrs %{link: nil, title: nil, text: nil, unlocked: nil}

    test "list_songs/0 returns all songs" do
      song = song_fixture()
      assert Site.list_songs() == [song]
    end

    test "get_song!/1 returns the song with given id" do
      song = song_fixture()
      assert Site.get_song!(song.id) == song
    end

    test "create_song/1 with valid data creates a song" do
      valid_attrs = %{link: "some link", title: "some title", text: "some text", unlocked: true}

      assert {:ok, %Song{} = song} = Site.create_song(valid_attrs)
      assert song.link == "some link"
      assert song.title == "some title"
      assert song.text == "some text"
      assert song.unlocked == true
    end

    test "create_song/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Site.create_song(@invalid_attrs)
    end

    test "update_song/2 with valid data updates the song" do
      song = song_fixture()
      update_attrs = %{link: "some updated link", title: "some updated title", text: "some updated text", unlocked: false}

      assert {:ok, %Song{} = song} = Site.update_song(song, update_attrs)
      assert song.link == "some updated link"
      assert song.title == "some updated title"
      assert song.text == "some updated text"
      assert song.unlocked == false
    end

    test "update_song/2 with invalid data returns error changeset" do
      song = song_fixture()
      assert {:error, %Ecto.Changeset{}} = Site.update_song(song, @invalid_attrs)
      assert song == Site.get_song!(song.id)
    end

    test "delete_song/1 deletes the song" do
      song = song_fixture()
      assert {:ok, %Song{}} = Site.delete_song(song)
      assert_raise Ecto.NoResultsError, fn -> Site.get_song!(song.id) end
    end

    test "change_song/1 returns a song changeset" do
      song = song_fixture()
      assert %Ecto.Changeset{} = Site.change_song(song)
    end
  end
end
