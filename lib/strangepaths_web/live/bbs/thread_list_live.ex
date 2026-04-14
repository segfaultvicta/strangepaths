defmodule StrangepathsWeb.BBSLive.ThreadList do
  use StrangepathsWeb, :live_view

  import StrangepathsWeb.LiveHelpers
  alias Strangepaths.BBS

  @impl true
  def mount(%{"board_slug" => board_slug}, session, socket) do
    socket = assign_defaults(session, socket)

    try do
      board = BBS.get_board_by_slug!(board_slug)
      thread_rows = BBS.list_threads_with_unread_counts(board, socket.assigns.current_user)

      sticky_ids =
        if socket.assigns.current_user do
          BBS.user_sticky_thread_ids(socket.assigns.current_user.id)
        else
          MapSet.new()
        end

      socket =
        socket
        |> assign(:board, board)
        |> assign(:thread_rows, thread_rows)
        |> assign(:sticky_ids, sticky_ids)
        |> assign(:page_title, board.name)

      {:ok, socket}
    rescue
      Ecto.NoResultsError ->
        {:ok,
         socket
         |> put_flash(:error, "Board not found")
         |> push_redirect(to: Routes.live_path(socket, StrangepathsWeb.BBSLive.BoardList))}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    if socket.assigns.current_user do
      assign(socket, :live_action, :new)
    else
      socket
      |> put_flash(:error, "You must be logged in to create a thread")
      |> push_patch(to: Routes.live_path(socket, StrangepathsWeb.BBSLive.ThreadList, socket.assigns.board.slug))
    end
  end

  defp apply_action(socket, :index, _params) do
    assign(socket, :live_action, :index)
  end

  def format_relative_time(datetime) when is_nil(datetime), do: ""

  def format_relative_time(datetime) do
    now = DateTime.utc_now()
    diff_seconds = DateTime.diff(now, datetime, :second)

    cond do
      diff_seconds < 60 -> "just now"
      diff_seconds < 3600 -> "#{div(diff_seconds, 60)}m ago"
      diff_seconds < 86400 -> "#{div(diff_seconds, 3600)}h ago"
      diff_seconds < 604800 -> "#{div(diff_seconds, 86400)}d ago"
      true -> Calendar.strftime(datetime, "%b %d, %Y")
    end
  end
end
