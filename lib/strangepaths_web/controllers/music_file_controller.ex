defmodule StrangepathsWeb.MusicFileController do
  use StrangepathsWeb, :controller

  alias Strangepaths.Site

  def serve(conn, %{"guid" => guid}) do
    case Site.get_song_by_guid(guid) do
      nil ->
        conn
        |> put_status(:not_found)
        |> text("File not found")

      song ->
        user = conn.assigns[:current_user]

        # Check if user can access (unlocked OR admin)
        can_access =
          song.unlocked ||
            (user && user.role in [:admin, :god])

        if can_access do
          # Serve the file
          file_path = Path.join([:code.priv_dir(:strangepaths), "static", "music", "#{guid}.mp3"])

          if File.exists?(file_path) do
            conn
            |> put_resp_content_type("audio/mpeg")
            |> put_resp_header("accept-ranges", "bytes")
            |> send_file(200, file_path)
          else
            conn
            |> put_status(:not_found)
            |> text("File not found on disk")
          end
        else
          conn
          |> put_status(:forbidden)
          |> text("This song is locked")
        end
    end
  end
end
