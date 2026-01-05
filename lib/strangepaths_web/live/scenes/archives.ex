defmodule StrangepathsWeb.Scenes.Archives do
  use StrangepathsWeb, :live_view

  import StrangepathsWeb.MusicBroadcast

  alias Strangepaths.Scenes
  alias Strangepaths.Site

  @impl true
  def mount(_params, session, socket) do
    socket = assign_defaults(session, socket)
    subscribe_to_music(socket)

    if socket.assigns.current_user do
      # Load archived scenes
      archived_scenes = Scenes.list_archived_scenes(socket.assigns.current_user)

      # Check if there's an Elsewhere scene to show weekly archives
      elsewhere_scene = Scenes.get_elsewhere_scene()

      elsewhere_weeks =
        if elsewhere_scene do
          Scenes.group_elsewhere_posts_by_week(elsewhere_scene.id)
        else
          %{}
        end

      {:ok,
       socket
       |> assign(:archived_scenes, archived_scenes)
       |> assign(:elsewhere_scene, elsewhere_scene)
       |> assign(:elsewhere_weeks, elsewhere_weeks)
       |> assign(:page_title, "Sanctuary - Archive")
       |> assign(:selected_scene, nil)
       |> assign(:selected_week, nil)
       |> assign(:posts, [])
       |> assign(:viewing_elsewhere, false)
       |> assign(:editing_scene_id, nil)
       |> assign(:editing_scene_name, "")
       |> assign(:search_query, "")
       |> assign(:search_results, nil)
       |> assign(:searching, false)
       |> assign(:show_filters, false)
       |> assign(:filter_my_scenes, false)
       |> assign(:filter_hide_elsewhere, false)
       |> assign(:filter_hide_system, true)
       |> assign(:filter_author, ""), temporary_assigns: [posts: []]}
    else
      {:ok,
       socket
       |> put_flash(:error, "You must be logged in to access archives")
       |> redirect(to: "/")}
    end
  end

  @impl true
  def handle_params(%{"slug" => slug}, _uri, socket) do
    scene = Scenes.get_scene_by_slug(slug)

    if scene && Scenes.can_view_scene?(scene, socket.assigns.current_user) do
      # Load all posts for the archived scene
      posts = Scenes.list_posts_for_archive(scene.id)

      {:noreply,
       socket
       |> assign(:selected_scene, scene)
       |> assign(:posts, posts)
       |> assign(:viewing_elsewhere, false)}
    else
      {:noreply,
       socket
       |> put_flash(:error, "Scene not found or you don't have permission to view it")
       |> push_patch(to: "/scenes/archives")}
    end
  end

  def handle_params(%{"week" => week_str}, _uri, socket) do
    handle_archive_event("view_elsewhere_week", %{"week" => week_str}, socket)
  end

  def handle_params(%{}, uri, socket) do
    path = URI.parse(uri).path

    if path == "/scenes/archives" do
      {:noreply,
       socket
       |> assign(:selected_scene, nil)
       |> assign(:selected_week, nil)
       |> assign(:posts, [])
       |> assign(:viewing_elsewhere, false)}
    else
      {:noreply, socket}
    end
  end

  def handle_params(params, uri, socket) do
    IO.puts("unhandled params in archive")
    IO.inspect(params)
    IO.inspect(uri)
    {:noreply, socket}
  end

  @impl true
  def handle_event(event, params, socket) do
    case forward_music_client_event(event, params, socket) do
      :not_music_event ->
        handle_archive_event(event, params, socket)

      result ->
        result
    end
  end

  defp handle_archive_event("search", %{"search_query" => query}, socket) do
    query = String.trim(query)

    if String.length(query) < 3 do
      {:noreply,
       socket
       |> assign(:search_query, query)
       |> assign(:search_results, nil)
       |> assign(:searching, false)}
    else
      socket = assign(socket, :searching, true)

      # Perform search
      user_id = socket.assigns.current_user.id
      my_scenes_filter = socket.assigns.filter_my_scenes
      hide_elsewhere_filter = socket.assigns.filter_hide_elsewhere
      hide_system_filter = socket.assigns.filter_hide_system
      author_filter = socket.assigns.filter_author

      elsewhere_scene_id =
        if socket.assigns.elsewhere_scene, do: socket.assigns.elsewhere_scene.id, else: nil

      scene_results =
        Scenes.search_archived_scenes(
          query,
          user_id,
          my_scenes_filter,
          hide_elsewhere_filter,
          elsewhere_scene_id,
          author_filter
        )

      post_results =
        Scenes.search_archived_posts(
          query,
          user_id,
          my_scenes_filter,
          hide_elsewhere_filter,
          hide_system_filter,
          elsewhere_scene_id,
          author_filter
        )

      codex_results = Site.search_codex_pages(query, user_id)

      # Combine scene and post results, removing duplicates
      scene_ids_from_names = MapSet.new(scene_results, fn result -> result.scene_id end)
      scene_ids_from_posts = MapSet.new(post_results, fn result -> result.scene_id end)
      all_scene_ids = MapSet.union(scene_ids_from_names, scene_ids_from_posts)

      # Build unified results with context
      unified_results =
        all_scene_ids
        |> Enum.map(fn scene_id ->
          scene_result = Enum.find(scene_results, fn r -> r.scene_id == scene_id end)
          post_result = Enum.find(post_results, fn r -> r.scene_id == scene_id end)

          %{
            scene_id: scene_id,
            scene_name:
              (scene_result && scene_result.scene_name) || (post_result && post_result.scene_name),
            scene_slug:
              (scene_result && scene_result.scene_slug) || (post_result && post_result.scene_slug),
            matched_in_name: !!scene_result,
            post_snippets: (post_result && post_result.snippets) || [],
            is_elsewhere: (post_result && post_result.is_elsewhere) || false,
            week_date: (post_result && post_result.week_date) || nil
          }
        end)
        |> Enum.sort_by(fn r -> r.scene_name end)

      {:noreply,
       socket
       |> assign(:search_query, query)
       |> assign(:search_results, %{scenes: unified_results, codex: codex_results})
       |> assign(:searching, false)}
    end
  end

  defp handle_archive_event("toggle_filters", _params, socket) do
    {:noreply, assign(socket, :show_filters, !socket.assigns.show_filters)}
  end

  defp handle_archive_event("toggle_my_scenes", _params, socket) do
    new_value = !socket.assigns.filter_my_scenes
    socket = assign(socket, :filter_my_scenes, new_value)

    # Re-run search if there's an active query
    if String.length(socket.assigns.search_query) >= 3 do
      handle_archive_event("search", %{"search_query" => socket.assigns.search_query}, socket)
    else
      {:noreply, socket}
    end
  end

  defp handle_archive_event("toggle_hide_elsewhere", _params, socket) do
    new_value = !socket.assigns.filter_hide_elsewhere
    socket = assign(socket, :filter_hide_elsewhere, new_value)

    # Re-run search if there's an active query
    if String.length(socket.assigns.search_query) >= 3 do
      handle_archive_event("search", %{"search_query" => socket.assigns.search_query}, socket)
    else
      {:noreply, socket}
    end
  end

  defp handle_archive_event("toggle_hide_system", _params, socket) do
    new_value = !socket.assigns.filter_hide_system
    socket = assign(socket, :filter_hide_system, new_value)

    # Re-run search if there's an active query
    if String.length(socket.assigns.search_query) >= 3 do
      handle_archive_event("search", %{"search_query" => socket.assigns.search_query}, socket)
    else
      {:noreply, socket}
    end
  end

  defp handle_archive_event("clear_search", _params, socket) do
    {:noreply,
     socket
     |> assign(:search_query, "")
     |> assign(:search_results, nil)
     |> assign(:searching, false)}
  end

  defp handle_archive_event("update_author_filter", %{"filter_author" => author}, socket) do
    socket = assign(socket, :filter_author, String.trim(author))

    # Re-run search if there's an active query
    if String.length(socket.assigns.search_query) >= 3 do
      handle_archive_event("search", %{"search_query" => socket.assigns.search_query}, socket)
    else
      {:noreply, socket}
    end
  end

  defp handle_archive_event("unlock_scene", %{"scene-id" => scene_id_str}, socket) do
    # Only dragons can unlock scenes
    if socket.assigns.current_user.role == :dragon do
      scene_id = String.to_integer(scene_id_str)
      scene = Scenes.get_scene(scene_id)

      if scene && scene.status == :archived do
        case Scenes.unlock_archived_scene(scene) do
          {:ok, updated_scene} ->
            {:noreply,
             socket
             |> assign(:selected_scene, updated_scene)
             |> put_flash(:info, "Scene unlocked! It is now publicly viewable.")}

          {:error, _changeset} ->
            {:noreply,
             socket
             |> put_flash(:error, "Failed to unlock scene.")}
        end
      else
        {:noreply,
         socket
         |> put_flash(:error, "Scene not found or not archived.")}
      end
    else
      {:noreply,
       socket
       |> put_flash(:error, "You do not have permission to unlock scenes.")}
    end
  end

  defp handle_archive_event("view_scene", %{"scene_id" => scene_id_str}, socket) do
    scene_id = String.to_integer(scene_id_str)
    scene = Scenes.get_scene(scene_id)

    if scene && Scenes.can_view_scene?(scene, socket.assigns.current_user) do
      # Load all posts for the archived scene
      posts = Scenes.list_posts_for_archive(scene.id)

      {:noreply,
       socket
       |> assign(:selected_scene, scene)
       |> assign(:posts, posts)
       |> assign(:viewing_elsewhere, false)}
    else
      {:noreply, put_flash(socket, :error, "You don't have permission to view this scene")}
    end
  end

  defp handle_archive_event("view_elsewhere_week", %{"week" => week_str}, socket) do
    week_date = Date.from_iso8601!(week_str)

    if socket.assigns.elsewhere_weeks[week_date] do
      posts = socket.assigns.elsewhere_weeks[week_date]

      {:noreply,
       socket
       |> assign(:selected_week, week_date)
       |> assign(:posts, posts)
       |> assign(:viewing_elsewhere, true)
       |> assign(:selected_scene, nil)}
    else
      {:noreply, put_flash(socket, :error, "Week not found")}
    end
  end

  defp handle_archive_event("back_to_list", _params, socket) do
    {:noreply,
     socket
     |> assign(:selected_scene, nil)
     |> assign(:selected_week, nil)
     |> assign(:posts, [])
     |> assign(:viewing_elsewhere, false)}
  end

  defp handle_archive_event("edit_archived_scene", %{"scene_id" => scene_id_str}, socket) do
    scene_id = String.to_integer(scene_id_str)
    scene = Scenes.get_scene(scene_id)

    if socket.assigns.role == :dragon && scene do
      {:noreply,
       socket
       |> assign(:editing_scene_id, scene_id)
       |> assign(:editing_scene_name, scene.name)}
    else
      {:noreply, put_flash(socket, :error, "You don't have permission to edit this scene")}
    end
  end

  defp handle_archive_event("update_editing_scene_name", %{"scene_name" => name}, socket) do
    {:noreply, assign(socket, :editing_scene_name, name)}
  end

  defp handle_archive_event("cancel_edit_archived_scene", _params, socket) do
    {:noreply,
     socket
     |> assign(:editing_scene_id, nil)
     |> assign(:editing_scene_name, "")}
  end

  defp handle_archive_event("save_archived_scene_edit", params, socket) do
    scene_id = String.to_integer(params["scene_id"] || to_string(socket.assigns.editing_scene_id))
    scene = Scenes.get_scene(scene_id)
    new_name = socket.assigns.editing_scene_name

    if socket.assigns.role == :dragon && scene && new_name != "" do
      case Scenes.update_archived_scene_name(scene, new_name) do
        {:ok, _updated_scene} ->
          # Reload archived scenes
          archived_scenes = Scenes.list_archived_scenes(socket.assigns.current_user)

          {:noreply,
           socket
           |> assign(:archived_scenes, archived_scenes)
           |> assign(:editing_scene_id, nil)
           |> assign(:editing_scene_name, "")
           |> put_flash(:info, "Scene name updated successfully")}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to update scene name")}
      end
    else
      {:noreply, put_flash(socket, :error, "Invalid scene or name")}
    end
  end

  defp handle_archive_event(_event, _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info(msg, socket) do
    case forward_music_event(msg, socket) do
      :not_music_event ->
        {:noreply, socket}

      result ->
        result
    end
  end
end
