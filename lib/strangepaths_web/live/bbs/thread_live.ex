defmodule StrangepathsWeb.BBSLive.Thread do
  use StrangepathsWeb, :live_view

  import StrangepathsWeb.LiveHelpers
  import StrangepathsWeb.SceneHelpers
  alias Strangepaths.BBS

  @impl true
  def mount(%{"thread_id" => thread_id} = _params, session, socket) do
    socket = assign_defaults(session, socket)

    case BBS.get_thread(thread_id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Thread not found")
         |> push_redirect(to: Routes.live_path(socket, StrangepathsWeb.BBSLive.BoardList))}

      thread ->
        # Load read mark if user is logged in
        read_mark =
          if socket.assigns.current_user do
            BBS.get_read_mark(socket.assigns.current_user.id, thread_id)
          else
            nil
          end

        posts = BBS.list_posts(thread_id)

        # Subscribe to thread updates and mark posts as read if connected
        if connected?(socket) do
          StrangepathsWeb.Endpoint.subscribe("bbs_thread:#{thread_id}")

          if socket.assigns.current_user do
            BBS.upsert_read_mark(socket.assigns.current_user.id, thread_id)
          end
        end

        socket =
          socket
          |> assign(:thread, thread)
          |> assign(:posts, posts)
          |> assign(:board, thread.board)
          |> assign(:last_read_post_id, read_mark && read_mark.last_read_post_id)
          |> assign(:unread_boundary_index, compute_unread_boundary(posts, read_mark))
          |> assign(:page_title, thread.title)

        {:ok, socket}
    end
  end

  @impl true
  def handle_info(%{event: "new_post", payload: %{post: post}}, socket) do
    # Advance read mark if user is logged in
    if socket.assigns.current_user do
      BBS.advance_read_mark(
        socket.assigns.current_user.id,
        socket.assigns.thread.id,
        post.id,
        post.posted_at
      )
    end

    # Append new post to posts list and push scroll event
    {:noreply,
     socket
     |> assign(:posts, socket.assigns.posts ++ [post])
     |> push_event("bbs-scroll-to-bottom", %{post_id: post.id})}
  end

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  defp compute_unread_boundary(posts, read_mark) do
    if read_mark do
      Enum.find_index(posts, fn p -> p.id > read_mark.last_read_post_id end)
    else
      nil
    end
  end

  def format_timestamp(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y at %I:%M %p")
  end
end
