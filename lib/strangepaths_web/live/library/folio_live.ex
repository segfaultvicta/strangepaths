defmodule StrangepathsWeb.LibraryLive.Folio do
  use StrangepathsWeb, :live_view
  import StrangepathsWeb.SceneHelpers, only: [render_post_content: 1]
  import StrangepathsWeb.LibraryHelpers, only: [render_library_content: 1]

  alias Strangepaths.Library

  @lock_timeout_ms Library.lock_timeout_seconds() * 1_000

  @impl true
  def mount(%{"slug" => slug}, session, socket) do
    socket = assign_defaults(session, socket)

    case Library.get_folio_by_slug(slug) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Folio not found.")
         |> push_redirect(to: "/library")}

      folio ->
        user = socket.assigns.current_user
        entries = Library.list_entries(folio.id)
        folio_tags = Library.list_folio_tags(folio.id)

        all_marginalia = Library.list_all_marginalia_for_folio(folio.id)

        marginalia_flat_map =
          all_marginalia
          |> Enum.group_by(& &1.entry_id)
          |> Enum.map(fn {entry_id, items} ->
            {entry_id, flatten_marginalia_tree(items)}
          end)
          |> Map.new()

        if connected?(socket) do
          StrangepathsWeb.Endpoint.subscribe("library_folio:#{folio.id}")
        end

        {:ok,
         socket
         |> assign(:page_title, folio.title)
         |> assign(:folio, folio)
         |> assign(:entries, entries)
         |> assign(:folio_tags, folio_tags)
         |> assign(:editing_title, false)
         |> assign(:title_changeset, Library.change_folio(folio))
         |> assign(:is_author, user != nil && folio.user_id == user.id)
         |> assign(:is_dragon, user != nil && user.role == :dragon)
         |> assign(:is_folio_editor, user != nil && Library.folio_editor?(user.id))
         |> assign(:editing_body, false)
         |> assign(:body_content, folio.body || "")
         |> assign(:preview_html, render_library_content(folio.body || ""))
         |> assign(:editor_typefaces, if(user, do: Library.folio_editor_typefaces(user.id), else: []))
         |> assign(:marginalia_flat_map, marginalia_flat_map)
         |> assign(:expanded_entries, MapSet.new())
         |> assign(:marginalia_form_entry_id, nil)
         |> assign(:marginalia_reply_to_id, nil)}
    end
  end

  @impl true
  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  @impl true
  def handle_event("start_edit_title", _params, socket) do
    if socket.assigns.is_author || socket.assigns.is_dragon do
      {:noreply, assign(socket, :editing_title, true)}
    else
      {:noreply, put_flash(socket, :error, "Unauthorized.")}
    end
  end

  def handle_event("cancel_edit_title", _params, socket) do
    {:noreply, assign(socket, :editing_title, false)}
  end

  def handle_event("save_title", %{"folio" => attrs}, socket) do
    if socket.assigns.is_author || socket.assigns.is_dragon do
      case Library.update_folio_title(socket.assigns.folio, attrs) do
        {:ok, updated_folio} ->
          # update_folio_title preserves the :user preload from the in-memory struct
          {:noreply,
           socket
           |> assign(:folio, updated_folio)
           |> assign(:editing_title, false)
           |> assign(:title_changeset, Library.change_folio(updated_folio))
           |> push_patch(to: "/library/#{updated_folio.slug}")}

        {:error, changeset} ->
          {:noreply, assign(socket, :title_changeset, changeset)}
      end
    else
      {:noreply, put_flash(socket, :error, "Unauthorized.")}
    end
  end

  def handle_event("delete_folio", _params, socket) do
    if socket.assigns.is_dragon do
      Library.delete_folio(socket.assigns.folio)

      {:noreply,
       socket
       |> put_flash(:info, "Folio deleted.")
       |> push_redirect(to: "/library")}
    else
      {:noreply, put_flash(socket, :error, "Unauthorized.")}
    end
  end

  def handle_event("claim_body_lock", _params, socket) do
    user = socket.assigns.current_user
    folio = socket.assigns.folio

    if socket.assigns.is_folio_editor do
      case Library.claim_body_lock(folio.id, user.id) do
        :ok ->
          Process.send_after(self(), :body_lock_timeout, @lock_timeout_ms)

          {:noreply,
           socket
           |> assign(:editing_body, true)
           |> assign(:body_content, folio.body || "")}

        {:error, :locked} ->
          {:noreply, put_flash(socket, :error, "Another editor is currently editing the body.")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("cancel_edit_body", _params, socket) do
    Library.release_body_lock(socket.assigns.folio.id)
    {:noreply, assign(socket, :editing_body, false)}
  end

  def handle_event("update_preview", %{"folio" => %{"body" => content}}, socket) do
    {:noreply,
     socket
     |> assign(:body_content, content)
     |> assign(:preview_html, render_library_content(content))}
  end

  def handle_event("save_body", %{"folio" => %{"body" => content}}, socket) do
    if socket.assigns.is_folio_editor do
      case Library.save_body(socket.assigns.folio, socket.assigns.current_user.id, content) do
        :ok ->
          updated_folio = %{socket.assigns.folio | body: content}

          {:noreply,
           socket
           |> assign(:folio, updated_folio)
           |> assign(:editing_body, false)
           |> assign(:preview_html, render_library_content(content))}

        {:error, :lock_lost} ->
          {:noreply,
           socket
           |> assign(:editing_body, false)
           |> put_flash(:error, "Lock was lost. Your changes were not saved. Please try again.")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("toggle_marginalia_thread", %{"entry-id" => entry_id_str}, socket) do
    entry_id = String.to_integer(entry_id_str)

    updated = if MapSet.member?(socket.assigns.expanded_entries, entry_id) do
      MapSet.delete(socket.assigns.expanded_entries, entry_id)
    else
      MapSet.put(socket.assigns.expanded_entries, entry_id)
    end

    {:noreply, assign(socket, :expanded_entries, updated)}
  end

  def handle_event("open_marginalia_form", %{"entry-id" => entry_id_str} = params, socket) do
    if socket.assigns.is_folio_editor do
      entry_id = String.to_integer(entry_id_str)
      reply_to = params["reply-to"] && String.to_integer(params["reply-to"])

      {:noreply,
       socket
       |> assign(:marginalia_form_entry_id, entry_id)
       |> assign(:marginalia_reply_to_id, reply_to)
       |> update(:expanded_entries, &MapSet.put(&1, entry_id))}
    else
      {:noreply, put_flash(socket, :error, "Unauthorized.")}
    end
  end

  def handle_event("close_marginalia_form", _params, socket) do
    {:noreply,
     socket
     |> assign(:marginalia_form_entry_id, nil)
     |> assign(:marginalia_reply_to_id, nil)}
  end

  def handle_event("submit_marginalia", %{"marginalia" => attrs}, socket) do
    if socket.assigns.is_folio_editor do
      user = socket.assigns.current_user
      entry_id = socket.assigns.marginalia_form_entry_id

      # Find the entry from the current assigns
      entry = Enum.find(socket.assigns.entries, &(&1.id == entry_id))

      # Determine which typeface to use
      typefaces = Library.folio_editor_typefaces(user.id)

      # Compare typeface_id string to string directly (typeface IDs are strings like "jorule", not integers)
      tf_id = attrs["typeface_id"]
      tf =
        cond do
          is_binary(tf_id) and tf_id != "" -> Enum.find(typefaces, &(&1.id == tf_id))
          true -> nil
        end

      cond do
        typefaces == [] ->
          {:noreply, put_flash(socket, :error, "You have no typefaces assigned.")}

        is_binary(tf_id) and tf_id != "" and tf == nil ->
          {:noreply, put_flash(socket, :error, "Invalid typeface selection.")}

        true ->
          selected_tf = tf || List.first(typefaces)

          full_attrs =
            attrs
            |> Map.put("name", selected_tf.name)
            |> Map.put("font", selected_tf.font)
            |> Map.put("color", selected_tf.color)
            |> Map.put("parent_id", socket.assigns.marginalia_reply_to_id)

          case Library.create_marginalia(entry, user, full_attrs) do
            {:ok, _marginalia} ->
              {:noreply,
               socket
               |> assign(:marginalia_form_entry_id, nil)
               |> assign(:marginalia_reply_to_id, nil)}

            {:error, :max_depth_exceeded} ->
              {:noreply, put_flash(socket, :error, "Cannot reply this deeply.")}

            {:error, _changeset} ->
              {:noreply, put_flash(socket, :error, "Failed to post marginalia.")}
          end
      end
    else
      {:noreply, put_flash(socket, :error, "Unauthorized.")}
    end
  end

  @impl true
  def handle_event("add_tag", %{"tag" => raw_tag}, socket) do
    tag = raw_tag |> String.downcase() |> String.trim()

    if socket.assigns.is_folio_editor && tag != "" do
      Library.add_tag(socket.assigns.folio, tag)
      {:noreply, load_folio_tags(socket)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("remove_tag", %{"tag" => tag}, socket) do
    if socket.assigns.is_folio_editor do
      Library.remove_tag(socket.assigns.folio, tag)
      {:noreply, load_folio_tags(socket)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(:body_lock_timeout, socket) do
    if socket.assigns[:editing_body] do
      Library.release_body_lock(socket.assigns.folio.id)

      {:noreply,
       socket
       |> assign(:editing_body, false)
       |> put_flash(:warning, "Body editing session timed out. Changes were not saved.")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "new_marginalia", payload: %{marginalia: m, entry_id: entry_id}}, socket) do
    # Recompute the flat tree for this entry's marginalia
    all_for_entry = Map.get(socket.assigns.marginalia_flat_map, entry_id, [])
                    |> Enum.map(fn {item, _depth} -> item end)
    # Deduplicate in case the same broadcast payload is delivered twice
    deduplicated = Enum.uniq_by(all_for_entry ++ [m], & &1.id)
    updated_flat = flatten_marginalia_tree(deduplicated)

    updated_map = Map.put(socket.assigns.marginalia_flat_map, entry_id, updated_flat)
    {:noreply, assign(socket, :marginalia_flat_map, updated_map)}
  end

  @impl true
  def terminate(_reason, socket) do
    if socket.assigns[:editing_body] do
      Library.release_body_lock(socket.assigns.folio.id)
    end
    :ok
  end

  # Helper function to flatten marginalia tree with depth information
  defp flatten_marginalia_tree(all, parent_id \\ nil, depth \\ 0) do
    children = Enum.filter(all, &(&1.parent_id == parent_id))
    Enum.flat_map(children, fn m ->
      [{m, depth}] ++ flatten_marginalia_tree(all, m.id, depth + 1)
    end)
  end

  # Helper to load folio tags into @folio_tags assign
  defp load_folio_tags(socket) do
    tags = Library.list_folio_tags(socket.assigns.folio.id)
    assign(socket, :folio_tags, tags)
  end
end
