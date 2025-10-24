defmodule Strangepaths.Site do
  @moduledoc """
  The Site context.
  """

  import Ecto.Query, warn: false
  alias Strangepaths.Repo

  alias Strangepaths.Site.MusicQueue
  alias Strangepaths.Site.Song

  @doc """
  Returns the list of songs.

  ## Examples

      iex> list_songs()
      [%Song{}, ...]

  """
  def list_songs do
    Repo.all(Song)
  end

  def disc1 do
    Song |> where(disc: 1) |> order_by(:order) |> Repo.all()
  end

  def disc2 do
    Song |> where(disc: 2) |> order_by(:order) |> Repo.all()
  end

  @doc """
  Gets a single song.

  Raises `Ecto.NoResultsError` if the Song does not exist.

  ## Examples

      iex> get_song!(123)
      %Song{}

      iex> get_song!(456)
      ** (Ecto.NoResultsError)

  """
  def get_song!(id), do: Repo.get!(Song, id)
  def get_song(id), do: Repo.get(Song, id)

  @doc """
  Gets a song by its file GUID.

  ## Examples

      iex> get_song_by_guid("abc-123")
      %Song{}

      iex> get_song_by_guid("nonexistent")
      nil

  """
  def get_song_by_guid(guid), do: Repo.get_by(Song, file_guid: guid)

  @doc """
  Creates a song.

  ## Examples

      iex> create_song(%{field: value})
      {:ok, %Song{}}

      iex> create_song(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_song(attrs \\ %{}) do
    # Calculate the next order number for the disc
    attrs_with_order =
      if attrs[:disc] && !attrs[:order] do
        next_order =
          Song
          |> where(disc: ^attrs.disc)
          |> select([s], max(s.order))
          |> Repo.one()
          |> case do
            # First song on this disc
            nil -> 1
            max_order -> max_order + 1
          end

        Map.put(attrs, :order, next_order)
      else
        attrs
      end

    %Song{}
    |> Song.changeset(attrs_with_order)
    |> Repo.insert()
  end

  @doc """
  Updates a song.

  ## Examples

      iex> update_song(song, %{field: new_value})
      {:ok, %Song{}}

      iex> update_song(song, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_song(%Song{} = song, attrs) do
    song
    |> Song.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a song.

  ## Examples

      iex> delete_song(song)
      {:ok, %Song{}}

      iex> delete_song(song)
      {:error, %Ecto.Changeset{}}

  """
  def delete_song(%Song{} = song) do
    Repo.delete(song)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking song changes.

  ## Examples

      iex> change_song(song)
      %Ecto.Changeset{data: %Song{}}

  """
  def change_song(%Song{} = song, attrs \\ %{}) do
    Song.changeset(song, attrs)
  end

  def broadcast_song(song_id, user_nickname) do
    song = get_song!(song_id)

    StrangepathsWeb.Endpoint.broadcast("music:broadcast", "play_song", %{
      song_id: song.id,
      title: song.title,
      link: song.link,
      queued_by: user_nickname
    })
  end

  def queue_song(song_id, user_nickname) do
    MusicQueue.enqueue(song_id, user_nickname)
  end

  def get_music_queue do
    MusicQueue.get_state()
  end

  def skip_current_song do
    MusicQueue.skip()
  end

  def next_song(song_id) do
    MusicQueue.next_song(song_id)
  end

  # Admin functions for song management

  @doc """
  Toggle the unlocked status of a song (admin only).
  """
  def toggle_song_lock(song_id) do
    song = get_song!(song_id)

    if !song.unlocked do
      # Discord shout that a song has been unlocked, and link to its OST page
      msg =
        "You hear — and your Star hears — a song, echoing from the stillness: #{song.title} (Details at: https://strangepaths.com/ost/#{song.id})"

      Nostrum.Api.Message.create(Application.get_env(:strangepaths, :discord_channel), msg)
    end

    update_song(song, %{unlocked: !song.unlocked})
  end

  @doc """
  Update song order within its disc. Reorders siblings accordingly.
  """
  def update_song_order(song_id, new_order) do
    song = get_song!(song_id)
    old_order = song.order
    disc = song.disc

    # Get all songs in the same disc ordered by current order
    songs_in_disc = Song |> where(disc: ^disc) |> order_by(:order) |> Repo.all()

    # If moving down (new_order > old_order), shift songs between old and new down
    # If moving up (new_order < old_order), shift songs between new and old up
    updated_songs =
      cond do
        new_order > old_order ->
          # Moving down: decrement order for songs between old and new
          Enum.map(songs_in_disc, fn s ->
            cond do
              s.id == song_id -> {s, new_order}
              s.order > old_order && s.order <= new_order -> {s, s.order - 1}
              true -> {s, s.order}
            end
          end)

        new_order < old_order ->
          # Moving up: increment order for songs between new and old
          Enum.map(songs_in_disc, fn s ->
            cond do
              s.id == song_id -> {s, new_order}
              s.order >= new_order && s.order < old_order -> {s, s.order + 1}
              true -> {s, s.order}
            end
          end)

        true ->
          # No change in order
          Enum.map(songs_in_disc, fn s -> {s, s.order} end)
      end

    # Update all affected songs
    Enum.each(updated_songs, fn {s, new_ord} ->
      if s.order != new_ord do
        update_song(s, %{order: new_ord})
      end
    end)

    {:ok, get_song!(song_id)}
  end

  @doc """
  Update song metadata (title, text/lyrics).
  """
  def update_song_metadata(song_id, attrs) do
    song = get_song!(song_id)
    update_song(song, attrs)
  end

  def render_lyrics(song_id) do
    song = get_song!(song_id)
    Earmark.as_html!(song.text)
  end

  @doc """
  Uploads an MP3 file for a song, generating a GUID for secure storage.
  Returns {:ok, guid} on success, {:error, reason} on failure.
  """
  def upload_song_file(song_id, upload) do
    song = get_song!(song_id)
    guid = Ecto.UUID.generate()

    music_dir = Path.join([:code.priv_dir(:strangepaths), "static", "music"])
    File.mkdir_p!(music_dir)

    dest_path = Path.join(music_dir, "#{guid}.mp3")

    case File.cp(upload.path, dest_path) do
      :ok ->
        # Update song with new GUID and link
        case update_song(song, %{
               file_guid: guid,
               link: "/music/#{guid}"
             }) do
          {:ok, _song} -> {:ok, guid}
          error -> error
        end

      {:error, reason} ->
        {:error, "Failed to copy file: #{inspect(reason)}"}
    end
  end
end
