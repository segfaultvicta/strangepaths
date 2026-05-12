defmodule StrangepathsWeb.PageController do
  use StrangepathsWeb, :controller

  alias Strangepaths.Activity

  def index(conn, _params) do
    render(conn, "index.html")
  end

  @valid_types ~w(rumor_change bbs_post library archived_scene)

  def activity(conn, params) do
    type_filter =
      case Map.get(params, "type") do
        t when t in @valid_types -> String.to_existing_atom(t)
        _ -> nil
      end

    recent_activity = Activity.list_recent_activity(conn.assigns[:current_user], 100, type_filter)
    render(conn, "activity.html", recent_activity: recent_activity, active_filter: type_filter)
  end
end
