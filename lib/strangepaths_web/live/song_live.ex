defmodule StrangepathsWeb.SongLive do
  use StrangepathsWeb, :live_view

  import StrangepathsWeb.MusicBroadcast

  alias Strangepaths.Site

  def mount(%{"id" => id}, session, socket) do
    socket = assign_defaults(session, socket)
    subscribe_to_music(socket)

    song = Site.get_song!(id)
    user = socket.assigns.current_user

    # Check if user can view lyrics (lyrics_unlocked OR admin)
    can_view = song.lyrics_unlocked || user.role == :dragon

    {:ok,
     socket
     |> assign(:song, song)
     |> assign(:can_view, can_view)
     |> assign(:editing_lyrics, false)
     |> assign(:uploaded_files, [])
     |> allow_upload(:mp3_file,
       accept: ~w(.mp3 audio/mpeg),
       max_entries: 1,
       max_file_size: 50_000_000
     )}
  end

  def handle_event(event, params, socket) do
    case forward_music_client_event(event, params, socket) do
      :not_music_event ->
        handle_song_event(event, params, socket)

      result ->
        result
    end
  end

  defp handle_song_event("queue_song", _, socket) do
    # Reuse existing queue logic
    Site.queue_song(socket.assigns.song.id, socket.assigns.current_user.nickname)
    {:noreply, put_flash(socket, :info, "Song queued!")}
  end

  defp handle_song_event("delete_song", _, socket) do
    if socket.assigns.current_user.role == :dragon do
      Site.delete_song(socket.assigns.song)
      {:noreply, put_flash(socket, :info, "Song deleted!") |> push_redirect(to: "/ost")}
    else
      {:noreply, socket}
    end
  end

  # Admin-only: Edit lyrics
  defp handle_song_event("start_edit_lyrics", _, socket) do
    if socket.assigns.current_user.role == :dragon do
      {:noreply, assign(socket, :editing_lyrics, true)}
    else
      {:noreply, socket}
    end
  end

  defp handle_song_event("save_lyrics", %{"text" => text}, socket) do
    if socket.assigns.current_user.role == :dragon do
      Site.update_song_metadata(socket.assigns.song.id, %{text: text})
      song = Site.get_song!(socket.assigns.song.id)

      {:noreply,
       socket
       |> assign(:song, song)
       |> assign(:editing_lyrics, false)
       |> put_flash(:info, "Lyrics updated!")}
    else
      {:noreply, socket}
    end
  end

  defp handle_song_event("cancel_edit_lyrics", _, socket) do
    {:noreply, assign(socket, :editing_lyrics, false)}
  end

  # Admin-only: Upload MP3 file
  defp handle_song_event("upload_mp3", _params, socket) do
    if socket.assigns.current_user.role == :dragon do
      uploaded_files =
        consume_uploaded_entries(socket, :mp3_file, fn %{path: path}, _entry ->
          # Create a temporary upload struct
          upload = %{path: path}

          case Site.upload_song_file(socket.assigns.song.id, upload) do
            {:ok, guid} ->
              {:ok, guid}

            {:error, reason} ->
              {:postpone, reason}
          end
        end)

      socket =
        case uploaded_files do
          [_guid | _] ->
            song = Site.get_song!(socket.assigns.song.id)

            socket
            |> assign(:song, song)
            |> put_flash(:info, "MP3 file uploaded successfully!")

          [] ->
            put_flash(socket, :error, "Failed to upload file")
        end

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  defp handle_song_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :mp3_file, ref)}
  end

  # Handle music events
  defp handle_song_event(event, params, socket) do
    case forward_music_client_event(event, params, socket) do
      :not_music_event -> {:noreply, socket}
      result -> result
    end
  end

  def handle_info(msg, socket) do
    case forward_music_event(msg, socket) do
      :not_music_event -> {:noreply, socket}
      result -> result
    end
  end

  # Helper for upload error messages
  defp error_to_string(:too_large), do: "File is too large (max 50MB)"
  defp error_to_string(:not_accepted), do: "File must be an MP3"
  defp error_to_string(:too_many_files), do: "Only one file allowed"
  defp error_to_string(err), do: "Upload error: #{inspect(err)}"
end
