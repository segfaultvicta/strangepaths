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

  def handle_event(_event, _params, socket) do
    {:noreply, socket}
  end
end
