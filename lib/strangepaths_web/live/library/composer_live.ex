defmodule StrangepathsWeb.LibraryLive.Composer do
  use StrangepathsWeb, :live_view

  import StrangepathsWeb.SceneHelpers, only: [render_post_content: 1, render_post_content: 2]
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
           |> assign(:group_actions, %{})
           |> assign_entries(entries)
           |> assign(:caret_position, length(entries) + 1)
           |> assign(:range_anchor_post_id, nil)
           |> assign(:expanded_scene_id, nil)
           |> assign(:scene_posts_cache, %{})
           |> assign(:filter_query, "")
           |> assign(:is_author, folio.user_id == user.id)
           |> assign(:is_dragon, user.role == :dragon)
           |> assign(
             :editor_typefaces,
             if(user, do: Library.folio_editor_typefaces(user.id), else: [])
           )
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
         |> assign_entries(entries)
         |> assign(:caret_position, position + 1)
         # Set range_anchor_post_id to the newly added post to enable shift-click range selection
         # from the next post. Clicking a different post without holding Shift will overwrite
         # the anchor, allowing the user to start a new range.
         |> assign(:range_anchor_post_id, post_id)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not add post.")}
    end
  end

  def handle_event(
        "add_range",
        %{"from-post-id" => from_str, "to-post-id" => to_str, "scene-id" => scene_id_str},
        socket
      ) do
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

    case Library.create_post_entries_at(socket.assigns.folio, user, range_ids, position) do
      {:ok, _entries} ->
        entries = Library.list_entries(socket.assigns.folio.id)

        {:noreply,
         socket
         |> assign_entries(entries)
         |> assign(:caret_position, position + length(range_ids))
         |> assign(:range_anchor_post_id, nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add range.")}
    end
  end

  def handle_event("set_range_anchor", %{"post-id" => post_id_str}, socket) do
    {:noreply, assign(socket, :range_anchor_post_id, String.to_integer(post_id_str))}
  end

  def handle_event("set_caret", %{"position" => pos_str}, socket) do
    position = String.to_integer(pos_str) |> max(1) |> min(length(socket.assigns.entries) + 1)
    {:noreply, assign(socket, :caret_position, position)}
  end

  def handle_event("toggle_entry_group", %{"entry-id" => id_str}, socket) do
    if socket.assigns.is_author || socket.assigns.is_dragon do
      entry_id = String.to_integer(id_str)

      case find_group_action(socket.assigns.entries, entry_id) do
        {:add, group_id} ->
          entry = Enum.find(socket.assigns.entries, &(&1.id == entry_id))
          Library.update_entry_group(entry, group_id)
          entries = Library.list_entries(socket.assigns.folio.id)
          {:noreply, assign_entries(socket, entries)}

        {:remove, entry} ->
          Library.update_entry_group(entry, nil)
          entries = Library.list_entries(socket.assigns.folio.id)
          {:noreply, assign_entries(socket, entries)}

        :no_op ->
          {:noreply, socket}
      end
    else
      {:noreply, put_flash(socket, :error, "Unauthorized.")}
    end
  end

  def compute_group_actions(entries) do
    Map.new(entries, fn entry ->
      action =
        case find_group_action(entries, entry.id) do
          {:add, _} -> :add
          {:remove, _} -> :remove
          :no_op -> :no_op
        end

      {entry.id, action}
    end)
  end

  defp find_group_action(entries, entry_id) do
    idx = Enum.find_index(entries, &(&1.id == entry_id))
    entry = Enum.at(entries, idx)

    grouped_indices =
      entries
      |> Enum.with_index()
      |> Enum.filter(fn {e, _} -> e.group_id end)
      |> Enum.map(fn {_, i} -> i end)

    cond do
      Enum.empty?(grouped_indices) ->
        {:add, Ecto.UUID.generate()}

      entry.group_id ->
        first = List.first(grouped_indices)
        last = List.last(grouped_indices)
        if idx == first || idx == last, do: {:remove, entry}, else: :no_op

      true ->
        first = List.first(grouped_indices)
        last = List.last(grouped_indices)

        if idx == first - 1 || idx == last + 1 do
          {:add, Enum.find_value(entries, & &1.group_id)}
        else
          :no_op
        end
    end
  end

  def handle_event("ungroup_all", _params, socket) do
    if socket.assigns.is_author || socket.assigns.is_dragon do
      socket.assigns.entries
      |> Enum.filter(& &1.group_id)
      |> Enum.each(&Library.update_entry_group(&1, nil))

      entries = Library.list_entries(socket.assigns.folio.id)
      {:noreply, assign_entries(socket, entries)}
    else
      {:noreply, put_flash(socket, :error, "Unauthorized.")}
    end
  end

  def handle_event(
        "shift_select_post",
        %{"post-id" => post_id_str, "scene-id" => scene_id_str},
        socket
      ) do
    case socket.assigns.range_anchor_post_id do
      nil ->
        # No anchor set — treat as regular add
        handle_event("add_post", %{"post-id" => post_id_str}, socket)

      anchor_id ->
        # Has anchor — add the range
        handle_event(
          "add_range",
          %{
            "from-post-id" => to_string(anchor_id),
            "to-post-id" => post_id_str,
            "scene-id" => scene_id_str
          },
          socket
        )
    end
  end

  # --- Note insertion ---

  def handle_event("add_note", %{"note" => attrs, "position" => pos_str} = params, socket) do
    user = socket.assigns.current_user
    position = String.to_integer(pos_str)
    typefaces = Library.folio_editor_typefaces(user.id)
    typeface_id = get_in(params, ["marginalia", "typeface_id"])

    tf =
      if typeface_id && length(typefaces) > 1 do
        Enum.find(typefaces, &(&1.id == typeface_id)) || List.first(typefaces)
      else
        List.first(typefaces)
      end

    note_attrs =
      attrs
      |> Map.put("name", (tf && tf.name) || "")
      |> Map.put("font", (tf && tf.font) || "")
      |> Map.put("color", (tf && tf.color) || "")

    case Library.create_note_entry(socket.assigns.folio, user, note_attrs, position) do
      {:ok, _} ->
        entries = Library.list_entries(socket.assigns.folio.id)
        {:noreply, socket |> assign_entries(entries) |> assign(:caret_position, position + 1)}

      {:error, e} ->
        {:noreply, put_flash(socket, :error, "Could not add note: #{inspect(e)}")}
    end
  end

  # --- Entry management (author/dragon only) ---

  def handle_event("delete_entry", %{"entry-id" => entry_id_str}, socket) do
    if socket.assigns.is_author || socket.assigns.is_dragon do
      entry_id = String.to_integer(entry_id_str)
      entry_index = Enum.find_index(socket.assigns.entries, &(&1.id == entry_id))

      if entry_index != nil do
        entry = Enum.at(socket.assigns.entries, entry_index)
        Library.delete_entry(entry)
        entries = Library.list_entries(socket.assigns.folio.id)

        deleted_position = entry_index + 1
        caret = socket.assigns.caret_position
        new_caret = if caret > deleted_position, do: caret - 1, else: caret

        {:noreply, socket |> assign_entries(entries) |> assign(:caret_position, new_caret)}
      else
        {:noreply, socket}
      end
    else
      {:noreply, put_flash(socket, :error, "Unauthorized.")}
    end
  end

  def handle_event("reorder_entries", %{"ids" => ids_str}, socket) do
    if socket.assigns.is_author || socket.assigns.is_dragon do
      ids = String.split(ids_str, ",") |> Enum.map(&String.to_integer/1)
      Library.reorder_entries(socket.assigns.folio.id, ids)
      entries = Library.list_entries(socket.assigns.folio.id)
      {:noreply, socket |> assign_entries(entries) |> assign(:caret_position, length(entries) + 1)}
    else
      {:noreply, put_flash(socket, :error, "Unauthorized.")}
    end
  end

  # --- Private helpers ---

  defp load_scenes(socket, user) do
    all_scenes = Scenes.list_scenes_for_composer(user.id)

    socket
    |> assign(:all_scenes, all_scenes)
    |> assign(:visible_scenes, filter_scenes(all_scenes, socket.assigns.filter_query))
  end

  defp recompute_visible_scenes(socket) do
    assign(socket, :visible_scenes, filter_scenes(socket.assigns.all_scenes, socket.assigns.filter_query))
  end

  defp filter_scenes(scenes, "") do
    scenes
  end

  defp filter_scenes(scenes, query) do
    q = String.downcase(query)

    Enum.filter(scenes, fn scene ->
      String.contains?(String.downcase(scene.name), q) or
        Enum.any?(scene.tags, &String.contains?(String.downcase(&1), q))
    end)
  end

  defp assign_entries(socket, entries) do
    socket
    |> assign(:entries, entries)
    |> assign(:group_actions, compute_group_actions(entries))
  end

  defp load_scene_posts(socket, scene_id) do
    posts = Scenes.list_posts_for_archive(scene_id)
    update(socket, :scene_posts_cache, &Map.put(&1, scene_id, posts))
  end
end
