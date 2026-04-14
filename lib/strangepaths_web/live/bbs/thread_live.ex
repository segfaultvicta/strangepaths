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
         |> push_redirect(to: Routes.bbs_board_list_path(socket, :index))}

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
          |> assign(:editing_post_id, nil)
          |> assign(:show_delete_confirm, false)

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
    changeset = BBS.change_post(%BBS.Post{}, attrs) |> Map.put(:action, :validate)
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
             |> push_event("bbs-reply-form-clear", %{})
             |> push_event("post_submitted", %{})}

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
            # Strip any nested [quote...][/quote] blocks (and stray tags) from the excerpt
            # so that only the plain text of the quoted post is embedded. This prevents
            # deeply-nested quote markup from accumulating and breaking the parser.
            excerpt =
              quote_data.content
              |> String.replace(~r/\[quote[^\]]*\].*?\[\/quote\]/s, "")
              |> String.replace(~r/\[quote[^\]]*\]/, "")
              |> String.replace("[/quote]", "")
              |> String.trim()
              |> String.slice(0, 200)
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

  @impl true
  def handle_event("copy_quote", %{"post_id" => post_id_str}, socket) do
    if socket.assigns.current_user do
      case Integer.parse(post_id_str) do
        {post_id, ""} ->
          quote_data = BBS.get_post_for_quote(post_id)

          if quote_data do
            excerpt =
              quote_data.content
              |> String.replace(~r/\[quote[^\]]*\].*?\[\/quote\]/s, "")
              |> String.replace(~r/\[quote[^\]]*\]/, "")
              |> String.replace("[/quote]", "")
              |> String.trim()
              |> String.slice(0, 200)

            quote_text =
              ~s([quote id=#{quote_data.id} author="#{quote_data.display_name}" thread_id=#{quote_data.thread_id} board="#{quote_data.board_slug}"]\n#{excerpt}\n[/quote]\n\n)

            {:noreply, push_event(socket, "bbs-copy-quote", %{text: quote_text})}
          else
            {:noreply, put_flash(socket, :error, "Post not found.")}
          end

        _ ->
          {:noreply, put_flash(socket, :error, "Invalid post ID.")}
      end
    else
      {:noreply, put_flash(socket, :error, "You must be logged in to copy a quote.")}
    end
  end

  @impl true
  def handle_event("delete_post", %{"post_id" => post_id_str}, socket) do
    with :dragon <- check_dragon(socket),
         {post_id, ""} <- Integer.parse(post_id_str),
         post when not is_nil(post) <- Enum.find(socket.assigns.posts, &(&1.id == post_id)) do
      case BBS.delete_post(post) do
        {:ok, _} ->
          new_posts = Enum.reject(socket.assigns.posts, &(&1.id == post_id))
          thread = %{socket.assigns.thread | post_count: socket.assigns.thread.post_count - 1}

          {:noreply,
           socket
           |> assign(:posts, new_posts)
           |> assign(:thread, thread)
           |> put_flash(:info, "Post deleted.")}

        {:error, :would_empty_thread} ->
          {:noreply,
           put_flash(
             socket,
             :error,
             "Cannot delete the only post. Use 'Delete Thread' to remove the whole thread."
           )}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete post.")}
      end
    else
      :not_dragon -> {:noreply, put_flash(socket, :error, "Unauthorized.")}
      {_, _} -> {:noreply, put_flash(socket, :error, "Invalid post ID.")}
      nil -> {:noreply, put_flash(socket, :error, "Post not found.")}
    end
  end

  @impl true
  def handle_event("start_edit_post", %{"post_id" => post_id_str}, socket) do
    with :dragon <- check_dragon(socket),
         {post_id, ""} <- Integer.parse(post_id_str) do
      {:noreply, assign(socket, :editing_post_id, post_id)}
    else
      :not_dragon -> {:noreply, put_flash(socket, :error, "Unauthorized.")}
      _ -> {:noreply, put_flash(socket, :error, "Invalid post ID.")}
    end
  end

  @impl true
  def handle_event("cancel_edit", _params, socket) do
    {:noreply, assign(socket, :editing_post_id, nil)}
  end

  @impl true
  def handle_event(
        "save_edit_post",
        %{"post_id" => post_id_str, "content" => new_content},
        socket
      ) do
    with :dragon <- check_dragon(socket),
         {post_id, ""} <- Integer.parse(post_id_str),
         post when not is_nil(post) <- Enum.find(socket.assigns.posts, &(&1.id == post_id)) do
      case BBS.update_post(post, socket.assigns.current_user, %{"content" => new_content}) do
        {:ok, updated_post} ->
          new_posts =
            Enum.map(socket.assigns.posts, fn p ->
              if p.id == post_id, do: updated_post, else: p
            end)

          {:noreply,
           socket
           |> assign(:posts, new_posts)
           |> assign(:editing_post_id, nil)
           |> put_flash(:info, "Post updated.")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to update post.")}
      end
    else
      :not_dragon -> {:noreply, put_flash(socket, :error, "Unauthorized.")}
      _ -> {:noreply, put_flash(socket, :error, "Post not found.")}
    end
  end

  @impl true
  def handle_event("toggle_lock", _params, socket) do
    with :dragon <- check_dragon(socket) do
      result =
        if socket.assigns.thread.is_locked do
          BBS.unlock_thread(socket.assigns.thread)
        else
          BBS.lock_thread(socket.assigns.thread)
        end

      case result do
        {:ok, updated_thread} ->
          {:noreply, assign(socket, :thread, updated_thread)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to update thread lock status.")}
      end
    else
      :not_dragon -> {:noreply, put_flash(socket, :error, "Unauthorized.")}
    end
  end

  @impl true
  def handle_event("toggle_pin", _params, socket) do
    with :dragon <- check_dragon(socket) do
      result =
        if socket.assigns.thread.is_pinned do
          BBS.unpin_thread(socket.assigns.thread)
        else
          BBS.pin_thread(socket.assigns.thread)
        end

      case result do
        {:ok, updated_thread} ->
          {:noreply, assign(socket, :thread, updated_thread)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to update thread pin status.")}
      end
    else
      :not_dragon -> {:noreply, put_flash(socket, :error, "Unauthorized.")}
    end
  end

  @impl true
  def handle_event("show_delete_confirm", _params, socket) do
    with :dragon <- check_dragon(socket) do
      {:noreply, assign(socket, :show_delete_confirm, true)}
    else
      :not_dragon -> {:noreply, put_flash(socket, :error, "Unauthorized.")}
    end
  end

  @impl true
  def handle_event("cancel_delete_confirm", _params, socket) do
    {:noreply, assign(socket, :show_delete_confirm, false)}
  end

  @impl true
  def handle_event("delete_thread", _params, socket) do
    with :dragon <- check_dragon(socket) do
      case BBS.delete_thread(socket.assigns.thread) do
        {:ok, _} ->
          {:noreply,
           socket
           |> assign(:show_delete_confirm, false)
           |> push_redirect(
             to:
               Routes.bbs_thread_list_path(socket, :index, socket.assigns.board.slug)
           )}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete thread.")}
      end
    else
      :not_dragon -> {:noreply, put_flash(socket, :error, "Unauthorized.")}
    end
  end

  # Grimoire glyph toolbar fires typing_state — no-op here
  @impl true
  def handle_event("typing_state", _params, socket), do: {:noreply, socket}

  defp check_dragon(socket) do
    if socket.assigns.current_user && socket.assigns.current_user.role == :dragon do
      :dragon
    else
      :not_dragon
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
