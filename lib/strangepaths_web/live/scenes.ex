defmodule StrangepathsWeb.Scenes do
  use StrangepathsWeb, :live_view

  import StrangepathsWeb.MusicBroadcast
  alias Phoenix.LiveView.JS

  alias Strangepaths.Scenes
  alias Strangepaths.Scenes.SceneServer
  alias Strangepaths.Accounts
  alias Strangepaths.Presence

  alias StrangepathsWeb.Endpoint, as: E

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
        |> assign(:rhs_users, [])
        |> assign(:eligible, false)
        |> assign(:post_mode, :action)
        |> assign(:post_content, "")
        |> assign(:saved_post_content, "")
        |> assign(:saved_ooc_content, "")
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
        |> assign(:ascended_users, [])
        |> assign(:private_users, [])
        |> assign(:collapse_manage_users, true)
        |> assign(:collapse_userlist, false)
        |> assign(:collapse_private_users, true)
        |> assign(:collapse_rhs_controls, false)
        |> assign(:arete_expenditure, 0)
        |> assign(:crimes, System.unique_integer())
        |> assign(:collapse_new_techne, true)
        |> assign(:new_techne_name, "")
        |> assign(:new_techne_desc, "")
        |> assign(:selected_techne_name, "")
        |> assign(:selected_techne_desc, "")
        |> assign(:selected_gnosis_color, nil)
        |> assign(:collapse_gm_controls, false)
        |> assign(:collapse_gm_user_controls, true)
        |> assign(:collapse_gm_roll_controls, true)
        |> assign(:roll_rank, 4)
        |> assign(:gm_alethic, false)
        |> assign(:gm_techne_name, "")
        |> assign(:gm_techne_desc, "")
        |> assign(:collapse_devour, true)
        |> assign(:unread_counts, %{})
        |> assign(:dragon_selections, %{})

      # Only load data and subscribe when connected (WebSocket established)
      if connected?(socket) do
        # Subscribe to lobby updates
        E.subscribe("scenes:lobby")

        # Subscribe to ascension updates
        E.subscribe("ascension")

        # Load active scenes visible to this user
        scenes = Scenes.list_active_scenes(socket.assigns.current_user)

        # Subscribe to all scenes for unread notifications
        Enum.each(scenes, fn scene ->
          E.subscribe("scene:#{scene.id}")
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

        # for Dragon tools, get ascended and private users
        ascended_users = Accounts.get_ascended_users()
        private_users = Accounts.get_private_users()

        socket =
          if socket.assigns.current_user.role == :dragon do
            socket
            |> assign(:ascended_users, ascended_users)
            |> assign(:private_users, private_users)
          else
            socket
          end

        socket =
          if last_scene do
            # Already subscribed to all scenes above, just track presence
            Presence.track(self(), "scene:#{last_scene.id}", socket.id, %{
              user_id: socket.assigns.current_user.id,
              nickname: socket.assigns.current_user.nickname
            })

            posts = SceneServer.get_cached_posts(last_scene.id)

            # Get present users
            present_users = get_present_users(last_scene.id)
            rhs_users = Strangepaths.Scenes.rhs_eligible(last_scene)

            socket
            |> assign(:current_scene, last_scene)
            |> assign(:posts, posts)
            |> assign(:posts_offset, length(posts))
            |> assign(:has_more_posts, length(posts) >= 30)
            |> assign(:present_users, present_users)
            |> assign(:rhs_users, rhs_users)
            |> assign(
              :eligible,
              Strangepaths.Scenes.post_eligible(socket.assigns.current_user, last_scene)
            )
          else
            if elsewhere_scene do
              # automatically join Elsewhere (already subscribed above, just track presence)
              Presence.track(self(), "scene:#{elsewhere_scene.id}", socket.id, %{
                user_id: socket.assigns.current_user.id,
                nickname: socket.assigns.current_user.nickname
              })

              posts = SceneServer.get_cached_posts(elsewhere_scene.id)

              # Get present users
              present_users = get_present_users(elsewhere_scene.id)
              rhs_users = Strangepaths.Scenes.rhs_eligible(elsewhere_scene)

              socket
              |> assign(:current_scene, elsewhere_scene)
              |> assign(:posts, posts)
              |> assign(:posts_offset, length(posts))
              |> assign(:has_more_posts, length(posts) >= 30)
              |> assign(:present_users, present_users)
              |> assign(:rhs_users, rhs_users)
              |> assign(:eligible, true)
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

  # JOIN A SCENE FROM THE LIST OF SCENES

  defp handle_scene_event("select_scene", %{"scene_id" => scene_id_str}, socket) do
    scene_id = String.to_integer(scene_id_str)
    scene = Scenes.get_scene(scene_id)

    if scene && Scenes.can_view_scene?(scene, socket.assigns.current_user) do
      # Untrack presence from previous scene (stay subscribed for unread counts)
      if socket.assigns.current_scene do
        Presence.untrack(self(), "scene:#{socket.assigns.current_scene.id}", socket.id)
      end

      # Track presence in new scene (already subscribed for unread counts)
      Presence.track(self(), "scene:#{scene.id}", socket.id, %{
        user_id: socket.assigns.current_user.id,
        nickname: socket.assigns.current_user.nickname
      })

      # Load posts
      posts = SceneServer.get_cached_posts(scene.id)
      has_more = length(posts) >= 30

      # Get present users
      present_users = get_present_users(scene.id)

      rhs_users = Strangepaths.Scenes.rhs_eligible(scene)

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
       |> assign(:rhs_users, rhs_users)
       |> assign(:eligible, Strangepaths.Scenes.post_eligible(socket.assigns.current_user, scene))
       |> assign(:post_content, "")
       |> assign(:ooc_content, "")
       |> assign(:unread_counts, unread_counts)
       |> push_event("focus_post_input", %{})}
    else
      {:noreply, put_flash(socket, :error, "You don't have permission to view this scene")}
    end
  end

  defp handle_scene_event("toggle_post_mode", _params, socket) do
    socket =
      if socket.assigns.post_mode == :action do
        socket
        |> assign(:post_mode, :speech)
      else
        socket
        |> assign(:post_mode, :action)
      end

    {:noreply, socket}
  end

  defp handle_scene_event("update_post_content", params, socket) do
    ooc_content = Map.get(params, "ooc_content", socket.assigns.ooc_content)
    post_content = Map.get(params, "content", socket.assigns.post_content)

    {:noreply,
     socket
     |> assign(:post_content, post_content)
     |> assign(:ooc_content, ooc_content)}
  end

  defp handle_scene_event("update_narrative_author_name", %{"author_name" => author_name}, socket) do
    {:noreply, assign(socket, :narrative_author_name, author_name)}
  end

  defp handle_scene_event("post_message", %{"content" => content} = params, socket) do
    scene = socket.assigns.current_scene
    user = socket.assigns.current_user

    if scene && user.id in (Scenes.rhs_eligible(scene) |> Enum.map(& &1.id)) do
      author_name =
        if user.role == :dragon do
          Map.get(params, "author_name", "")
        else
          nil
        end

      ooc_content = Map.get(params, "ooc_content", "")

      content =
        if socket.assigns.post_mode == :speech do
          "*says,* \“" <> content <> "\”"
        else
          "*" <> transform_quotes(content) <> "*"
        end

      # if the last two characters of content are "**" preceded by a "”",
      # remove the final asterisks.
      content =
        if String.ends_with?(content, "”**") do
          String.slice(content, 0..-3//-1)
        else
          content
        end

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

  defp handle_scene_event("post_narrative", %{"content" => content} = _params, socket) do
    scene = socket.assigns.current_scene
    user = socket.assigns.current_user

    if scene && user.role == :dragon do
      post_attrs = %{
        scene_id: scene.id,
        user_id: user.id,
        avatar_id: nil,
        content: "ꙮ " <> String.trim(content),
        ooc_content: nil,
        narrative_author_name: nil
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

  defp handle_scene_event("manage_users", %{"user_ids" => user_ids}, socket) do
    Strangepaths.Scenes.update_scene_locked_users(
      socket.assigns.current_scene.id,
      Enum.map(user_ids, &String.to_integer/1)
    )

    # trigger an *ascension* update, because that'll update rhs_eligible for people
    E.broadcast("ascension", "update", %{})
    # also want a scene update
    SceneServer.broadcast_scene_update()

    {:noreply, socket}
  end

  defp handle_scene_event("toggle_manage_users", _params, socket) do
    {:noreply,
     socket
     |> assign(:collapse_manage_users, !socket.assigns.collapse_manage_users)}
  end

  defp handle_scene_event("toggle_drawer", _params, socket) do
    {:noreply, assign(socket, :drawer_open, !socket.assigns.drawer_open)}
  end

  defp handle_scene_event("toggle_userlist", _params, socket) do
    {:noreply, assign(socket, :collapse_userlist, !socket.assigns.collapse_userlist)}
  end

  defp handle_scene_event("toggle_rhs_controls", _params, socket) do
    {:noreply, assign(socket, :collapse_rhs_controls, !socket.assigns.collapse_rhs_controls)}
  end

  defp handle_scene_event("toggle_gm_controls", _params, socket) do
    {:noreply, assign(socket, :collapse_gm_controls, !socket.assigns.collapse_gm_controls)}
  end

  defp handle_scene_event("toggle_gm_user_controls", _params, socket) do
    {:noreply,
     assign(socket, :collapse_gm_user_controls, !socket.assigns.collapse_gm_user_controls)}
  end

  defp handle_scene_event("toggle_private_users", _params, socket) do
    {:noreply, assign(socket, :collapse_private_users, !socket.assigns.collapse_private_users)}
  end

  defp handle_scene_event("toggle_gm_roll_controls", _params, socket) do
    {:noreply,
     assign(socket, :collapse_gm_roll_controls, !socket.assigns.collapse_gm_roll_controls)}
  end

  defp handle_scene_event("toggle_devour", _params, socket) do
    {:noreply, assign(socket, :collapse_devour, !socket.assigns.collapse_devour)}
  end

  defp handle_scene_event("toggle_new_techne", _params, socket) do
    {:noreply, assign(socket, :collapse_new_techne, !socket.assigns.collapse_new_techne)}
  end

  defp handle_scene_event("toggle_ascension", %{"id" => id}, socket) do
    user = Accounts.get_user!(id)

    {:ok, _user} =
      Accounts.update_user_ascension(
        user,
        %{public_ascension: !user.public_ascension}
      )

    E.broadcast("ascension", "update", %{})

    {:noreply, socket}
  end

  defp handle_scene_event("clear_ascension", %{"id" => id}, socket) do
    user = Accounts.get_user!(id)
    Accounts.clear_user(user)
    E.broadcast("ascension", "update", %{})
    {:noreply, socket}
  end

  defp handle_scene_event(
         "update_arete_selection",
         %{"user-id" => user_id, "arete" => arete_str},
         socket
       ) do
    arete = String.to_integer(arete_str)
    user_selections = Map.get(socket.assigns.dragon_selections, user_id, %{})
    updated_selections = Map.put(user_selections, :arete, arete)
    dragon_selections = Map.put(socket.assigns.dragon_selections, user_id, updated_selections)

    {:noreply, assign(socket, :dragon_selections, dragon_selections)}
  end

  defp handle_scene_event(
         "select_sacrifice_color",
         %{"user-id" => user_id, "color" => color},
         socket
       ) do
    user_selections = Map.get(socket.assigns.dragon_selections, user_id, %{})
    # Toggle: if clicking same color, deselect it
    current_color = Map.get(user_selections, :color)
    new_color = if current_color == color, do: nil, else: color
    updated_selections = Map.put(user_selections, :color, new_color)
    dragon_selections = Map.put(socket.assigns.dragon_selections, user_id, updated_selections)

    {:noreply, assign(socket, :dragon_selections, dragon_selections)}
  end

  defp handle_scene_event(
         "update_sacrifice_ranks",
         %{"user-id" => user_id, "ranks" => ranks_str},
         socket
       ) do
    ranks = String.to_integer(ranks_str)
    user_selections = Map.get(socket.assigns.dragon_selections, user_id, %{})
    updated_selections = Map.put(user_selections, :ranks, ranks)
    dragon_selections = Map.put(socket.assigns.dragon_selections, user_id, updated_selections)

    {:noreply, assign(socket, :dragon_selections, dragon_selections)}
  end

  # TODO send narrative posts
  defp handle_scene_event("apply_dragon_changes", %{"user-id" => user_id_str}, socket) do
    user = Accounts.get_user!(user_id_str)
    selections = Map.get(socket.assigns.dragon_selections, user_id_str, %{})

    msg = ""

    # Award Arete if > 0
    arete_amount = Map.get(selections, :arete, 0)

    msg =
      if arete_amount > 0 do
        Accounts.update_user_arete(user, %{arete: user.arete + arete_amount})

        "- #{user.nickname} has gained #{arete_amount} Arete, and now has #{user.arete + arete_amount}."
      else
        msg
      end

    # Demand Sacrifice if color and ranks > 0
    color = Map.get(selections, :color)
    ranks = Map.get(selections, :ranks, 0)

    msg =
      if color && ranks > 0 && color in ["red", "green", "blue", "white", "black", "empty"] do
        case Strangepaths.Accounts.gm_driven_sacrifice_of(user, color, ranks) do
          {:ok, n} ->
            "- #{user.nickname} was made to sacrifice #{cardinality_lookup(n)} of their #{color_lookup(color)} gnosis."

          {:error, reason} ->
            "ERROR: #{user.nickname}'s sacrifice failed: #{reason}"
        end
      else
        msg
      end

    # Broadcast update
    E.broadcast("ascension", "update", %{})

    # Clear selections for this user
    dragon_selections = Map.delete(socket.assigns.dragon_selections, user_id_str)

    Scenes.system_message(msg, false, socket.assigns.current_scene.id)

    {:noreply, assign(socket, :dragon_selections, dragon_selections)}
  end

  defp handle_scene_event(
         "update_roll_rank",
         %{"_target" => ["alethic"], "alethic" => "on"},
         socket
       ) do
    {:noreply, assign(socket, :gm_alethic, true)}
  end

  defp handle_scene_event("update_roll_rank", %{"_target" => ["alethic"]}, socket) do
    {:noreply, assign(socket, :gm_alethic, false)}
  end

  defp handle_scene_event(
         "update_roll_rank",
         %{"_target" => ["roll_rank"], "roll_rank" => roll_rank_str},
         socket
       ) do
    roll_rank = String.to_integer(roll_rank_str)
    {:noreply, assign(socket, :roll_rank, roll_rank)}
  end

  defp handle_scene_event(
         "update_gm_techne",
         %{"techne-desc" => desc, "techne-name" => name},
         socket
       ) do
    {:noreply,
     socket
     |> assign(:gm_techne_name, name)
     |> assign(:gm_techne_desc, desc)}
  end

  defp handle_scene_event("roll_gm_color", %{"color" => color}, socket) do
    # rank to roll will be stored in @roll_rank
    nickname =
      if socket.assigns.narrative_author_name != nil and
           socket.assigns.narrative_author_name != "" do
        socket.assigns.narrative_author_name
      else
        "The Dragon"
      end

    roll =
      if socket.assigns.gm_alethic do
        roll1 = Enum.random(1..socket.assigns.roll_rank)
        roll2 = Enum.random(1..socket.assigns.roll_rank)
        {:alethic, socket.assigns.roll_rank, max(roll1, roll2), roll1, roll2}
      else
        result = Enum.random(1..socket.assigns.roll_rank)
        {:mundane, socket.assigns.roll_rank, result}
      end

    msg = roll_message(nickname, color, roll)

    msg =
      if socket.assigns.gm_techne_name != "" do
        "- #{msg}\n\n#{nickname} invoked their techné **#{socket.assigns.gm_techne_name}** *(#{socket.assigns.gm_techne_desc})*"
      else
        msg
      end

    Scenes.system_message(msg, false, socket.assigns.current_scene.id)

    {:noreply,
     socket
     |> assign(:gm_techne_name, nil)
     |> assign(:gm_techne_desc, nil)}
  end

  defp handle_scene_event("post_gm_techne", _, socket) do
    # posting techne WITHOUT a roll happening at the same time, awoo
    if socket.assigns.gm_techne_name != nil do
      nickname =
        if socket.assigns.narrative_author_name != nil and
             socket.assigns.narrative_author_name != "" do
          socket.assigns.narrative_author_name
        else
          "The Dragon"
        end

      msg =
        "- #{nickname} invoked their techné **#{socket.assigns.gm_techne_name}** *(#{socket.assigns.gm_techne_desc})*"

      Scenes.system_message(msg, false, socket.assigns.current_scene.id)

      {:noreply,
       socket
       |> assign(:gm_techne_name, nil)
       |> assign(:gm_techne_desc, nil)}
    else
      {:noreply, socket}
    end
  end

  defp handle_scene_event("devour", _, socket) do
    users = Strangepaths.Accounts.get_ascended_users()

    msgs =
      Enum.map(users, fn user ->
        {:ok, red} = Strangepaths.Accounts.gm_driven_sacrifice_to(user, "red", 4)
        {:ok, green} = Strangepaths.Accounts.gm_driven_sacrifice_to(user, "green", 4)
        {:ok, blue} = Strangepaths.Accounts.gm_driven_sacrifice_to(user, "blue", 4)
        {:ok, white} = Strangepaths.Accounts.gm_driven_sacrifice_to(user, "white", 4)
        {:ok, black} = Strangepaths.Accounts.gm_driven_sacrifice_to(user, "black", 4)
        {:ok, void} = Strangepaths.Accounts.gm_driven_sacrifice_to(user, "empty", 4)

        ranks =
          [
            {red, "red"},
            {green, "green"},
            {blue, "blue"},
            {white, "white"},
            {black, "black"},
            {void, "empty"}
          ]
          |> Enum.reject(fn {val, _} -> val == 0 end)
          |> Enum.map(fn {val, color} ->
            "#{cardinality_lookup(round(val))} of your #{color_lookup(color)} gnosis"
          end)
          |> case do
            [] ->
              ""

            [single] ->
              single

            [first, second] ->
              "#{first} and #{second}"

            list ->
              {last, rest} = List.pop_at(list, -1)
              Enum.join(rest, ", ") <> ", and #{last}"
          end

        if ranks == "" do
          nil
        else
          "- **#{user.nickname}**: you have sacrificed #{ranks}.\n\n"
        end
      end)

    StrangepathsWeb.Endpoint.broadcast("ascension", "update", %{})

    msg =
      "The worlds have been consumed, in overgrowth, in madness, and in fire.\n\n" <>
        (msgs
         |> Enum.reject(fn x -> x == nil end)
         |> Enum.join(""))

    Scenes.system_message(msg, true, socket.assigns.current_scene.id)

    {:noreply, socket}
  end

  # USERSPACE ASCENSION CONTROLS

  defp handle_scene_event(
         "change_techne",
         %{"new_techne_name" => name, "new_techne_desc" => desc},
         socket
       ) do
    {:noreply, socket |> assign(:new_techne_name, name) |> assign(:new_techne_desc, desc)}
  end

  defp handle_scene_event("delete_techne", %{"name" => name}, socket) do
    user = socket.assigns.current_user

    current_true_techne = Strangepaths.Accounts.get_user!(user.id).techne

    new_techne =
      Enum.filter(current_true_techne, fn t ->
        String.split(t, ":") |> hd() != name
      end)

    {:ok, _} = Strangepaths.Accounts.update_user_techne(user, %{techne: new_techne})

    StrangepathsWeb.Endpoint.broadcast("ascension", "update", %{})

    {:noreply, socket}
  end

  defp handle_scene_event("select_techne", %{"name" => name, "desc" => desc}, socket) do
    if socket.assigns.selected_techne_name == name do
      {:noreply, socket |> assign(:selected_techne_name, "") |> assign(:selected_techne_desc, "")}
    else
      {:noreply,
       socket |> assign(:selected_techne_name, name) |> assign(:selected_techne_desc, desc)}
    end
  end

  defp handle_scene_event("select_gnosis_color", %{"color" => color}, socket) do
    if socket.assigns.selected_gnosis_color == color do
      {:noreply, socket |> assign(:selected_gnosis_color, nil)}
    else
      {:noreply, socket |> assign(:selected_gnosis_color, color)}
    end
  end

  defp handle_scene_event("user_ascension_action", _, socket) do
    user = socket.assigns.current_user

    msg = ""

    # handle rolls
    msg =
      msg <>
        if socket.assigns.selected_gnosis_color != nil and
             socket.assigns.selected_gnosis_color != "" do
          color = socket.assigns.selected_gnosis_color

          color =
            if color == "empty" do
              "void"
            else
              color
            end

          primary = Map.get(user, String.to_atom("primary_#{color}"))
          alethic = Map.get(user, String.to_atom("alethic_#{color}"))

          roll =
            if alethic > 0 and alethic >= primary do
              roll1 = Enum.random(1..primary)
              roll2 = Enum.random(1..primary)
              {:alethic, alethic, max(roll1, roll2), roll1, roll2}
            else
              result = Enum.random(1..primary)
              {:mundane, primary, result}
            end

          roll_message(user.nickname, color, roll) <> "\n\n"
        else
          ""
        end

    msg =
      msg <>
        if socket.assigns.arete_expenditure != 0 do
          curr_arete = user.arete
          spending_arete = socket.assigns.arete_expenditure
          # should not be able to ever spend more arete than you have, but just in case
          new_arete = max(curr_arete - spending_arete, 0)
          Strangepaths.Accounts.update_user_arete(user, %{arete: new_arete})

          "- **#{user.nickname}** spent #{spending_arete} Arete and now has #{new_arete} remaining.\n\n"
        else
          ""
        end

    msg =
      msg <>
        if socket.assigns.selected_techne_name != "" do
          name = socket.assigns.selected_techne_name
          desc = socket.assigns.selected_techne_desc

          "- **#{user.nickname}** invoked their techné **#{name}** *(#{desc})*"
        else
          ""
        end

    msg =
      msg <>
        if socket.assigns.new_techne_name != "" and socket.assigns.new_techne_desc != "" do
          current_true_techne = Strangepaths.Accounts.get_user!(user.id).techne

          new_techne =
            current_true_techne ++
              ["#{socket.assigns.new_techne_name}:#{socket.assigns.new_techne_desc}"]

          Strangepaths.Accounts.update_user_techne(user, %{techne: new_techne})

          "- **#{user.nickname}** has attained unto the techné **#{socket.assigns.new_techne_name}** *(#{socket.assigns.new_techne_desc})*\n\n"
        else
          ""
        end

    if msg != "" do
      E.broadcast("ascension", "update", %{})

      Strangepaths.Scenes.system_message(msg, false, socket.assigns.current_scene.id)

      {:noreply,
       socket
       |> assign(:arete_expenditure, 0)
       |> assign(:crimes, System.unique_integer())
       |> assign(:toggle_new_techne, false)
       |> assign(:selected_gnosis_color, nil)
       |> assign(:selected_techne_name, "")
       |> assign(:selected_techne_desc, "")
       |> assign(:new_techne_name, "")
       |> assign(:new_techne_desc, "")}
    else
      {:noreply, socket}
    end
  end

  defp handle_scene_event(
         "validate_arete",
         %{"arete_extern" => %{"spend_arete" => arete}},
         socket
       ) do
    {:noreply, assign(socket, :arete_expenditure, String.to_integer(arete))}
  end

  defp handle_scene_event("ascend", %{"color" => color}, socket) do
    user = socket.assigns.current_user

    color =
      if color == "empty" do
        "void"
      else
        color
      end

    {also_elsewhere, resp} =
      case Strangepaths.Accounts.ascend(user, color) do
        :alethic_sacrifice ->
          {true,
           "- **#{user.nickname}** chose to perform a beautiful, and terrible, magic; for a brief moment their [redacted] sacrifice of their entire #{color_lookup(color)} gnosis allows them communion with the Dragon."}

        {:ascension_successful, new_die} ->
          {false,
           "- **#{user.nickname}**'s #{color_lookup(color)} gnosis has ascended unto the #{Integer.to_string(new_die)}ᵗʰ rank."}
      end

    Strangepaths.Scenes.system_message(resp, also_elsewhere, socket.assigns.current_scene.id)

    E.broadcast("ascension", "update", %{})

    {:noreply, socket}
  end

  defp handle_scene_event("sacrifice", %{"color" => color}, socket) do
    user = socket.assigns.current_user

    Strangepaths.Accounts.player_driven_sacrifice(user, color)
    msg = "- #{user.nickname} made an offering of their #{color_lookup(color)} gnosis."

    Strangepaths.Scenes.system_message(msg, false, socket.assigns.current_scene.id)

    E.broadcast("ascension", "update", %{})

    {:noreply, socket}
  end

  # POST MANAGEMENT

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
            E.unsubscribe("scene:#{scene_id}")
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

  defp handle_scene_event(_event, _params, socket) do
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
      rhs_users = Strangepaths.Scenes.rhs_eligible(socket.assigns.current_scene)

      {:noreply,
       socket
       |> assign(:present_users, present_users)
       |> assign(:rhs_users, rhs_users)}
    else
      {:noreply, socket}
    end
  end

  defp handle_scene_info(%{topic: "ascension", event: "update"}, socket) do
    socket =
      if socket.assigns.current_user.role == :dragon do
        socket
        |> assign(:ascended_users, Accounts.get_ascended_users())
        |> assign(:private_users, Accounts.get_private_users())
        |> assign(:rhs_users, Strangepaths.Scenes.rhs_eligible(socket.assigns.current_scene))
      else
        # Need to be updating the current user's techne, arete, primaries, and alethics
        user = Strangepaths.Accounts.get_user!(socket.assigns.current_user.id)

        techne =
          case user.techne do
            nil ->
              [{"", ""}]

            _ ->
              Enum.map(user.techne, fn techne ->
                case String.split(techne, ":", parts: 2) do
                  [name, desc] -> %{name: String.trim(name), desc: String.trim(desc)}
                  [name] -> %{name: String.trim(name), desc: ""}
                end
              end)
          end

        socket
        |> assign(:rhs_users, Strangepaths.Scenes.rhs_eligible(socket.assigns.current_scene))
        |> assign(:current_user, %{user | techne: techne})
      end

    {:noreply, socket}
  end

  defp handle_scene_info(_msg, socket) do
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

  defp transform_quotes(text) do
    text
    |> String.graphemes()
    |> Enum.reduce({[], false}, fn char, {acc, in_quote} ->
      case char do
        "\"" when in_quote ->
          # Closing quote - add italic marker after the quote
          {acc ++ ["\”", "*"], false}

        "\"" when not in_quote ->
          # Opening quote - add italic marker before the quote
          {acc ++ ["*", "\“"], true}

        other ->
          {acc ++ [other], in_quote}
      end
    end)
    |> elem(0)
    |> Enum.join()
  end

  defp color_lookup(color) do
    case color do
      "red" -> "🔴burning"
      "blue" -> "🔵pellucid"
      "green" -> "🟢flourishing"
      "white" -> "⚪radiant"
      "black" -> "⚫tenebrous"
      "empty" -> "🌌liminal"
      "void" -> "🌌liminal"
    end
  end

  defp cardinality_lookup(n) do
    case n do
      0 -> "naught"
      1 -> "once"
      2 -> "twice"
      3 -> "thrice"
      4 -> "deeply"
      5 -> "utterly and absolutely"
      _ -> ""
    end
  end

  defp get_desc(color) do
    case color do
      "red" ->
        "Red actions are impulsive, physical, brave or foolish; they are sparked by passion and emotions running high and a love of freedom above all else."

      "green" ->
        "Green actions are instinctive, harmonious and accepting of the world as it is; they are focused on growth, interdependence and deep context."

      "blue" ->
        "Blue actions are clever, cunning, and logical; they are taken towards achieving perfection and certainty, understanding the world through analysis and study, or fulfilling one's inherent potential."

      "white" ->
        "White actions are lawful and selfless; they advance the community rather than the individual, and are concerned with morality, fairness, and symmetry."

      "black" ->
        "Black actions are powerful and selfish; ambitious, willing to treat anything and everything as a resource to be spent; willing to sacrifice for gain."

      _ ->
        "Empty actions are mysterious and defy systematising ontologies; they concern magic, metaphysics, the will to overcome and transgress the bounds of reality."
    end
  end

  defp roll_message(nickname, color, roll) do
    case roll do
      {:alethic, stat, outcome, r1, r2} ->
        if outcome == stat do
          "- **#{nickname}** invoked their [redacted] #{color_lookup(color)} gnosis [d#{stat}: (#{r1}, #{r2})] -> ***#{outcome}***! It ✨explodes!"
        else
          "- **#{nickname}** invoked their [redacted] #{color_lookup(color)} gnosis [d#{stat}: (#{r1}, #{r2})] -> ***#{outcome}***."
        end

      {:mundane, stat, outcome} ->
        if outcome == stat do
          "- **#{nickname}** invoked their #{color_lookup(color)} gnosis [d#{stat}] -> ***#{outcome}***! It ✨explodes!"
        else
          "- **#{nickname}** invoked their #{color_lookup(color)} gnosis [d#{stat}] -> ***#{outcome}***."
        end
    end
  end
end
