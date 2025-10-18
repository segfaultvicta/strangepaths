defmodule StrangepathsWeb.SongController do
  use StrangepathsWeb, :controller

  alias Strangepaths.Site
  alias Strangepaths.Site.Song

  def index(conn, _params) do
    render(conn, "index.html", songs: %{disc1: Site.disc1(), disc2: Site.disc2()})
  end

  def new(conn, _params) do
    changeset = Site.change_song(%Song{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"song" => song_params}) do
    case Site.create_song(song_params) do
      {:ok, song} ->
        conn
        |> put_flash(:info, "Song created successfully.")
        |> redirect(to: Routes.song_path(conn, :show, song))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    song = Site.get_song!(id)
    render(conn, "show.html", song: song)
  end

  def edit(conn, %{"id" => id}) do
    song = Site.get_song!(id)
    changeset = Site.change_song(song)
    render(conn, "edit.html", song: song, changeset: changeset)
  end

  def update(conn, %{"id" => id, "song" => song_params}) do
    song = Site.get_song!(id)

    case Site.update_song(song, song_params) do
      {:ok, song} ->
        conn
        |> put_flash(:info, "Song updated successfully.")
        |> redirect(to: Routes.song_path(conn, :show, song))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html", song: song, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    song = Site.get_song!(id)
    {:ok, _song} = Site.delete_song(song)

    conn
    |> put_flash(:info, "Song deleted successfully.")
    |> redirect(to: Routes.song_path(conn, :index))
  end
end
