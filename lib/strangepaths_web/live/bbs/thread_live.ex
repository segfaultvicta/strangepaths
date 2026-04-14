defmodule StrangepathsWeb.BBSLive.Thread do
  use StrangepathsWeb, :live_view

  import StrangepathsWeb.LiveHelpers
  import StrangepathsWeb.BBSHelpers
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

        reply_changeset = BBS.change_post()

        socket =
          socket
          |> assign(:thread, thread)
          |> assign(:posts, posts)
          |> assign(:board, thread.board)
          |> assign(:last_read_post_id, read_mark && read_mark.last_read_post_id)
          |> assign(:unread_boundary_index, compute_unread_boundary(posts, read_mark))
          |> assign(:page_title, thread.title)
          |> assign(:reply_changeset, reply_changeset)

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

  @impl true
  def handle_event("validate_reply", %{"post" => attrs}, socket) do
    changeset = BBS.change_post(%{}, attrs) |> Map.put(:action, :validate)
    {:noreply, assign(socket, :reply_changeset, changeset)}
  end

  @impl true
  def handle_event("create_reply", %{"post" => attrs}, socket) do
    if socket.assigns.current_user do
      if socket.assigns.thread.is_locked do
        {:noreply, put_flash(socket, :error, "This thread is locked.")}
      else
        case BBS.create_post(socket.assigns.thread, socket.assigns.current_user, attrs) do
          {:ok, _post} ->
            # Clear the form and reset changeset
            {:noreply,
             socket
             |> assign(:reply_changeset, BBS.change_post())
             |> push_event("bbs-reply-form-clear", %{})}

          {:error, changeset} ->
            {:noreply,
             socket
             |> put_flash(:error, "Failed to create reply")
             |> assign(:reply_changeset, changeset)}
        end
      end
    else
      {:noreply, put_flash(socket, :error, "You must be logged in to post.")}
    end
  end

  @impl true
  def handle_event("quote_post", %{"post_id" => post_id_str}, socket) do
    if socket.assigns.current_user do
      case Integer.parse(post_id_str) do
        {post_id, ""} ->
          quote_data = BBS.get_post_for_quote(post_id)

          if quote_data do
            # Truncate excerpt to 200 chars
            excerpt = String.slice(quote_data.content, 0, 200)
            same_thread = quote_data.thread_id == socket.assigns.thread.id

            {:noreply,
             push_event(socket, "bbs-insert-quote", %{
               post_id: quote_data.id,
               author: quote_data.display_name,
               thread_id: quote_data.thread_id,
               board: quote_data.board_slug,
               excerpt: excerpt,
               same_thread: same_thread
             })}
          else
            {:noreply, put_flash(socket, :error, "Post not found.")}
          end

        _ ->
          {:noreply, put_flash(socket, :error, "Invalid post ID.")}
      end
    else
      {:noreply, put_flash(socket, :error, "You must be logged in to quote.")}
    end
  end

  defp compute_unread_boundary(posts, read_mark) do
    if read_mark do
      Enum.find_index(posts, fn p -> p.id > read_mark.last_read_post_id end)
    else
      nil
    end
  end
end
