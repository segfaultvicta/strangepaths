defmodule StrangepathsWeb.PageView do
  use StrangepathsWeb, :view

  def format_activity_time(%DateTime{} = dt) do
    StrangepathsWeb.LiveHelpers.format_relative_time(dt)
  end

  def activity_type_label(:rumor_change), do: "map"
  def activity_type_label(:bbs_post), do: "linkpearl"
  def activity_type_label(:marginalia), do: "marginalia"
  def activity_type_label(:folio_update), do: "library"
  def activity_type_label(:archived_scene), do: "scene"
  def activity_type_label(_), do: "activity"

  def filter_pill_class(true),
    do: "px-2 py-0.5 text-xs rounded bg-indigo-500 dark:bg-indigo-600 text-white font-mono"

  def filter_pill_class(false),
    do:
      "px-2 py-0.5 text-xs rounded bg-indigo-100 dark:bg-gray-700 dark:text-gray-300 font-mono hover:bg-indigo-200 dark:hover:bg-gray-600"
end
