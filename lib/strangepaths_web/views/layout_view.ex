defmodule StrangepathsWeb.LayoutView do
  use StrangepathsWeb, :view

  # Phoenix LiveDashboard is available only in development by default,
  # so we instruct Elixir to not warn if the dashboard route is missing.
  @compile {:no_warn_undefined, {Routes, :live_dashboard_path, 2}}

  def navclass(conn, item) do
    "my-1 text-lg font-large md:mx-4 md:my-0 hover:text-sky-300 " <>
      if conn.request_path =~ Atom.to_string(item), do: "activenav", else: "inactivenav"
  end
end
