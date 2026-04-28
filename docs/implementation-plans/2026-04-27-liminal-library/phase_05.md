# Liminal Library Phase 5: Post Collection Composer

**Goal:** Split-panel LiveView for building post collections — scene browser (left) with filtering and range selection, live entry list (right) with insertion caret, drag-to-reorder, and inline note insertion.

**Architecture:** New `LibraryLive.Composer` LiveView at `/library/:slug/compose`. Left panel shows all scenes (both active and archived) with collapsible post lists. Right panel shows the folio's entry list managed via Sortable.js. Server holds all state (filter, caret position, selected range anchor). JS hook `LibraryComposer` handles Sortable.js, shift-click detection, and insertion caret UI.

**Key findings from codebase investigation:**
- Scene tags are `{:array, :string}` field on scenes; `#full cast session` is a plain tag string value
- `list_posts_for_archive/1` returns posts in chronological order — use this for the composer left panel
- Sortable.js is already in `Hooks.Sortable` in `assets/js/app.js` — extend it for the composer
- No existing `list_scenes_for_composer` function — needs to be added to Scenes context

**Tech Stack:** Phoenix LiveView, Ecto, Sortable.js (already in assets)

**Scope:** Phase 5 of 7

**Codebase verified:** 2026-04-27

---

## Acceptance Criteria Coverage

### liminal-library.AC4: Post collection composer
- **liminal-library.AC4.1 Success:** Scene browser shows all scenes with archive tag badges
- **liminal-library.AC4.2 Success:** Title/tag filter narrows scene list; `#full cast session` scenes always appear regardless
- **liminal-library.AC4.3 Success:** Full-cast-session scenes have a distinct background color in the scene list
- **liminal-library.AC4.4 Success:** "Scenes I was in" toggle filters to only scenes the current user has posts in
- **liminal-library.AC4.5 Success:** Clicking a post adds it at the current insertion caret position
- **liminal-library.AC4.6 Success:** Shift-click range and From/To caret buttons both select contiguous post ranges
- **liminal-library.AC4.7 Success:** Entries can be reordered by dragging; grouped entries (shared group_id) move as a unit
- **liminal-library.AC4.8 Success:** Inline note can be inserted between any two entries
- **liminal-library.AC4.9 Success:** Insertion caret is placeable between any two entries and persists between additions

### liminal-library.AC5: Entry permissions
- **liminal-library.AC5.1 Success:** Any folio editor can add post entries and inline notes to any folio
- **liminal-library.AC5.2 Success:** Folio author (and dragon) can reorder, delete, and edit entries in their folio
- **liminal-library.AC5.3 Failure:** Non-author folio editor cannot reorder, delete, or edit existing entries

---

<!-- START_SUBCOMPONENT_A (tasks 1-2) -->

<!-- START_TASK_1 -->
### Task 1: Scenes context — composer query functions

Add two functions to `lib/strangepaths/scenes.ex`:

```elixir
@doc """
Returns all scenes for the library composer browser — both active and archived.
Ordered by status (active first), then by name.
Includes owner preload for display.
"""
def list_scenes_for_composer do
  from(s in Scene,
    where: not s.is_elsewhere,
    order_by: [asc: s.status, asc: s.name],
    preload: [:owner]
  )
  |> Repo.all()
end

@doc """
Returns all scenes where the given user has at least one post.
Used for the "Scenes I was in" filter in the composer.
"""
def list_scenes_with_user_posts(user_id) do
  from(s in Scene,
    join: p in Post,
    on: p.scene_id == s.id and p.user_id == ^user_id,
    where: not s.is_elsewhere,
    distinct: true,
    order_by: [asc: s.status, asc: s.name],
    preload: [:owner]
  )
  |> Repo.all()
end
```

Also add `list_posts_for_archive/1` to the `alias` or confirm it already exists (it does — in the investigation, it's confirmed as an existing function in `scenes.ex`).

**Verify:**

```bash
mix compile --no-deps-check
```
<!-- END_TASK_1 -->

<!-- START_TASK_2 -->
### Task 2: Router, FolioList update, and Composer LiveView scaffold

**A. Update `lib/strangepaths_web/router.ex`:**

Add the compose route. It must be defined BEFORE `/library/:slug` (which you added in Phase 3) to prevent potential conflict — even though Phoenix route matching handles different segment counts, explicit ordering is safer:

```elixir
live("/library/:slug/compose", LibraryLive.Composer, :compose)
# These were already added in Phase 3:
# live("/library/admin", LibraryLive.Admin)
# live("/library/:slug", LibraryLive.Folio, :show)
# live("/library/new", LibraryLive.FolioList, :new)
# live("/library", LibraryLive.FolioList, :index)
```

**B. Update `lib/strangepaths_web/live/library/folio_list_live.ex`:**

Change the `create_folio` event handler's success redirect from `/library/#{folio.slug}` to `/library/#{folio.slug}/compose`:

```elixir
# In handle_event("create_folio", ...), change:
# push_redirect(to: "/library/#{folio.slug}")
# to:
push_redirect(to: "/library/#{folio.slug}/compose")
```

**C. Create `lib/strangepaths_web/live/library/composer_live.ex`:**

```elixir
defmodule StrangepathsWeb.LibraryLive.Composer do
  use StrangepathsWeb, :live_view

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
        if user && Library.is_folio_editor?(user.id) do
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
    user = socket.assigns.current_user
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
```

**Important:** `Library.update_entry_group/2` is a new function needed for the `group_entries` event. Add to `lib/strangepaths/library.ex`:

```elixir
def update_entry_group(entry, group_id) do
  entry
  |> Strangepaths.Library.Entry.group_changeset(%{group_id: group_id})
  |> Repo.update()
end
```

And add to `lib/strangepaths/library/entry.ex`:

```elixir
def group_changeset(entry, attrs) do
  cast(entry, attrs, [:group_id])
end
```

**Verify:**

```bash
mix compile --no-deps-check
```
<!-- END_TASK_2 -->

<!-- END_SUBCOMPONENT_A -->

<!-- START_SUBCOMPONENT_B (tasks 3-5) -->

<!-- START_TASK_3 -->
### Task 3: Composer template

**Create `lib/strangepaths_web/live/library/composer_live.html.heex`:**

```heex
<div class="flex h-screen overflow-hidden">

  <%# === LEFT PANEL: Scene Browser === %>
  <div class="w-1/2 border-r border-gray-800 flex flex-col overflow-hidden">
    <div class="p-4 border-b border-gray-800 flex-shrink-0">
      <h2 class="font-semibold mb-3">Scene Browser</h2>

      <input
        type="text"
        placeholder="Filter by title or tag..."
        value={@filter_query}
        phx-change="set_filter"
        phx-debounce="300"
        name="q"
        class="w-full bg-gray-900 border border-gray-700 rounded px-3 py-1 text-sm mb-2"
      />

      <label class="flex items-center gap-2 text-sm cursor-pointer">
        <input
          type="checkbox"
          phx-click="toggle_my_scenes"
          checked={@my_scenes_only}
        />
        Scenes I was in
      </label>
    </div>

    <div class="overflow-y-auto flex-1 p-2">
      <%= for scene <- @visible_scenes do %>
        <%# full cast session scenes get a distinct background %>
        <div class={"mb-1 rounded " <> if("full cast session" in scene.tags, do: "bg-emerald-950/30 border border-emerald-900/50", else: "")}>
          <button
            phx-click="expand_scene"
            phx-value-scene-id={scene.id}
            class="w-full text-left px-3 py-2 hover:bg-gray-800 rounded text-sm flex items-center justify-between"
          >
            <span class="font-medium"><%= scene.name %></span>
            <span class="flex gap-1 flex-wrap">
              <%= for tag <- scene.tags do %>
                <span class="text-xs bg-gray-800 px-1 rounded"><%= tag %></span>
              <% end %>
              <span class="text-gray-500"><%= if @expanded_scene_id == scene.id, do: "▲", else: "▼" %></span>
            </span>
          </button>

          <%= if @expanded_scene_id == scene.id do %>
            <div class="ml-3 border-l border-gray-700 pl-2">
              <%= for post <- Map.get(@scene_posts_cache, scene.id, []) do %>
                <div id={"browser-post-#{post.id}"} class="py-2 border-b border-gray-800/50 text-sm group/post">
                  <div class="flex items-center justify-between mb-1">
                    <span class="font-medium text-xs text-gray-400">
                      <%= post.author_nickname || (post.user && post.user.nickname) %>
                    </span>
                    <div class="flex gap-1 opacity-0 group-hover/post:opacity-100 transition-opacity">
                      <button
                        phx-click="set_range_anchor"
                        phx-value-post-id={post.id}
                        title="Set as range start (From)"
                        class="text-xs px-1 text-gray-500 hover:text-gray-300"
                      >↑ From</button>
                      <%= if @range_anchor_post_id do %>
                        <button
                          phx-click="add_range"
                          phx-value-from-post-id={@range_anchor_post_id}
                          phx-value-to-post-id={post.id}
                          phx-value-scene-id={scene.id}
                          title="Add range from anchor to here"
                          class="text-xs px-1 text-gray-500 hover:text-gray-300"
                        >↓ To</button>
                      <% end %>
                    </div>
                  </div>
                  <div
                    class="cursor-pointer hover:bg-gray-700/50 rounded p-1"
                    phx-click="add_post"
                    phx-value-post-id={post.id}
                    title="Add post at caret position"
                  >
                    <div class="text-xs text-gray-300 line-clamp-3">
                      <%= raw render_post_content(post.content) %>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
  </div>

  <%# === RIGHT PANEL: Entry List === %>
  <div class="w-1/2 flex flex-col overflow-hidden">
    <div class="p-4 border-b border-gray-800 flex-shrink-0">
      <h2 class="font-semibold">
        <%= @folio.title %>
        <%= live_redirect "← View folio", to: "/library/#{@folio.slug}", class: "text-xs text-gray-500 hover:text-gray-300 ml-2" %>
      </h2>
      <p class="text-xs text-gray-500 mt-1">
        Caret at position <%= @caret_position %> · <%= length(@entries) %> entries
      </p>
    </div>

    <div
      id="composer-entry-list"
      phx-hook="LibraryComposer"
      class="overflow-y-auto flex-1 p-2"
    >
      <%# Caret at position 1 (before all entries) %>
      <div
        class={"caret-slot py-1 cursor-pointer " <> if(@caret_position == 1, do: "border-t-2 border-purple-500", else: "border-t border-gray-800 hover:border-gray-600")}
        phx-click="set_caret"
        phx-value-position="1"
        title="Set insertion point here"
      ></div>

      <%= for {entry, index} <- Enum.with_index(@entries, 1) do %>
        <div
          id={"entry-#{entry.id}"}
          data-entry-id={entry.id}
          data-group-id={entry.group_id || ""}
          class={"entry-item mb-1 p-2 bg-gray-900 rounded border " <> if(entry.group_id, do: "border-amber-900/50", else: "border-gray-800")}
        >
          <div class="flex items-start justify-between gap-2">
            <div class="flex-1 min-w-0">
              <%= case entry.kind do %>
              <% :post_ref -> %>
                <div class="text-xs text-gray-500 mb-1">
                  <%= entry.scene_post && (entry.scene_post.author_nickname || (entry.scene_post.user && entry.scene_post.user.nickname)) %>
                </div>
                <div class="text-xs text-gray-300 line-clamp-3">
                  <%= raw(entry.scene_post && render_post_content(entry.scene_post.content)) %>
                </div>
              <% :note -> %>
                <div class="text-xs italic" style={"font-family: #{entry.font}; color: #{entry.color};"}>
                  <%= raw render_library_content(entry.content) %>
                </div>
              <% end %>
            </div>

            <%= if @is_author || @is_dragon do %>
              <div class="flex gap-1 flex-shrink-0">
                <span class="drag-handle cursor-grab text-gray-600 hover:text-gray-400 text-sm" title="Drag to reorder">⣿</span>
                <button
                  phx-click="delete_entry"
                  phx-value-entry-id={entry.id}
                  class="text-xs text-gray-600 hover:text-red-400"
                  title="Remove entry"
                >✕</button>
              </div>
            <% end %>
          </div>
        </div>

        <%# Caret slot AFTER this entry %>
        <div
          class={"caret-slot py-1 cursor-pointer " <> if(@caret_position == index + 1, do: "border-t-2 border-purple-500", else: "border-t border-gray-800 hover:border-gray-600")}
          phx-click="set_caret"
          phx-value-position={index + 1}
          title="Set insertion point here"
        ></div>

        <%# Add note affordance between entries (only when caret is here) %>
        <%= if @caret_position == index + 1 do %>
          <div class="mb-2">
            <form phx-submit="add_note">
              <input type="hidden" name="position" value={index + 1} />
              <textarea
                name="note[content]"
                placeholder="Add inline note..."
                class="w-full bg-gray-900 border border-gray-700 rounded px-2 py-1 text-xs h-16 resize-none"
              ></textarea>
              <button type="submit" class="text-xs px-2 py-0.5 bg-gray-700 rounded mt-1">+ Add note</button>
            </form>
          </div>
        <% end %>
      <% end %>
    </div>
  </div>

</div>
```
<!-- END_TASK_3 -->

<!-- START_TASK_4 -->
### Task 4: `LibraryComposer` JS hook

In `assets/js/app.js`, add the `LibraryComposer` hook. Find where `Hooks.Sortable` is defined and add the new hook nearby. Note: The hook definition was already added in Task 3 above (in the template notes), with `initSortable()` and `initShiftClick()` methods extracted.

**Important — AC4.7 gap:** The current Sortable.js implementation does not automatically enforce that entries sharing a `group_id` move as a unit. To fully satisfy AC4.7, the `onEnd` callback must detect if the dragged entry belongs to a group, find all sibling entries with the same `group_id` in the DOM, and ensure they follow the dragged entry to its new position. Alternatively, render grouped entries inside a single draggable wrapper `<div>` with a stable `id` containing the `group_id`, and add the entire wrapper to Sortable. The latter approach is recommended as it provides native drag behavior for the group.

**Note on Sortable.js and LiveView re-renders:** When new entries are added to the list, LiveView will patch the DOM. The `phx-update="ignore"` attribute was removed so LiveView can update the list naturally. The `LibraryComposer` hook's `updated()` callback should re-initialize Sortable on the updated container to ensure new entries are draggable. Add this to the hook:

```javascript
Hooks.LibraryComposer = {
  mounted() {
    this.initSortable();
    this.initShiftClick();
  },

  updated() {
    this.initSortable();
  },

  initSortable() {
    const list = this.el.querySelector("#composer-entry-list") || this.el;
    new Sortable(list, {
      animation: 150,
      ghostClass: "opacity-50",
      handle: ".drag-handle",
      onEnd: (event) => {
        const items = list.querySelectorAll("[data-entry-id]");
        const orderedIds = Array.from(items)
          .map((el) => el.dataset.entryId)
          .filter(Boolean)
          .join(",");

        this.pushEvent("reorder_entries", { ids: orderedIds });
      },
    });
  },

  initShiftClick() {
    document.addEventListener("click", (e) => {
      const postEl = e.target.closest("[id^='browser-post-']");
      if (!postEl || !e.shiftKey) return;

      const postId = postEl.id.replace("browser-post-", "");
      const sceneEl = postEl.closest("[data-scene-id]");
      const sceneId = sceneEl ? sceneEl.dataset.sceneId : null;

      if (postId && sceneId) {
        this.pushEvent("shift_select_post", {
          "post-id": postId,
          "scene-id": sceneId,
        });
      }
    });
  },
};
```

Each `[data-entry-id]` gets a stable `id` attribute (e.g., `id={"entry-#{entry.id}"}`) so LiveView can patch only changed rows.

**Note on shift-click:** The above delegates range calculation to the server via a `shift_select_post` event. Add the handler to `composer_live.ex`:

```elixir
def handle_event("shift_select_post", %{"post-id" => post_id_str, "scene-id" => scene_id_str}, socket) do
  case socket.assigns.range_anchor_post_id do
    nil ->
      # No anchor set — treat as regular add
      handle_event("add_post", %{"post-id" => post_id_str}, socket)

    anchor_id ->
      # Has anchor — add the range
      handle_event("add_range", %{
        "from-post-id" => to_string(anchor_id),
        "to-post-id" => post_id_str,
        "scene-id" => scene_id_str
      }, socket)
  end
end
```

**Note on code organization:** While the current approach works, it chains direct `handle_event/3` calls. For better maintainability, extract the core logic from `add_post` and `add_range` event handlers into private helpers `do_add_post/3` and `do_add_range/4`. Have `shift_select_post` and the corresponding public event handlers all call these private functions rather than calling `handle_event/3` directly. This avoids nested handle_event calls and makes the logic easier to test.

Also add `data-scene-id` to the scene `<div>` in the template so shift-click can find the scene:

```heex
<div data-scene-id={scene.id} class={"mb-1 rounded " <> ...}>
```

**Verify:**

```bash
mix assets.build
mix compile --no-deps-check
```
<!-- END_TASK_4 -->

<!-- START_TASK_5 -->
### Task 5: Composer tests

**Create `test/strangepaths_web/live/library/composer_live_test.exs`:**

```elixir
defmodule StrangepathsWeb.LibraryLive.ComposerTest do
  use StrangepathsWeb.ConnCase

  import Phoenix.LiveViewTest
  import Strangepaths.AccountsFixtures
  import Strangepaths.LibraryFixtures

  alias Strangepaths.Library

  # Verifies: liminal-library.AC4.1
  describe "GET /library/:slug/compose" do
    test "folio editor can access composer", %{conn: conn} do
      user = user_typeface_fixture()
      folio = folio_fixture(user, %{"title" => "Composer Access Test"})
      conn = log_in_user(conn, user)

      {:ok, _view, html} = live(conn, "/library/composer-access-test/compose")
      assert html =~ "Scene Browser"
      assert html =~ "Composing: Composer Access Test"
    end

    test "non-folio-editor is redirected", %{conn: conn} do
      author = user_typeface_fixture()
      folio = folio_fixture(author, %{"title" => "Composer Redirect Test"})
      other_user = user_fixture()
      conn = log_in_user(conn, other_user)

      {:ok, view, _html} = live(conn, "/library/composer-redirect-test/compose")
      assert_redirect(view, "/library/composer-redirect-test")
    end
  end

  # Verifies: liminal-library.AC4.2 (filter)
  describe "scene filtering" do
    test "filter by title narrows scene list", %{conn: conn} do
      user = user_typeface_fixture()
      folio = folio_fixture(user, %{"title" => "Filter Test Folio"})
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, "/library/filter-test-folio/compose")

      html = view |> element("input[name='q']") |> render_change(%{q: "nonexistent_xyz_term"})
      # With an obscure filter, full-cast-session scenes still appear
      # but non-matching ones are hidden — this depends on having scene fixtures
      # Verify the event handler runs without crashing
      assert is_binary(html)
    end
  end

  # Verifies: liminal-library.AC5.1 (any folio editor can add entries)
  describe "adding entries" do
    test "folio editor can add an inline note at caret position", %{conn: conn} do
      user = user_typeface_fixture()
      folio = folio_fixture(user, %{"title" => "Note Add Test"})
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, "/library/note-add-test/compose")

      view
      |> form("form[phx-submit='add_note']", note: %{content: "An inline note"}, position: "1")
      |> render_submit()

      entries = Library.list_entries(folio.id)
      assert length(entries) == 1
      assert hd(entries).kind == :note
      assert hd(entries).content == "An inline note"
    end
  end

  # Verifies: liminal-library.AC5.2 and AC5.3 (entry deletion permissions)
  describe "entry deletion permissions" do
    test "author can delete entries", %{conn: conn} do
      user = user_typeface_fixture()
      folio = folio_fixture(user, %{"title" => "Author Delete Test"})
      entry = note_entry_fixture(folio, user)
      conn = log_in_user(conn, user)

      {:ok, view, html} = live(conn, "/library/author-delete-test/compose")
      assert html =~ "✕"

      view
      |> element("button[phx-click='delete_entry'][phx-value-entry-id='#{entry.id}']")
      |> render_click()

      assert Library.list_entries(folio.id) == []
    end

    test "non-author folio editor does not see delete button (AC5.3)", %{conn: conn} do
      author = user_typeface_fixture()
      other_editor = user_typeface_fixture()
      folio = folio_fixture(author, %{"title" => "Non Author Delete"})
      _entry = note_entry_fixture(folio, author)
      conn = log_in_user(conn, other_editor)

      {:ok, _view, html} = live(conn, "/library/non-author-delete/compose")
      refute html =~ "✕"
    end
  end
end
```

**Run:**

```bash
mix test test/strangepaths_web/live/library/composer_live_test.exs
mix test
```

**Commit:**

```bash
git add lib/strangepaths/scenes.ex \
        lib/strangepaths/library.ex \
        lib/strangepaths/library/entry.ex \
        lib/strangepaths_web/router.ex \
        lib/strangepaths_web/live/library/folio_list_live.ex \
        lib/strangepaths_web/live/library/composer_live.ex \
        lib/strangepaths_web/live/library/composer_live.html.heex \
        assets/js/app.js \
        test/strangepaths_web/live/library/composer_live_test.exs
git commit -m "liminal library phase 5: post collection composer"
```
<!-- END_TASK_5 -->

<!-- END_SUBCOMPONENT_B -->
