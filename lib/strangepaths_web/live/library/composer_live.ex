defmodule StrangepathsWeb.LibraryLive.Composer do
  use StrangepathsWeb, :live_view

  require Logger

  import StrangepathsWeb.SceneHelpers, only: [render_post_content: 2]
  import StrangepathsWeb.LibraryHelpers, only: [render_library_content: 1]

  alias Strangepaths.{Library, Scenes}

  @entries_lock_timeout_ms Library.entries_lock_timeout_seconds() * 1_000

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
          lock_result =
            if connected?(socket),
              do: Library.claim_entries_lock(folio.id, user.id),
              else: :ok

          case lock_result do
            {:error, :locked} ->
              {:ok,
               socket
               |> put_flash(:error, "Another editor is currently editing this folio's entries.")
               |> push_redirect(to: "/library/#{folio.slug}")}

            :ok ->
              entries = Library.list_entries(folio.id)

              timer_ref =
                if connected?(socket),
                  do: Process.send_after(self(), :entries_lock_timeout, @entries_lock_timeout_ms),
                  else: nil

              {:ok,
               socket
               |> assign(:page_title, "Composing: #{folio.title}")
               |> assign(:folio, folio)
               |> assign(:group_actions, %{})
               |> assign_entries(entries)
               |> assign(:caret_position, length(entries) + 1)
               |> assign(:pending_delete_entry_id, nil)
               |> assign(:editing_note_entry_id, nil)
               |> assign(:range_anchor_post_id, nil)
               |> assign(:expanded_scene_id, nil)
               |> assign(:scene_posts_cache, %{})
               |> assign(:filter_query, "")
               |> assign(:is_author, folio.user_id == user.id)
               |> assign(:is_dragon, user.role == :dragon)
               |> assign(:entries_lock_timer_ref, timer_ref)
               |> assign(:session_ops, [])
               |> assign(
                 :editor_typefaces,
                 if(user, do: Library.folio_editor_typefaces(user.id), else: [])
               )
               |> load_scenes(user)}
          end
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

  def handle_event("noop", _params, socket), do: {:noreply, socket}

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
    rank = socket.assigns.caret_position
    position = rank_to_db_position(socket.assigns.entries, rank)

    case Library.create_post_entry(socket.assigns.folio, user, post_id, position) do
      {:ok, _entry} ->
        old_ids = MapSet.new(socket.assigns.entries, & &1.id)
        entries = Library.list_entries(socket.assigns.folio.id)
        new_entry = Enum.find(entries, &(!MapSet.member?(old_ids, &1.id)))
        op = %{op: :added_post, label: post_entry_label(new_entry)}

        {:noreply,
         socket
         |> assign_entries(entries)
         |> assign(:caret_position, rank + 1)
         |> update(:session_ops, &(&1 ++ [op]))
         |> renew_lock()}

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

    rank = socket.assigns.caret_position
    position = rank_to_db_position(socket.assigns.entries, rank)

    case Library.create_post_entries_at(socket.assigns.folio, user, range_ids, position) do
      {:ok, _entries} ->
        old_ids = MapSet.new(socket.assigns.entries, & &1.id)
        entries = Library.list_entries(socket.assigns.folio.id)
        new_ops = entries
          |> Enum.filter(&(!MapSet.member?(old_ids, &1.id)))
          |> Enum.map(&%{op: :added_post, label: post_entry_label(&1)})

        {:noreply,
         socket
         |> assign_entries(entries)
         |> assign(:caret_position, rank + length(range_ids))
         |> assign(:range_anchor_post_id, nil)
         |> update(:session_ops, &(&1 ++ new_ops))
         |> renew_lock()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add range.")}
    end
  end

  def handle_event("set_range_anchor", %{"post-id" => post_id_str}, socket) do
    post_id = String.to_integer(post_id_str)
    new_anchor = if socket.assigns.range_anchor_post_id == post_id, do: nil, else: post_id
    {:noreply, assign(socket, :range_anchor_post_id, new_anchor)}
  end

  def handle_event("set_caret", %{"position" => pos_str}, socket) do
    position = String.to_integer(pos_str) |> max(1) |> min(length(socket.assigns.entries) + 1)
    {:noreply, assign(socket, :caret_position, position)}
  end

  def handle_event("toggle_entry_group", %{"entry-id" => id_str}, socket) do
    entry_id = String.to_integer(id_str)

    case find_group_action(socket.assigns.entries, entry_id) do
      {:add, group_id} ->
        entry = Enum.find(socket.assigns.entries, &(&1.id == entry_id))
        Library.update_entry_group(entry, group_id)
        entries = Library.list_entries(socket.assigns.folio.id)
        {:noreply, socket |> assign_entries(entries) |> renew_lock()}

      {:remove, entry} ->
        Library.update_entry_group(entry, nil)
        entries = Library.list_entries(socket.assigns.folio.id)
        {:noreply, socket |> assign_entries(entries) |> renew_lock()}

      :no_op ->
        {:noreply, socket}
    end
  end

  def handle_event("ungroup_all", _params, socket) do
    socket.assigns.entries
    |> Enum.filter(& &1.group_id)
    |> Enum.each(&Library.update_entry_group(&1, nil))

    entries = Library.list_entries(socket.assigns.folio.id)
    {:noreply, socket |> assign_entries(entries) |> renew_lock()}
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
    rank = String.to_integer(pos_str)
    position = rank_to_db_position(socket.assigns.entries, rank)
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
        op = %{op: :added_note, content: String.slice(attrs["content"] || "", 0, 60)}

        {:noreply,
         socket
         |> assign_entries(entries)
         |> assign(:caret_position, rank + 1)
         |> update(:session_ops, &(&1 ++ [op]))
         |> renew_lock()}

      {:error, e} ->
        {:noreply, put_flash(socket, :error, "Could not add note: #{inspect(e)}")}
    end
  end

  # --- Entry management (author/dragon only) ---

  def handle_event("delete_entry", %{"entry-id" => entry_id_str}, socket) do
    entry_id = String.to_integer(entry_id_str)
    entry_index = Enum.find_index(socket.assigns.entries, &(&1.id == entry_id))

    if entry_index != nil do
      entry = Enum.at(socket.assigns.entries, entry_index)

      if Library.entry_has_marginalia?(entry.id) do
        {:noreply, assign(socket, :pending_delete_entry_id, entry.id)}
      else
        do_delete_entry(socket, entry, entry_index)
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("confirm_delete_entry", %{"entry-id" => entry_id_str}, socket) do
    entry_id = String.to_integer(entry_id_str)
    entry_index = Enum.find_index(socket.assigns.entries, &(&1.id == entry_id))

    if entry_index != nil do
      entry = Enum.at(socket.assigns.entries, entry_index)
      do_delete_entry(socket, entry, entry_index)
    else
      {:noreply, assign(socket, :pending_delete_entry_id, nil)}
    end
  end

  def handle_event("cancel_delete_entry", _params, socket) do
    {:noreply, assign(socket, :pending_delete_entry_id, nil)}
  end

  defp do_delete_entry(socket, entry, entry_index) do
    op = deleted_entry_op(entry)
    Library.delete_entry(entry, socket.assigns.current_user.id)
    entries = Library.list_entries(socket.assigns.folio.id)

    deleted_position = entry_index + 1
    caret = socket.assigns.caret_position
    new_caret = if caret > deleted_position, do: caret - 1, else: caret

    {:noreply,
     socket
     |> assign(:pending_delete_entry_id, nil)
     |> assign_entries(entries)
     |> assign(:caret_position, new_caret)
     |> update(:session_ops, &(&1 ++ [op]))
     |> renew_lock()}
  end

  def handle_event("start_edit_note", %{"entry-id" => entry_id_str}, socket) do
    entry_id = String.to_integer(entry_id_str)
    user = socket.assigns.current_user

    entry = Enum.find(socket.assigns.entries, &(&1.id == entry_id && &1.kind == :note))

    if entry && user do
      {:noreply, assign(socket, :editing_note_entry_id, entry_id)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("cancel_edit_note", _params, socket) do
    {:noreply, assign(socket, :editing_note_entry_id, nil)}
  end

  def handle_event("save_note_edit", %{"entry-id" => entry_id_str, "note" => %{"content" => content}}, socket) do
    entry_id = String.to_integer(entry_id_str)
    user = socket.assigns.current_user

    entry = Enum.find(socket.assigns.entries, &(&1.id == entry_id && &1.kind == :note))

    cond do
      is_nil(user) || is_nil(entry) ->
        {:noreply, put_flash(socket, :error, "Unauthorized.")}

      true ->
        case Library.update_note_entry(entry, %{"content" => content}, user.id) do
          {:ok, _} ->
            entries = Library.list_entries(socket.assigns.folio.id)
            op = %{op: :edited_note, content: String.slice(content, 0, 60)}

            {:noreply,
             socket
             |> assign(:editing_note_entry_id, nil)
             |> assign_entries(entries)
             |> update(:session_ops, &(&1 ++ [op]))
             |> renew_lock()}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Could not save note.")}
        end
    end
  end

  def handle_event("reorder_entries", %{"ids" => ids_str}, socket) do
    ids = String.split(ids_str, ",") |> Enum.map(&String.to_integer/1)
    Library.reorder_entries(socket.assigns.folio.id, ids, socket.assigns.current_user.id)
    entries = Library.list_entries(socket.assigns.folio.id)

    {:noreply,
     socket
     |> assign_entries(entries)
     |> assign(:caret_position, length(entries) + 1)
     |> update(:session_ops, fn ops ->
       if Enum.any?(ops, &(&1.op == :reordered)), do: ops, else: ops ++ [%{op: :reordered}]
     end)
     |> renew_lock()}
  end

  @impl true
  def handle_event("keepalive", _params, socket) do
    {:noreply, renew_lock(socket)}
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

  @impl true
  def handle_info(:entries_lock_timeout, socket) do
    flush_session_edit(socket, :timeout)
    Library.release_entries_lock(socket.assigns.folio.id)

    {:noreply,
     socket
     |> assign(:entries_lock_timer_ref, nil)
     |> put_flash(:warning, "Editing session timed out. Please re-open the composer to continue.")
     |> push_redirect(to: "/library/#{socket.assigns.folio.slug}")}
  end

  @impl true
  def terminate(reason, socket) do
    folio_id = socket.assigns[:folio] && socket.assigns.folio.id
    ops_count = length(socket.assigns[:session_ops] || [])

    Logger.info(
      "[FolioFlush] terminate folio=#{inspect(folio_id)} ops=#{ops_count} reason=#{inspect(reason)}"
    )

    if socket.assigns[:folio] do
      flush_session_edit(socket, :terminate)
      Library.release_entries_lock(socket.assigns.folio.id)
    end

    :ok
  end

  # --- Private helpers ---

  defp post_entry_label(nil), do: "post #unknown"
  defp post_entry_label(%{scene_post: nil}), do: "post #unknown"
  defp post_entry_label(%{scene_post: post}) do
    author = post.narrative_author_name || post.author_nickname || (post.user && post.user.nickname) || "unknown"
    scene  = (post.scene && post.scene.name) || "unknown scene"
    snippet = String.slice(post.content_stripped || "", 0, 80)
    "post by #{author} in #{scene} (#{snippet})"
  end
  defp post_entry_label(_), do: "post #unknown"

  defp deleted_entry_op(%{kind: :post_ref, scene_post: nil}) do
    %{op: :deleted_post, label: "post #unknown"}
  end
  defp deleted_entry_op(%{kind: :post_ref, scene_post: post}) do
    author = post.narrative_author_name || post.author_nickname || (post.user && post.user.nickname) || "unknown"
    scene  = (post.scene && post.scene.name) || "unknown scene"
    snippet = String.slice(post.content_stripped || "", 0, 80)
    %{op: :deleted_post, label: "post by #{author} in #{scene} (#{snippet})"}
  end
  defp deleted_entry_op(%{kind: :note, content: content}) do
    %{op: :deleted_note, content: String.slice(content || "", 0, 60)}
  end

  defp flush_session_edit(socket, path) do
    folio_id = socket.assigns[:folio] && socket.assigns.folio.id
    user_id = socket.assigns[:current_user] && socket.assigns.current_user.id
    ops = socket.assigns[:session_ops] || []

    cond do
      ops == [] ->
        Logger.info(
          "[FolioFlush] flush path=#{path} folio=#{inspect(folio_id)} user=#{inspect(user_id)} ops=0 result=noop"
        )
        :noop

      is_nil(folio_id) or is_nil(user_id) ->
        Logger.error(
          "[FolioFlush] flush path=#{path} folio=#{inspect(folio_id)} user=#{inspect(user_id)} ops=#{length(ops)} result=missing_context"
        )
        :error

      true ->
        try do
          summary = build_count_summary(ops)
          detail = build_entry_detail(ops)
          Library.record_entries_edit(folio_id, user_id, summary, detail)

          Logger.info(
            "[FolioFlush] flush path=#{path} folio=#{folio_id} user=#{user_id} ops=#{length(ops)} result=ok summary=#{inspect(summary)}"
          )

          :ok
        rescue
          e ->
            Logger.error(
              "[FolioFlush] flush path=#{path} folio=#{folio_id} user=#{user_id} ops=#{length(ops)} result=raised class=#{inspect(e.__struct__)} message=#{Exception.message(e)}"
            )

            Logger.error(Exception.format(:error, e, __STACKTRACE__))

            :error
        end
    end
  end

  defp build_count_summary(ops) do
    posts_added  = Enum.count(ops, &(&1.op == :added_post))
    notes_added  = Enum.count(ops, &(&1.op == :added_note))
    notes_edited = Enum.count(ops, &(&1.op == :edited_note))
    deleted      = Enum.count(ops, &(&1.op in [:deleted_post, :deleted_note]))
    reordered    = Enum.any?(ops, &(&1.op == :reordered))

    [
      posts_added  > 0 && "added #{posts_added} post#{if posts_added == 1, do: "", else: "s"}",
      notes_added  > 0 && "added #{notes_added} note#{if notes_added == 1, do: "", else: "s"}",
      notes_edited > 0 && "edited #{notes_edited} note#{if notes_edited == 1, do: "", else: "s"}",
      deleted      > 0 && "deleted #{deleted} entr#{if deleted == 1, do: "y", else: "ies"}",
      reordered            && "reordered entries"
    ]
    |> Enum.filter(& &1)
    |> Enum.join(", ")
  end

  defp build_entry_detail(ops) do
    added_posts  = ops |> Enum.filter(&(&1.op == :added_post))  |> Enum.map(& &1.label)
    added_notes  = ops |> Enum.filter(&(&1.op == :added_note))  |> Enum.map(& &1.content)
    deleted_post = ops |> Enum.filter(&(&1.op == :deleted_post)) |> Enum.map(& &1.label)
    deleted_note = ops |> Enum.filter(&(&1.op == :deleted_note)) |> Enum.map(& &1.content)
    edited_notes = ops |> Enum.filter(&(&1.op == :edited_note)) |> Enum.map(& &1.content)
    reordered    = Enum.any?(ops, &(&1.op == :reordered))

    [
      if(added_posts  != [], do: "added: #{Enum.join(added_posts, ", ")}"),
      if(added_notes  != [], do: Enum.map_join(added_notes, ", ", &"added note: \"#{&1}\"")),
      if(deleted_post != [], do: "deleted: #{Enum.join(deleted_post, ", ")}"),
      if(deleted_note != [], do: Enum.map_join(deleted_note, ", ", &"deleted note: \"#{&1}\"")),
      if(edited_notes != [], do: Enum.map_join(edited_notes, ", ", &"edited note: \"#{&1}\"")),
      if(reordered,           do: "reordered entries"),
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" · ")
  end

  defp rank_to_db_position(entries, rank) do
    case Enum.at(entries, rank - 1) do
      nil ->
        case List.last(entries) do
          nil  -> 1
          last -> last.position + 1
        end
      entry ->
        entry.position
    end
  end

  defp renew_lock(socket) do
    if ref = socket.assigns[:entries_lock_timer_ref], do: Process.cancel_timer(ref)
    Library.claim_entries_lock(socket.assigns.folio.id, socket.assigns.current_user.id)
    ref = Process.send_after(self(), :entries_lock_timeout, @entries_lock_timeout_ms)
    assign(socket, :entries_lock_timer_ref, ref)
  end

  defp load_scenes(socket, user) do
    all_scenes = Scenes.list_scenes_for_composer(user.id)

    socket
    |> assign(:all_scenes, all_scenes)
    |> assign(:visible_scenes, filter_scenes(all_scenes, socket.assigns.filter_query))
  end

  defp recompute_visible_scenes(socket) do
    assign(
      socket,
      :visible_scenes,
      filter_scenes(socket.assigns.all_scenes, socket.assigns.filter_query)
    )
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
    post_ref_entries = Enum.filter(entries, &(&1.kind == :post_ref && &1.scene_post != nil))

    included_post_ids =
      post_ref_entries |> Enum.map(& &1.scene_post_id) |> MapSet.new()

    included_scene_ids =
      post_ref_entries |> Enum.map(& &1.scene_post.scene_id) |> MapSet.new()

    socket
    |> assign(:entries, entries)
    |> assign(:group_actions, compute_group_actions(entries))
    |> assign(:included_post_ids, included_post_ids)
    |> assign(:included_scene_ids, included_scene_ids)
  end

  defp load_scene_posts(socket, scene_id) do
    posts = Scenes.list_posts_for_archive(scene_id)
    update(socket, :scene_posts_cache, &Map.put(&1, scene_id, posts))
  end
end
