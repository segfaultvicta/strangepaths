defmodule StrangepathsWeb.LibraryLive.Composer do
  use StrangepathsWeb, :live_view

  import StrangepathsWeb.SceneHelpers, only: [render_post_content: 1]
  import StrangepathsWeb.LibraryHelpers, only: [render_library_content: 1]

  alias Strangepaths.{Library, Scenes}

  @impl true
  def mount(%{"slug" => slug}, session, socket) do
    socket = assign_defaults(session, socket)
    user = socket.assigns.current_user

    case Library.get_folio_by_slug(slug) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Folio not found.")
         |> push_redirect(to: "/library")}

      folio ->
        if user && Library.folio_editor?(user.id) do
          entries = Library.list_entries(folio.id)

          {:ok,
           socket
           |> assign(:page_title, "Composing: #{folio.title}")
           |> assign(:folio, folio)
           |> assign(:entries, entries)
           |> assign(:caret_position, length(entries) + 1)
           |> assign(:range_anchor_post_id, nil)
           |> assign(:expanded_scene_id, nil)
           |> assign(:scene_posts_cache, %{})
           |> assign(:filter_query, "")
           |> assign(:my_scenes_only, false)
           |> assign(:is_author, folio.user_id == user.id)
           |> assign(:is_dragon, user.role == :dragon)
           |> load_scenes(user)}
        else
          {:ok,
           socket
           |> put_flash(:error, "You must be a folio editor to compose.")
           |> push_redirect(to: "/library/#{slug}")}
        end
    end
  end

  @impl true
  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  # --- Scene browser events ---

  @impl true
  def handle_event("set_filter", %{"q" => q}, socket) do
    {:noreply, socket |> assign(:filter_query, q) |> recompute_visible_scenes()}
  end

  def handle_event("toggle_my_scenes", _params, socket) do
    {:noreply,
     socket
     |> update(:my_scenes_only, &(!&1))
     |> recompute_visible_scenes()}
  end

  def handle_event("expand_scene", %{"scene-id" => scene_id_str}, socket) do
    scene_id = String.to_integer(scene_id_str)

    if socket.assigns.expanded_scene_id == scene_id do
      {:noreply, assign(socket, :expanded_scene_id, nil)}
    else
      socket = assign(socket, :expanded_scene_id, scene_id)
      socket = load_scene_posts(socket, scene_id)
      {:noreply, socket}
    end
  end

  # --- Entry addition events ---

  def handle_event("add_post", %{"post-id" => post_id_str}, socket) do
    user = socket.assigns.current_user
    post_id = String.to_integer(post_id_str)
    position = socket.assigns.caret_position

    case Library.create_post_entry(socket.assigns.folio, user, post_id, position) do
      {:ok, _entry} ->
        entries = Library.list_entries(socket.assigns.folio.id)
        {:noreply,
         socket
         |> assign(:entries, entries)
         |> assign(:caret_position, position + 1)
         |> assign(:range_anchor_post_id, post_id)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not add post.")}
    end
  end

  def handle_event("add_range", %{"from-post-id" => from_str, "to-post-id" => to_str, "scene-id" => scene_id_str}, socket) do
    user = socket.assigns.current_user
    scene_id = String.to_integer(scene_id_str)
    from_id = String.to_integer(from_str)
    to_id = String.to_integer(to_str)

    posts = Map.get(socket.assigns.scene_posts_cache, scene_id, [])
    post_ids = posts |> Enum.map(& &1.id)

    from_idx = Enum.find_index(post_ids, &(&1 == from_id)) || 0
    to_idx = Enum.find_index(post_ids, &(&1 == to_id)) || 0

    {start_idx, end_idx} = if from_idx <= to_idx, do: {from_idx, to_idx}, else: {to_idx, from_idx}
    range_ids = Enum.slice(post_ids, start_idx..end_idx)

    position = socket.assigns.caret_position

    range_ids
    |> Enum.with_index(position)
    |> Enum.each(fn {post_id, pos} ->
      Library.create_post_entry(socket.assigns.folio, user, post_id, pos)
    end)

    entries = Library.list_entries(socket.assigns.folio.id)

    {:noreply,
     socket
     |> assign(:entries, entries)
     |> assign(:caret_position, position + length(range_ids))}
  end

  def handle_event("set_range_anchor", %{"post-id" => post_id_str}, socket) do
    {:noreply, assign(socket, :range_anchor_post_id, String.to_integer(post_id_str))}
  end

  def handle_event("set_caret", %{"position" => pos_str}, socket) do
    {:noreply, assign(socket, :caret_position, String.to_integer(pos_str))}
  end

  # --- Note insertion ---

  def handle_event("add_note", %{"note" => attrs, "position" => pos_str}, socket) do
    user = socket.assigns.current_user
    position = String.to_integer(pos_str)
    typefaces = Library.folio_editor_typefaces(user.id)
    tf = List.first(typefaces)

    note_attrs =
      attrs
      |> Map.put("name", tf && tf.name || "")
      |> Map.put("font", tf && tf.font || "")
      |> Map.put("color", tf && tf.color || "")

    case Library.create_note_entry(socket.assigns.folio, user, note_attrs, position) do
      {:ok, _} ->
        entries = Library.list_entries(socket.assigns.folio.id)
        {:noreply, socket |> assign(:entries, entries) |> assign(:caret_position, position + 1)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not add note.")}
    end
  end

  # --- Entry management (author/dragon only) ---

  def handle_event("delete_entry", %{"entry-id" => entry_id_str}, socket) do
    if socket.assigns.is_author || socket.assigns.is_dragon do
      entry_id = String.to_integer(entry_id_str)
      entry = Enum.find(socket.assigns.entries, &(&1.id == entry_id))

      if entry do
        Library.delete_entry(entry)
        entries = Library.list_entries(socket.assigns.folio.id)
        {:noreply, assign(socket, :entries, entries)}
      else
        {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("reorder_entries", %{"ids" => ids_str}, socket) do
    if socket.assigns.is_author || socket.assigns.is_dragon do
      ids = String.split(ids_str, ",") |> Enum.map(&String.to_integer/1)
      Library.reorder_entries(socket.assigns.folio.id, ids)
      entries = Library.list_entries(socket.assigns.folio.id)
      {:noreply, assign(socket, :entries, entries)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("group_entries", %{"ids" => ids_str}, socket) do
    if socket.assigns.is_author || socket.assigns.is_dragon do
      ids = String.split(ids_str, ",") |> Enum.map(&String.to_integer/1)
      group_id = Ecto.UUID.generate()
      # Update all selected entries to share this group_id
      Enum.each(ids, fn id ->
        entry = Enum.find(socket.assigns.entries, &(&1.id == id))
        if entry, do: Library.update_entry_group(entry, group_id)
      end)
      entries = Library.list_entries(socket.assigns.folio.id)
      {:noreply, assign(socket, :entries, entries)}
    else
      {:noreply, socket}
    end
  end

  # --- Private helpers ---

  defp load_scenes(socket, user) do
    all_scenes =
      if socket.assigns.my_scenes_only do
        Scenes.list_scenes_with_user_posts(user.id)
      else
        Scenes.list_scenes_for_composer()
      end

    my_scene_ids =
      if user, do: MapSet.new(Scenes.list_scenes_with_user_posts(user.id), & &1.id), else: MapSet.new()

    socket
    |> assign(:all_scenes, all_scenes)
    |> assign(:my_scene_ids, my_scene_ids)
    |> assign(:visible_scenes, filter_scenes(all_scenes, socket.assigns.filter_query))
  end

  defp recompute_visible_scenes(socket) do
    scenes = if socket.assigns.my_scenes_only do
      Enum.filter(socket.assigns.all_scenes, &MapSet.member?(socket.assigns.my_scene_ids, &1.id))
    else
      socket.assigns.all_scenes
    end
    assign(socket, :visible_scenes, filter_scenes(scenes, socket.assigns.filter_query))
  end

  defp filter_scenes(scenes, "") do
    scenes
  end

  defp filter_scenes(scenes, query) do
    q = String.downcase(query)
    Enum.filter(scenes, fn scene ->
      # full cast session scenes are always visible
      "full cast session" in scene.tags or
        String.contains?(String.downcase(scene.name), q) or
        Enum.any?(scene.tags, &String.contains?(&1, q))
    end)
  end

  defp load_scene_posts(socket, scene_id) do
    posts = Scenes.list_posts_for_archive(scene_id)
    update(socket, :scene_posts_cache, &Map.put(&1, scene_id, posts))
  end
end
