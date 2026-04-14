defmodule StrangepathsWeb.BBSLive.ThreadList do
  use StrangepathsWeb, :live_view

  import StrangepathsWeb.LiveHelpers
  alias Strangepaths.BBS

  @impl true
  def mount(%{"board_slug" => board_slug}, session, socket) do
    socket = assign_defaults(session, socket)

    case BBS.get_board_by_slug(board_slug) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Board not found")
         |> push_redirect(to: Routes.live_path(socket, StrangepathsWeb.BBSLive.BoardList))}

      board ->
        thread_rows = BBS.list_threads_with_unread_counts(board, socket.assigns.current_user)

        socket =
          socket
          |> assign(:board, board)
          |> assign(:thread_rows, thread_rows)
          |> assign(:page_title, board.name)

        {:ok, socket}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    if socket.assigns.current_user do
      socket
    else
      socket
      |> put_flash(:error, "You must be logged in to create a thread")
      |> push_patch(to: Routes.live_path(socket, StrangepathsWeb.BBSLive.ThreadList, socket.assigns.board.slug))
    end
  end

  defp apply_action(socket, :index, _params) do
    socket
  end
end
