defmodule StrangepathsWeb.Scenes.Archives do
  use StrangepathsWeb, :live_view

  import StrangepathsWeb.MusicBroadcast

  alias Strangepaths.Scenes

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
       |> assign(:selected_scene, nil)
       |> assign(:selected_week, nil)
       |> assign(:posts, [])
       |> assign(:viewing_elsewhere, false)}
    else
      {:ok,
       socket
       |> put_flash(:error, "You must be logged in to access archives")
       |> redirect(to: "/")}
    end
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

  defp handle_archive_event("view_scene", %{"scene_id" => scene_id_str}, socket) do
    scene_id = String.to_integer(scene_id_str)
    scene = Scenes.get_scene(scene_id)

    if scene && Scenes.can_view_scene?(scene, socket.assigns.current_user) do
      # Load all posts for the archived scene
      posts = Scenes.list_posts(scene.id, 1000)

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

  defp handle_archive_event(event, params, socket) do
    IO.puts("unhandled archive event #{event} with params #{inspect(params)}")
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
