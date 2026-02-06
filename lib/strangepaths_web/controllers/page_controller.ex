defmodule StrangepathsWeb.PageController do
  use StrangepathsWeb, :controller

  alias Strangepaths.Scenes

  def index(conn, _params) do
    recent_archives = Scenes.list_recent_archived_scenes(conn.assigns[:current_user], 5)
    render(conn, "index.html", recent_archives: recent_archives)
  end
end
