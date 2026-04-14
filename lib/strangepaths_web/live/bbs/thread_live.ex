defmodule StrangepathsWeb.BBSLive.Thread do
  use StrangepathsWeb, :live_view

  import StrangepathsWeb.LiveHelpers
  import StrangepathsWeb.SceneHelpers
  alias Strangepaths.BBS

  @impl true
  def mount(%{"thread_id" => thread_id} = _params, session, socket) do
    socket = assign_defaults(session, socket)

    try do
      thread = BBS.get_thread!(thread_id)

      # Load read mark if user is logged in
      read_mark =
        if socket.assigns.current_user do
          BBS.get_read_mark(socket.assigns.current_user.id, thread_id)
        else
          nil
        end

      posts = BBS.list_posts(thread_id)

      # Mark all posts as read if user is logged in
      if socket.assigns.current_user do
        BBS.upsert_read_mark(socket.assigns.current_user.id, thread_id)
      end

      # Subscribe to thread updates if connected
      socket =
        if connected?(socket) do
          StrangepathsWeb.Endpoint.subscribe("bbs_thread:#{thread_id}")
          socket
        else
          socket
        end

      socket =
        socket
        |> assign(:thread, thread)
        |> assign(:posts, posts)
        |> assign(:board, thread.board)
        |> assign(:last_read_post_id, read_mark && read_mark.last_read_post_id)
        |> assign(:page_title, thread.title)

      {:ok, socket}
    rescue
      Ecto.NoResultsError ->
        {:ok,
         socket
         |> put_flash(:error, "Thread not found")
         |> push_redirect(to: Routes.live_path(socket, StrangepathsWeb.BBSLive.BoardList))}
    end
  end

  @impl true
  def handle_info(%{"event" => "new_post", "payload" => %{"post" => post_data}}, socket) do
    # Reconstruct the post with user preloaded
    post = BBS.get_post!(post_data["id"])

    # Advance read mark if user is logged in
    socket =
      if socket.assigns.current_user do
        BBS.advance_read_mark(
          socket.assigns.current_user.id,
          socket.assigns.thread.id,
          post.id,
          post.posted_at
        )

        socket
      else
        socket
      end

    # Append new post to posts list and push scroll event
    {:noreply,
     socket
     |> assign(:posts, socket.assigns.posts ++ [post])
     |> push_event("bbs-scroll-to-bottom", %{})}
  end

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  def format_timestamp(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y at %I:%M %p")
  end

  def post_id_greater?(_post_id, last_read_id) when is_nil(last_read_id), do: true
  def post_id_greater?(post_id, last_read_id), do: post_id > last_read_id
end
