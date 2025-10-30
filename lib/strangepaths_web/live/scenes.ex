defmodule StrangepathsWeb.Scenes do
  use StrangepathsWeb, :live_view

  import StrangepathsWeb.MusicBroadcast
  alias Phoenix.LiveView.JS

  alias Strangepaths.Scenes
  alias Strangepaths.Scenes.SceneServer
  alias Strangepaths.Accounts
  alias Strangepaths.Presence

  @impl true
  def mount(_params, session, socket) do
    socket = assign_defaults(session, socket)
    subscribe_to_music(socket)

    # Check if user is logged in (needed for both disconnected and connected mounts)
    if socket.assigns.current_user do
      # Initialize all assigns with empty/default values (works for disconnected mount)
      socket =
        socket
        |> assign(:scenes, [])
        |> assign(:current_scene, nil)
        |> assign(:posts, [])
        |> assign(:avatars, [])
        |> assign(:avatar_picker_open, false)
        |> assign(:selected_avatar_id, nil)
        |> assign(:selected_avatar, nil)
        |> assign(:open_categories, [])
        |> assign(:present_users, [])
        |> assign(:ascended_users, [])
        |> assign(:post_content, "")
        |> assign(:ooc_content, "")
        |> assign(:posts_offset, 0)
        |> assign(:has_more_posts, false)
        |> assign(:loading_more, false)
        |> assign(:create_scene_name, "")
        |> assign(:create_scene_locked, false)
        |> assign(:create_scene_user_ids, [])
        |> assign(:narrative_mode, false)
        |> assign(:narrative_author_name, "")
        |> assign(:drawer_open, false)
        |> assign(:all_users, [])
        |> assign(:unread_counts, %{})

      # Only load data and subscribe when connected (WebSocket established)
      if connected?(socket) do
        # Subscribe to lobby updates
        StrangepathsWeb.Endpoint.subscribe("scenes:lobby")

        # Load active scenes visible to this user
        scenes = Scenes.list_active_scenes(socket.assigns.current_user)

        # Subscribe to all scenes for unread notifications
        Enum.each(scenes, fn scene ->
          StrangepathsWeb.Endpoint.subscribe("scene:#{scene.id}")
        end)
        elsewhere_scene = Enum.find(scenes, fn s -> s.is_elsewhere end)

        selected_avatar_id = socket.assigns.current_user.selected_avatar_id || nil
        # get that avatar
        selected_avatar =
          if selected_avatar_id, do: Accounts.get_avatar!(selected_avatar_id), else: nil

        # Eventually, I'll want to replace this with
        # "join the last scene your session remembers you being joined on"
        # and fall back to Elsewhere if that scene has been closed, but this
        # will do for now :3

        last_scene_id = socket.assigns.current_user.last_scene_id || nil
        last_scene = if last_scene_id, do: Scenes.get_scene(last_scene_id), else: nil

        # check to make sure that last_scene is still available and not archived
        last_scene =
          if last_scene && last_scene.status == :active do
            last_scene
          else
            nil
          end

        # Also, the right-hand column should show *anyone who's participated*
        # in the scene, not everyone who's currently presence-tracked as present
        # should also use it TO show who, of the participants, is presence-tracked

        socket =
          if last_scene do
            StrangepathsWeb.Endpoint.subscribe("scene:#{last_scene.id}")

            Presence.track(self(), "scene:#{last_scene.id}", socket.id, %{
              user_id: socket.assigns.current_user.id,
              nickname: socket.assigns.current_user.nickname
            })

            posts = SceneServer.get_cached_posts(last_scene.id)

            # Get present users
            present_users = get_present_users(last_scene.id)
            ascended_users = get_ascended_users(present_users)

            socket
            |> assign(:current_scene, last_scene)
            |> assign(:posts, posts)
            |> assign(:posts_offset, length(posts))
            |> assign(:has_more_posts, length(posts) >= 30)
            |> assign(:present_users, present_users)
            |> assign(:ascended_users, ascended_users)
          else
            if elsewhere_scene do
              # automatically join Elsewhere
              StrangepathsWeb.Endpoint.subscribe("scene:#{elsewhere_scene.id}")

              Presence.track(self(), "scene:#{elsewhere_scene.id}", socket.id, %{
                user_id: socket.assigns.current_user.id,
                nickname: socket.assigns.current_user.nickname
              })

              posts = SceneServer.get_cached_posts(elsewhere_scene.id)

              # Get present users
              present_users = get_present_users(elsewhere_scene.id)
              ascended_users = get_ascended_users(present_users)

              socket
              |> assign(:current_scene, elsewhere_scene)
              |> assign(:posts, posts)
              |> assign(:posts_offset, length(posts))
              |> assign(:has_more_posts, length(posts) >= 30)
              |> assign(:present_users, present_users)
              |> assign(:ascended_users, ascended_users)
            else
              socket
            end
          end

        # Get all users for scene locking (Dragon only needs this)
        all_users =
          if socket.assigns.current_user.role == :dragon do
            Accounts.list_users()
          else
            []
          end

        {:ok,
         socket
         |> assign(:scenes, scenes)
         |> assign(:selected_avatar_id, selected_avatar_id)
         |> assign(:selected_avatar, selected_avatar)
         |> assign(:all_users, all_users)}
      else
        # Disconnected mount - just return socket with empty data
        {:ok, socket}
      end
    else
      # No user logged in - redirect (works for both mounts)
      {:ok,
       socket
       |> put_flash(:error, "You must be logged in to access scenes")
       |> redirect(to: "/")}
    end
  end

  @impl true
  def handle_event(event, params, socket) do
    case forward_music_client_event(event, params, socket) do
      :not_music_event ->
        handle_scene_event(event, params, socket)

      result ->
        result
    end
  end

  defp handle_scene_event("open_avatar_picker", _, socket) do
    avatars_by_category =
      Strangepaths.Accounts.list_avatars_by_category(socket.assigns.current_user)

    {:noreply,
     socket
     |> assign(:avatar_picker_open, true)
     |> assign(:avatars_by_category, avatars_by_category)
     |> assign(:open_categories, [])}
  end

  defp handle_scene_event("close_avatar_picker", _, socket) do
    {:noreply, assign(socket, :avatar_picker_open, false)}
  end

  defp handle_scene_event("toggle_category", %{"category" => category}, socket) do
    open_categories = socket.assigns.open_categories

    new_open_categories =
      if category in open_categories do
        List.delete(open_categories, category)
      else
        [category | open_categories]
      end

    {:noreply, assign(socket, :open_categories, new_open_categories)}
  end

  defp handle_scene_event("select_avatar", %{"avatar-id" => avatar_id}, socket) do
    # look up avatar by ID
    avatar_id = String.to_integer(avatar_id)
    avatar = Accounts.get_avatar!(avatar_id)

    # save avatar ID
    {:ok, _user} =
      Accounts.update_user_selected_avatar_id(socket.assigns.current_user, %{
        selected_avatar_id: avatar_id
      })

    {:noreply,
     socket
     |> assign(:avatar_picker_open, false)
     |> assign(:selected_avatar, avatar)
     |> assign(:selected_avatar_id, avatar_id)}
  end

  defp handle_scene_event("select_scene", %{"scene_id" => scene_id_str}, socket) do
    scene_id = String.to_integer(scene_id_str)
    scene = Scenes.get_scene(scene_id)

    if scene && Scenes.can_view_scene?(scene, socket.assigns.current_user) do
      # Unsubscribe from previous scene
      if socket.assigns.current_scene do
        StrangepathsWeb.Endpoint.unsubscribe("scene:#{socket.assigns.current_scene.id}")
        Presence.untrack(self(), "scene:#{socket.assigns.current_scene.id}", socket.id)
      end

      # Subscribe to new scene
      StrangepathsWeb.Endpoint.subscribe("scene:#{scene.id}")

      # Track presence
      Presence.track(self(), "scene:#{scene.id}", socket.id, %{
        user_id: socket.assigns.current_user.id,
        nickname: socket.assigns.current_user.nickname
      })

      # Load posts
      posts = SceneServer.get_cached_posts(scene.id)
      has_more = length(posts) >= 30

      # Get present users
      present_users = get_present_users(scene.id)

      # Get ascended users (public_ascension: true)
      ascended_users = get_ascended_users(present_users)

      # save this scene to the DB as last_scene_id
      {:ok, _user} =
        Accounts.update_user_last_scene_id(socket.assigns.current_user, %{
          last_scene_id: scene_id
        })

      # Clear unread count for this scene
      unread_counts = Map.delete(socket.assigns.unread_counts, scene_id)

      {:noreply,
       socket
       |> assign(:current_scene, scene)
       |> assign(:posts, posts)
       |> assign(:posts_offset, length(posts))
       |> assign(:has_more_posts, has_more)
       |> assign(:present_users, present_users)
       |> assign(:ascended_users, ascended_users)
       |> assign(:post_content, "")
       |> assign(:ooc_content, "")
       |> assign(:unread_counts, unread_counts)}
    else
      {:noreply, put_flash(socket, :error, "You don't have permission to view this scene")}
    end
  end

  defp handle_scene_event("post_message", %{"content" => content} = params, socket) do
    scene = socket.assigns.current_scene
    user = socket.assigns.current_user

    if scene && Scenes.can_post_in_scene?(scene, user) do
      # the dragon can post as other people
      author_name =
        if user.role == :dragon do
          Map.get(params, "author_name", "")
        else
          nil
        end

      ooc_content = Map.get(params, "ooc_content", "")

      IO.puts("in post_message; author_name is #{inspect(author_name)}")

      post_attrs = %{
        scene_id: scene.id,
        user_id: user.id,
        avatar_id: socket.assigns.selected_avatar_id,
        content: String.trim(content),
        narrative_author_name: author_name,
        ooc_content: if(String.trim(ooc_content) != "", do: String.trim(ooc_content), else: nil)
      }

      case Scenes.create_character_post(post_attrs) do
        {:ok, post} ->
          # Preload associations for broadcasting
          post = Strangepaths.Repo.preload(post, [:user, :avatar])
          SceneServer.broadcast_post(scene.id, post)

          {:noreply,
           socket
           |> assign(:post_content, "")
           |> assign(:narrative_author_name, author_name)
           |> assign(:ooc_content, "")}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to post message")}
      end
    else
      {:noreply, put_flash(socket, :error, "You don't have permission to post in this scene")}
    end
  end

  defp handle_scene_event("post_narrative", %{"content" => content} = params, socket) do
    scene = socket.assigns.current_scene
    user = socket.assigns.current_user

    if scene && user.role == :dragon do
      _ooc_content = Map.get(params, "ooc_content", "")
      _author_name = Map.get(params, "author_name", "")

      post_attrs = %{
        scene_id: scene.id,
        user_id: user.id,
        avatar_id: nil,
        # avatar_id: socket.assigns.selected_avatar_id,
        content: String.trim(content),
        ooc_content: nil,
        # ooc_content: if(String.trim(ooc_content) != "", do: String.trim(ooc_content), else: nil),
        narrative_author_name: nil
        # narrative_author_name:
        #  if(String.trim(author_name) != "", do: String.trim(author_name), else: nil)
      }

      case Scenes.create_narrative_post(post_attrs) do
        {:ok, post} ->
          post = Strangepaths.Repo.preload(post, [:user, :avatar])
          SceneServer.broadcast_post(scene.id, post)

          {:noreply,
           socket
           |> assign(:post_content, "")
           |> assign(:ooc_content, "")
           |> assign(:narrative_author_name, "")}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to post narrative")}
      end
    else
      {:noreply, put_flash(socket, :error, "Only the Dragon can post narratives")}
    end
  end

  defp handle_scene_event("toggle_narrative_mode", _params, socket) do
    {:noreply, assign(socket, :narrative_mode, !socket.assigns.narrative_mode)}
  end

  defp handle_scene_event("toggle_drawer", _params, socket) do
    {:noreply, assign(socket, :drawer_open, !socket.assigns.drawer_open)}
  end

  defp handle_scene_event("create_scene", params, socket) do
    user = socket.assigns.current_user

    if Scenes.can_create_scene?(user) do
      name = Map.get(params, "name", "")
      locked = Map.get(params, "locked", "false") == "true"

      user_ids =
        params
        |> Map.get("user_ids", [])
        |> Enum.map(&String.to_integer/1)

      scene_attrs = %{
        name: String.trim(name),
        owner_id: user.id,
        locked_to_users: if(locked, do: user_ids, else: [])
      }

      case Scenes.create_scene(scene_attrs) do
        {:ok, _scene} ->
          # Broadcast scene list update
          SceneServer.broadcast_scene_update()

          # Reload scenes
          scenes = Scenes.list_active_scenes(user)

          {:noreply,
           socket
           |> assign(:scenes, scenes)
           |> assign(:create_scene_name, "")
           |> assign(:create_scene_locked, false)
           |> assign(:create_scene_user_ids, [])
           |> put_flash(:info, "Scene created successfully")}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to create scene")}
      end
    else
      {:noreply, put_flash(socket, :error, "Only the Dragon can create scenes")}
    end
  end

  defp handle_scene_event("archive_scene", %{"scene_id" => scene_id_str}, socket) do
    scene_id = String.to_integer(scene_id_str)
    scene = Scenes.get_scene(scene_id)
    user = socket.assigns.current_user

    case Scenes.archive_scene(scene, user) do
      {:ok, _scene} ->
        SceneServer.broadcast_scene_update()
        scenes = Scenes.list_active_scenes(user)

        socket =
          socket
          |> assign(:scenes, scenes)
          |> put_flash(:info, "Scene archived successfully")

        # If we were viewing the archived scene, clear it
        socket =
          if socket.assigns.current_scene && socket.assigns.current_scene.id == scene_id do
            StrangepathsWeb.Endpoint.unsubscribe("scene:#{scene_id}")
            assign(socket, :current_scene, nil)
          else
            socket
          end

        {:noreply, socket}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, reason)}
    end
  end

  defp handle_scene_event("load_more_posts", _params, socket) do
    scene = socket.assigns.current_scene

    if scene && !socket.assigns.loading_more do
      offset = socket.assigns.posts_offset
      more_posts = Scenes.list_posts(scene.id, 30, offset)
      has_more = length(more_posts) >= 30

      {:noreply,
       socket
       |> assign(:posts, socket.assigns.posts ++ more_posts)
       |> assign(:posts_offset, offset + length(more_posts))
       |> assign(:has_more_posts, has_more)
       |> assign(:loading_more, false)}
    else
      {:noreply, socket}
    end
  end

  defp handle_scene_event(event, params, socket) do
    IO.puts("unhandled event #{event} with params #{inspect(params)}")
    {:noreply, socket}
  end

  # Handle music broadcasts and scene updates
  @impl true
  def handle_info(msg, socket) do
    case forward_music_event(msg, socket) do
      :not_music_event ->
        handle_scene_info(msg, socket)

      result ->
        result
    end
  end

  defp handle_scene_info(%{event: "new_post", payload: payload, topic: topic}, socket) do
    post = payload.post
    # Extract scene_id from topic "scene:123"
    scene_id = topic |> String.split(":") |> List.last() |> String.to_integer()

    # If this is the current scene, add to posts list
    if socket.assigns.current_scene && socket.assigns.current_scene.id == scene_id do
      posts = [post | socket.assigns.posts]
      {:noreply, assign(socket, :posts, posts)}
    else
      # Otherwise, increment unread count for this scene
      unread_counts = Map.update(socket.assigns.unread_counts, scene_id, 1, &(&1 + 1))
      {:noreply, assign(socket, :unread_counts, unread_counts)}
    end
  end

  defp handle_scene_info(%{event: "scene_list_updated"}, socket) do
    # Reload scene list
    scenes = Scenes.list_active_scenes(socket.assigns.current_user)
    {:noreply, assign(socket, :scenes, scenes)}
  end

  defp handle_scene_info(%{event: "presence_diff"}, socket) do
    # Update present users when someone joins/leaves
    if socket.assigns.current_scene do
      present_users = get_present_users(socket.assigns.current_scene.id)
      ascended_users = get_ascended_users(present_users)

      {:noreply,
       socket
       |> assign(:present_users, present_users)
       |> assign(:ascended_users, ascended_users)}
    else
      {:noreply, socket}
    end
  end

  defp handle_scene_info(msg, socket) do
    IO.puts("unhandled message #{inspect(msg)}")
    {:noreply, socket}
  end

  # Helper functions

  defp get_present_users(scene_id) do
    topic = "scene:#{scene_id}"

    Presence.list(topic)
    |> Enum.map(fn {_id, %{metas: [meta | _]}} ->
      # Load full user data
      if meta[:user_id] do
        Accounts.get_user(meta.user_id)
      else
        nil
      end
    end)
    |> Enum.filter(&(&1 != nil))
  end

  defp get_ascended_users(users) do
    users
    |> Enum.filter(fn user -> user.public_ascension == true end)
  end
end
