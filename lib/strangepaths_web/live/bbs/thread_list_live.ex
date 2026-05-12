defmodule StrangepathsWeb.BBSLive.ThreadList do
  use StrangepathsWeb, :live_view

  import StrangepathsWeb.LiveHelpers
  import StrangepathsWeb.ErrorHelpers, only: [translate_error: 1]
  alias Strangepaths.BBS

  @impl true
  def mount(%{"board_slug" => board_slug}, session, socket) do
    socket = assign_defaults(session, socket)

    case BBS.get_board_by_slug(board_slug) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Board not found")
         |> push_redirect(to: Routes.bbs_board_list_path(socket, :index))}

      board ->
        if connected?(socket), do: StrangepathsWeb.Endpoint.subscribe("bbs_board:#{board.id}")

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
    # NOTE: mount already loaded thread_rows before this auth check fires.
    # This is intentional in LiveView for :new actions — load-then-redirect is acceptable.
    if socket.assigns.current_user do
      changeset = BBS.change_thread()
      assign(socket, :changeset, changeset)
    else
      socket
      |> put_flash(:error, "You must be logged in to create a thread")
      |> push_patch(
        to:
          Routes.bbs_thread_list_path(socket, :index, socket.assigns.board.slug)
      )
    end
  end

  defp apply_action(socket, :index, _params) do
    socket
  end

  @impl true
  def handle_event("validate_thread", %{"thread" => attrs}, socket) do
    changeset = BBS.change_thread(%BBS.Thread{}, attrs) |> Map.put(:action, :validate)
    {:noreply, assign(socket, :changeset, changeset)}
  end

  @impl true
  def handle_event("create_thread", %{"thread" => attrs}, socket) do
    if socket.assigns.current_user do
      case BBS.create_thread(socket.assigns.board, socket.assigns.current_user, attrs) do
        {:ok, {thread, _post}} ->
          {:noreply,
           socket
           |> put_flash(:info, "Thread created successfully")
           |> push_redirect(
             to:
               Routes.bbs_thread_path(socket, :show, socket.assigns.board.slug, thread.id)
           )}

        {:error, changeset} ->
          {:noreply,
           socket
           |> put_flash(:error, "Failed to create thread")
           |> assign(:changeset, changeset)}
      end
    else
      {:noreply, put_flash(socket, :error, "You must be logged in to post.")}
    end
  end

  # Grimoire glyph toolbar fires typing_state — no-op here
  @impl true
  def handle_event("typing_state", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("toggle_sticky", %{"thread_id" => thread_id_str}, socket) do
    if socket.assigns.current_user do
      case Integer.parse(thread_id_str) do
        {thread_id, ""} ->
          BBS.toggle_sticky(socket.assigns.current_user.id, thread_id)
          # Reload threads to reflect new sticky state
          board = socket.assigns.board
          thread_rows = BBS.list_threads_with_unread_counts(board, socket.assigns.current_user)
          {:noreply, assign(socket, :thread_rows, thread_rows)}

        _ ->
          {:noreply, put_flash(socket, :error, "Invalid thread ID.")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(%{event: "new_thread", payload: %{thread_id: id}}, socket) do
    if Enum.any?(socket.assigns.thread_rows, &(&1.thread.id == id)) do
      {:noreply, socket}
    else
      case BBS.get_thread_row(id, socket.assigns.current_user) do
        nil -> {:noreply, socket}
        row ->
          rows = sort_thread_rows([row | socket.assigns.thread_rows])
          {:noreply, assign(socket, :thread_rows, rows)}
      end
    end
  end

  @impl true
  def handle_info(%{event: "thread_updated", payload: %{thread_id: id}}, socket) do
    case BBS.get_thread_row(id, socket.assigns.current_user) do
      nil -> {:noreply, socket}
      row ->
        rows =
          socket.assigns.thread_rows
          |> Enum.reject(&(&1.thread.id == id))
          |> then(&[row | &1])
          |> sort_thread_rows()
        {:noreply, assign(socket, :thread_rows, rows)}
    end
  end

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  defp sort_thread_rows(rows) do
    Enum.sort_by(rows, fn row ->
      {if(row.thread.is_pinned, do: 1, else: 0),
       if(row.is_stickied, do: 1, else: 0),
       DateTime.to_unix(row.thread.last_post_at)}
    end, :desc)
  end
end
