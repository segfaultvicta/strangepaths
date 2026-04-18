defmodule StrangepathsWeb.BBSLive.BoardList do
  use StrangepathsWeb, :live_view

  import StrangepathsWeb.LiveHelpers
  import StrangepathsWeb.ErrorHelpers
  alias Strangepaths.BBS
  alias Strangepaths.BBS.Board

  @impl true
  def mount(_params, session, socket) do
    socket =
      assign_defaults(session, socket)
      |> assign(:page_title, "The Aethernet")
      |> assign(:show_new_board_form, false)
      |> assign(:changeset, nil)
      |> assign(:manage_mode, false)
      |> assign(:editing_board_id, nil)
      |> assign(:edit_changeset, nil)

    boards = BBS.list_boards()

    {:ok, assign(socket, :boards, boards)}
  end

  @impl true
  def handle_event("toggle_new_board_form", _params, socket) do
    show = socket.assigns.show_new_board_form
    changeset = if show, do: nil, else: BBS.change_board()

    {:noreply,
     socket
     |> assign(:show_new_board_form, not show)
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("validate_board", %{"board" => attrs}, socket) do
    changeset =
      BBS.change_board(%Board{}, attrs)
      |> Map.put(:action, :insert)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  @impl true
  def handle_event("create_board", %{"board" => attrs}, socket) do
    if socket.assigns.current_user && socket.assigns.current_user.role == :dragon do
      case BBS.create_board(attrs) do
        {:ok, board} ->
          {:noreply,
           socket
           |> push_redirect(
             to: Routes.bbs_thread_list_path(socket, :index, board.slug)
           )
           |> put_flash(:info, "Board created successfully.")}

        {:error, changeset} ->
          {:noreply, assign(socket, :changeset, changeset)}
      end
    else
      {:noreply, put_flash(socket, :error, "Unauthorized")}
    end
  end

  @impl true
  def handle_event("toggle_manage_mode", _params, socket) do
    if socket.assigns.current_user && socket.assigns.current_user.role == :dragon do
      managing = socket.assigns.manage_mode

      {:noreply,
       socket
       |> assign(:manage_mode, not managing)
       |> assign(:editing_board_id, nil)
       |> assign(:edit_changeset, nil)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("edit_board", %{"id" => id}, socket) do
    if socket.assigns.current_user && socket.assigns.current_user.role == :dragon do
      board = BBS.get_board!(id)
      {:noreply,
       socket
       |> assign(:editing_board_id, board.id)
       |> assign(:edit_changeset, BBS.change_board(board))}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("cancel_edit_board", _params, socket) do
    {:noreply,
     socket
     |> assign(:editing_board_id, nil)
     |> assign(:edit_changeset, nil)}
  end

  @impl true
  def handle_event("validate_edit_board", %{"board" => attrs}, socket) do
    if socket.assigns.edit_changeset do
      board = BBS.get_board!(socket.assigns.editing_board_id)
      changeset =
        BBS.change_board(board, attrs)
        |> Map.put(:action, :update)

      {:noreply, assign(socket, :edit_changeset, changeset)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("save_board", %{"board" => attrs}, socket) do
    if socket.assigns.current_user && socket.assigns.current_user.role == :dragon do
      board = BBS.get_board!(socket.assigns.editing_board_id)

      case BBS.update_board(board, attrs) do
        {:ok, _board} ->
          {:noreply,
           socket
           |> assign(:editing_board_id, nil)
           |> assign(:edit_changeset, nil)
           |> assign(:boards, BBS.list_boards())}

        {:error, changeset} ->
          {:noreply, assign(socket, :edit_changeset, changeset)}
      end
    else
      {:noreply, put_flash(socket, :error, "Unauthorized")}
    end
  end

  @impl true
  def handle_event("reorder_boards", %{"ids" => ids}, socket) do
    if socket.assigns.current_user && socket.assigns.current_user.role == :dragon do
      BBS.reorder_boards(ids)
      {:noreply, assign(socket, :boards, BBS.list_boards())}
    else
      {:noreply, socket}
    end
  end

  def handle_event(_event, _params, socket) do
    {:noreply, socket}
  end
end
