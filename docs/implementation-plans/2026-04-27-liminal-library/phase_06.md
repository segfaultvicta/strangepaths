# Liminal Library Phase 6: Marginalia System

**Goal:** Threaded viewer commentary on individual folio entries — collapsed by default, rendered in poster's stored typeface, delivered in real-time via PubSub.

**Architecture:** Each entry on the folio view page gets a marginalia thread below it (collapsed to a count badge by default). Expanding a thread shows the adjacency-list tree with replies indented. New marginalia are broadcast on `"library_folio:#{folio_id}"` and appended to the relevant entry's thread in real-time. Depth enforcement in the context prevents runaway nesting.

**Key patterns from codebase investigation:**
- PubSub: `StrangepathsWeb.Endpoint.broadcast(topic, event, payload)` and `.subscribe(topic)` (matching BBS pattern exactly)
- New item delivery: `socket.assigns.marginalia_map ++ [new]` style list append (no `phx-update="append"`)
- Toggle pattern: MapSet of expanded entry IDs in assigns; `toggle_marginalia_thread` event adds/removes

**Tech Stack:** Phoenix LiveView, PubSub via `StrangepathsWeb.Endpoint`, Ecto

**Scope:** Phase 6 of 7

**Codebase verified:** 2026-04-27

---

## Acceptance Criteria Coverage

### liminal-library.AC6: Marginalia
- **liminal-library.AC6.1 Success:** Any folio editor can add marginalia to any entry on any folio
- **liminal-library.AC6.2 Success:** User with multiple typefaces sees a dropdown when adding marginalia
- **liminal-library.AC6.3 Success:** Marginalia render in the poster's stored typeface (name/font/color)
- **liminal-library.AC6.4 Success:** Marginalia threads are collapsed by default with count badge visible
- **liminal-library.AC6.5 Success:** Expanding a thread shows marginalia inline below the entry, with replies indented
- **liminal-library.AC6.6 Success:** New marginalia appear in real-time for all active viewers
- **liminal-library.AC6.7 Failure:** Non-folio-editor cannot add marginalia

---

<!-- START_SUBCOMPONENT_A (tasks 1-2) -->

<!-- START_TASK_1 -->
### Task 1: Library context — marginalia additions

**A. Add `list_all_marginalia_for_folio/1` to `lib/strangepaths/library.ex`:**

Loads all marginalia for all entries of a folio in one query, ordered by `inserted_at` for consistent thread rendering:

```elixir
def list_all_marginalia_for_folio(folio_id) do
  entry_ids =
    from(e in Entry, where: e.folio_id == ^folio_id, select: e.id)
    |> Repo.all()

  from(m in Marginalia,
    where: m.entry_id in ^entry_ids,
    order_by: m.inserted_at,
    preload: [:user]
  )
  |> Repo.all()
end
```

**B. Add depth enforcement and PubSub broadcast to `create_marginalia/3`:**

Replace the existing `create_marginalia/3` function with this version:

```elixir
@max_marginalia_depth 3

def create_marginalia(entry, user, attrs) do
  parent_id = attrs["parent_id"] || attrs[:parent_id]

  cond do
    parent_id != nil && parent_id != "" ->
      depth = marginalia_depth(String.to_integer(to_string(parent_id)))

      if depth >= @max_marginalia_depth do
        {:error, :max_depth_exceeded}
      else
        do_create_marginalia(entry, user, attrs)
      end

    true ->
      do_create_marginalia(entry, user, attrs)
  end
end

defp do_create_marginalia(entry, user, attrs) do
  result =
    %Marginalia{}
    |> Marginalia.create_changeset(
      attrs
      |> Map.put("entry_id", entry.id)
      |> Map.put("user_id", user.id)
    )
    |> Repo.insert()

  case result do
    {:ok, marginalia} ->
      StrangepathsWeb.Endpoint.broadcast(
        "library_folio:#{entry.folio_id}",
        "new_marginalia",
        %{marginalia: Repo.preload(marginalia, :user), entry_id: entry.id}
      )
      {:ok, marginalia}

    error ->
      error
  end
end

defp marginalia_depth(nil), do: 0
defp marginalia_depth(parent_id) when is_integer(parent_id) do
  case Repo.get(Marginalia, parent_id) do
    nil -> 0
    parent -> 1 + marginalia_depth(parent.parent_id)
  end
end
```

**Run context tests to confirm no regressions:**

```bash
mix test test/strangepaths/library_test.exs
```

**Commit:**

```bash
git add lib/strangepaths/library.ex
git commit -m "liminal library phase 6a: marginalia context functions with PubSub and depth enforcement"
```
<!-- END_TASK_1 -->

<!-- START_TASK_2 -->
### Task 2: Context tests for marginalia additions

Add a new `describe "marginalia creation"` block to `test/strangepaths/library_test.exs`:

```elixir
describe "marginalia depth enforcement" do
  test "creates top-level marginalia" do
    user = user_typeface_fixture()
    folio = folio_fixture(user)
    entry = note_entry_fixture(folio, user)
    [tf | _] = Library.folio_editor_typefaces(user.id)

    {:ok, m} =
      Library.create_marginalia(entry, user, %{
        "content" => "Top level",
        "name" => tf.name,
        "font" => tf.font,
        "color" => tf.color
      })

    assert m.parent_id == nil
  end

  test "creates a reply (depth 1)" do
    user = user_typeface_fixture()
    folio = folio_fixture(user)
    entry = note_entry_fixture(folio, user)
    [tf | _] = Library.folio_editor_typefaces(user.id)

    {:ok, parent} =
      Library.create_marginalia(entry, user, %{
        "content" => "Top",
        "name" => tf.name,
        "font" => tf.font,
        "color" => tf.color
      })

    {:ok, child} =
      Library.create_marginalia(entry, user, %{
        "content" => "Reply",
        "name" => tf.name,
        "font" => tf.font,
        "color" => tf.color,
        "parent_id" => parent.id
      })

    assert child.parent_id == parent.id
  end

  test "rejects marginalia that would exceed max depth" do
    user = user_typeface_fixture()
    folio = folio_fixture(user)
    entry = note_entry_fixture(folio, user)
    [tf | _] = Library.folio_editor_typefaces(user.id)

    base_attrs = %{
      "content" => "x",
      "name" => tf.name,
      "font" => tf.font,
      "color" => tf.color
    }

    {:ok, m1} = Library.create_marginalia(entry, user, base_attrs)
    {:ok, m2} = Library.create_marginalia(entry, user, Map.put(base_attrs, "parent_id", m1.id))
    {:ok, m3} = Library.create_marginalia(entry, user, Map.put(base_attrs, "parent_id", m2.id))

    # Depth 3 (m3) should succeed; depth 4 (off m3) should fail
    assert {:error, :max_depth_exceeded} =
             Library.create_marginalia(entry, user, Map.put(base_attrs, "parent_id", m3.id))
  end
end
```

**Run:**

```bash
mix test test/strangepaths/library_test.exs
```
<!-- END_TASK_2 -->

<!-- END_SUBCOMPONENT_A -->

<!-- START_SUBCOMPONENT_B (tasks 3-4) -->

<!-- START_TASK_3 -->
### Task 3: Folio LiveView — marginalia state and events

**Extend `lib/strangepaths_web/live/library/folio_live.ex`:**

Add to `mount/3` after `@folio` assignment (requires the folio to have been found):

```elixir
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

socket
|> assign(:marginalia_flat_map, marginalia_flat_map)
|> assign(:expanded_entries, MapSet.new())
|> assign(:marginalia_form_entry_id, nil)
|> assign(:marginalia_reply_to_id, nil)
|> assign(:editor_typefaces, ...)  # already added in Phase 4
```

Note: `connected?/1` is a Phoenix LiveView helper that returns true only when the LiveView is connected over WebSocket (not the initial static render). Subscribing only when connected prevents dead-view subscription attempts.

**Add event handlers:**

```elixir
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
    {:noreply, socket}
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

    tf_id = attrs["typeface_id"] || (typefaces != [] && List.first(typefaces).id)
    tf = Enum.find(typefaces, &(&1.id == tf_id)) || List.first(typefaces)

    full_attrs =
      attrs
      |> Map.put("name", tf && tf.name || "")
      |> Map.put("font", tf && tf.font || "")
      |> Map.put("color", tf && tf.color || "")
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
  else
    {:noreply, socket}
  end
end

@impl true
def handle_info(%Phoenix.Socket.Broadcast{event: "new_marginalia", payload: %{marginalia: m, entry_id: entry_id}}, socket) do
  # Recompute the flat tree for this entry's marginalia
  all_for_entry = Map.get(socket.assigns.marginalia_flat_map, entry_id, [])
                  |> Enum.map(fn {item, _depth} -> item end)
  updated_flat = flatten_marginalia_tree(all_for_entry ++ [m])

  updated_map = Map.put(socket.assigns.marginalia_flat_map, entry_id, updated_flat)
  {:noreply, assign(socket, :marginalia_flat_map, updated_map)}
end
```
<!-- END_TASK_3 -->

<!-- START_TASK_4 -->
### Task 4: Template updates for marginalia

**Update `lib/strangepaths_web/live/library/folio_live.html.heex`:**

Add this marginalia block inside the `for entry <- @entries` loop, immediately AFTER each entry's display div (after the `:post_ref` / `:note` rendering):

```heex
<%# ── Marginalia thread for this entry ── %>
<div class="ml-4 mt-1">
  <%
    marginalia_with_depth = Map.get(@marginalia_flat_map, entry.id, [])
    count = length(marginalia_with_depth)
    is_expanded = MapSet.member?(@expanded_entries, entry.id)
  %>

  <%# Collapsed: count badge + toggle %>
  <button
    phx-click="toggle_marginalia_thread"
    phx-value-entry-id={entry.id}
    class="text-xs text-gray-600 hover:text-gray-400"
  >
    <%= cond do %>
    <% count == 0 -> %> ○ no marginalia
    <% is_expanded -> %> ▾ <%= count %> marginalia
    <% true -> %> ▸ <%= count %> marginalia
    <% end %>
  </button>

  <%= if is_expanded do %>
    <%# Thread display (flat list with depth-based indentation) %>
    <div class="mt-2 space-y-1">
      <%= for {m, depth} <- marginalia_with_depth do %>
        <div
          id={"marginalia-#{m.id}"}
          class="text-xs py-1 border-l-2 border-gray-800 pl-2"
          style={"margin-left: #{depth * 16}px; font-family: #{m.font}; color: #{m.color};"}
        >
          <span class="font-semibold"><%= m.name %></span>
          <span class="text-gray-500 ml-1 text-xs"><%= format_relative_time(m.inserted_at) %></span>

          <%= if @is_folio_editor do %>
            <button
              phx-click="open_marginalia_form"
              phx-value-entry-id={entry.id}
              phx-value-reply-to={m.id}
              class="ml-2 text-gray-600 hover:text-gray-400"
              title="Reply to this"
            >↩ Reply</button>
          <% end %>

          <%# Reply form inline when this is the reply target %>
          <%= if @marginalia_form_entry_id == entry.id && @marginalia_reply_to_id == m.id do %>
            <.form let={_f} for={%{}} as={:marginalia} phx-submit="submit_marginalia" class="mt-1">
              <%= if length(@editor_typefaces) > 1 do %>
                <select name="marginalia[typeface_id]" class="text-xs mb-1 bg-gray-900 border border-gray-700 rounded px-2 py-0.5">
                  <%= for tf <- @editor_typefaces do %>
                    <option value={tf.id}><%= tf.name %></option>
                  <% end %>
                </select>
              <% end %>
              <textarea
                name="marginalia[content]"
                placeholder="Reply..."
                class="w-full h-16 text-xs bg-gray-900 border border-gray-700 rounded px-2 py-1 resize-none"
              ></textarea>
              <div class="flex gap-2 mt-1">
                <button type="submit" class="text-xs px-2 py-0.5 bg-gray-700 rounded">Post Reply</button>
                <button type="button" phx-click="close_marginalia_form" class="text-xs text-gray-500">Cancel</button>
              </div>
            </.form>
          <% end %>

          <div class="mt-1"><%= raw render_library_content(m.content) %></div>
        </div>
      <% end %>
    </div>

    <%# Top-level marginalia form %>
    <%= if @is_folio_editor do %>
      <%= if @marginalia_form_entry_id == entry.id && is_nil(@marginalia_reply_to_id) do %>
        <.form let={f} for={%{}} as={:marginalia} phx-submit="submit_marginalia" class="mt-2">
          <%= if length(@editor_typefaces) > 1 do %>
            <select name="marginalia[typeface_id]" class="text-xs mb-1 bg-gray-900 border border-gray-700 rounded px-2 py-0.5">
              <%= for tf <- @editor_typefaces do %>
                <option value={tf.id} style={"font-family: #{tf.font}; color: #{tf.color};"}>
                  <%= tf.name %>
                </option>
              <% end %>
            </select>
          <% end %>
          <textarea
            name="marginalia[content]"
            placeholder="Add marginalia..."
            class="w-full h-20 text-xs bg-gray-900 border border-gray-700 rounded px-2 py-1 resize-none"
          ></textarea>
          <div class="flex gap-2 mt-1">
            <button type="submit" class="text-xs px-2 py-0.5 bg-gray-700 rounded">Post</button>
            <button type="button" phx-click="close_marginalia_form" class="text-xs text-gray-500 hover:text-gray-300">Cancel</button>
          </div>
        </.form>
      <% else %>
        <button
          phx-click="open_marginalia_form"
          phx-value-entry-id={entry.id}
          class="text-xs text-gray-600 hover:text-gray-400 mt-1"
        >
          + Annotate
        </button>
      <% end %>
    <% end %>
  <% end %>
</div>
```

**Add a `render_marginalia/7` function component or private helper to `folio_live.ex`:**

Since this is a recursive render (replies can have replies), implement it as a private function in `folio_live.ex`:

```elixir
# In folio_live.ex — private helpers
defp render_marginalia_list(m, all_marginalia, depth, assigns) do
  replies = Enum.filter(all_marginalia, &(&1.parent_id == m.id))
  indent = depth * 16  # pixels

  # Returns a rendered HTML string — used in template via raw()
  # But in LiveView .heex templates, we should use assigns and conditionals.
  # This approach doesn't work cleanly in .heex.
  # See the template approach below instead.
end
```

**Note on recursive rendering:** Direct recursive function calls don't work cleanly in `.heex` templates. Use a Phoenix function component instead, or flatten the rendering by pre-processing the tree structure in the LiveView before assigning.

**Recommended approach — flatten the tree in the LiveView:**

In the LiveView, pre-process marginalia into a display list with `depth` metadata:

```elixir
# In folio_live.ex — add a helper:
defp flatten_marginalia_tree(all, parent_id \\ nil, depth \\ 0) do
  children = Enum.filter(all, &(&1.parent_id == parent_id))
  Enum.flat_map(children, fn m ->
    [{m, depth}] ++ flatten_marginalia_tree(all, m.id, depth + 1)
  end)
end
```

Then in mount (and in handle_info after new marginalia arrive), compute a `@marginalia_flat_map` — a map from entry_id to `[{marginalia, depth}]` tuples:

```elixir
# In mount, replace marginalia_map with:
marginalia_flat_map =
  Library.list_all_marginalia_for_folio(folio.id)
  |> Enum.group_by(& &1.entry_id)
  |> Enum.map(fn {entry_id, items} ->
    {entry_id, flatten_marginalia_tree(items)}
  end)
  |> Map.new()

# In handle_info for new_marginalia:
def handle_info(%{event: "new_marginalia", payload: %{marginalia: m, entry_id: entry_id}}, socket) do
  # Recompute the flat tree for just this entry's marginalia
  all_for_entry = Map.get(socket.assigns.marginalia_flat_map, entry_id, [])
                  |> Enum.map(fn {item, _depth} -> item end)
  updated_flat = flatten_marginalia_tree(all_for_entry ++ [m])

  updated_map = Map.put(socket.assigns.marginalia_flat_map, entry_id, updated_flat)
  {:noreply, assign(socket, :marginalia_flat_map, updated_map)}
end
```


**Verify:**

```bash
mix compile --no-deps-check
```
<!-- END_TASK_4 -->

<!-- START_TASK_5 -->
### Task 5: Marginalia tests

**Create `test/strangepaths_web/live/library/marginalia_test.exs`:**

```elixir
defmodule StrangepathsWeb.LibraryLive.MarginaliaTest do
  use StrangepathsWeb.ConnCase

  import Phoenix.LiveViewTest
  import Strangepaths.AccountsFixtures
  import Strangepaths.LibraryFixtures

  alias Strangepaths.Library

  # Verifies: liminal-library.AC6.4 (collapsed by default)
  describe "marginalia collapse state" do
    test "marginalia threads are collapsed by default", %{conn: conn} do
      user = user_typeface_fixture()
      folio = folio_fixture(user, %{"title" => "Marginalia Collapse Test"})
      entry = note_entry_fixture(folio, user)
      m = marginalia_fixture(entry, user)

      conn2 = log_in_user(conn, user)
      {:ok, _view, html} = live(conn2, "/library/marginalia-collapse-test")

      # Count badge visible but content not rendered
      assert html =~ "1 marginalia"
      refute html =~ m.content
    end

    test "expanding a thread shows marginalia content (AC6.5)", %{conn: conn} do
      user = user_typeface_fixture()
      folio = folio_fixture(user, %{"title" => "Marginalia Expand Test"})
      entry = note_entry_fixture(folio, user)
      m = marginalia_fixture(entry, user, %{"content" => "Unique marginalia content xyz"})

      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, "/library/marginalia-expand-test")

      html =
        view
        |> element("button[phx-click='toggle_marginalia_thread'][phx-value-entry-id='#{entry.id}']")
        |> render_click()

      assert html =~ "Unique marginalia content xyz"
    end
  end

  # Verifies: liminal-library.AC6.1 (any folio editor can add)
  describe "adding marginalia" do
    test "folio editor can post marginalia on any folio", %{conn: conn} do
      author = user_typeface_fixture()
      other_editor = user_typeface_fixture()
      folio = folio_fixture(author, %{"title" => "Any Editor Marginalia"})
      entry = note_entry_fixture(folio, author)

      conn = log_in_user(conn, other_editor)
      {:ok, view, _html} = live(conn, "/library/any-editor-marginalia")

      # Expand entry thread
      view
      |> element("button[phx-click='toggle_marginalia_thread'][phx-value-entry-id='#{entry.id}']")
      |> render_click()

      # Open form
      view
      |> element("button[phx-click='open_marginalia_form'][phx-value-entry-id='#{entry.id}']")
      |> render_click()

      # Submit
      view
      |> form("form[phx-submit='submit_marginalia']",
        marginalia: %{content: "A new annotation"}
      )
      |> render_submit()

      entries = Library.list_all_marginalia_for_folio(folio.id)
      assert length(entries) == 1
      assert hd(entries).content == "A new annotation"
    end
  end

  # Verifies: liminal-library.AC6.7 (non-editor cannot add)
  describe "permission enforcement" do
    test "non-folio-editor does not see annotate button", %{conn: conn} do
      author = user_typeface_fixture()
      non_editor = user_fixture()
      folio = folio_fixture(author, %{"title" => "Non Editor View"})
      entry = note_entry_fixture(folio, author)

      conn = log_in_user(conn, non_editor)
      {:ok, view, _html} = live(conn, "/library/non-editor-view")

      html =
        view
        |> element("button[phx-click='toggle_marginalia_thread'][phx-value-entry-id='#{entry.id}']")
        |> render_click()

      refute html =~ "Annotate"
      refute html =~ "open_marginalia_form"
    end
  end

  # Verifies: liminal-library.AC6.6 (real-time)
  describe "real-time delivery" do
    test "new marginalia appear in real-time for other viewers", %{conn: conn} do
      author = user_typeface_fixture()
      other_editor = user_typeface_fixture()
      folio = folio_fixture(author, %{"title" => "Realtime Test Folio"})
      entry = note_entry_fixture(folio, author)

      # Open viewer session
      viewer_conn = log_in_user(conn, author)
      {:ok, viewer_view, _} = live(viewer_conn, "/library/realtime-test-folio")

      # Expand the entry thread
      viewer_view
      |> element("button[phx-click='toggle_marginalia_thread'][phx-value-entry-id='#{entry.id}']")
      |> render_click()

      # Create marginalia from the context directly (simulating another user)
      [tf | _] = Library.folio_editor_typefaces(other_editor.id)

      {:ok, _} =
        Library.create_marginalia(entry, other_editor, %{
          "content" => "Real-time annotation",
          "name" => tf.name,
          "font" => tf.font,
          "color" => tf.color
        })

      # LiveView should have received the broadcast
      html = render(viewer_view)
      assert html =~ "Real-time annotation"
    end
  end
end
```

**Run tests:**

```bash
mix test test/strangepaths_web/live/library/marginalia_test.exs
mix test
```

**Commit:**

```bash
git add lib/strangepaths/library.ex \
        lib/strangepaths_web/live/library/folio_live.ex \
        lib/strangepaths_web/live/library/folio_live.html.heex \
        test/strangepaths/library_test.exs \
        test/strangepaths_web/live/library/marginalia_test.exs
git commit -m "liminal library phase 6: marginalia system with PubSub and threading"
```
<!-- END_TASK_5 -->

<!-- END_SUBCOMPONENT_B -->
