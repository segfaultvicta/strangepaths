# Liminal Library Phase 7: Browse, Search & Aesthetic Polish

**Goal:** Full browse/search on the folio landing page, tag management UI on the folio view, and library-specific SCSS styles.

**Architecture:** `search_folios/1` in `Library` context uses sequential Ecto query composition (ILIKE, join-based tag filter) following the `cards.ex` / `scenes.ex` pattern. `FolioListLive` gains search/filter/sort assigns and a single phx-change search form. `FolioLive` gains add/remove tag event handlers (context functions already exist from Phase 1). A new `.library-*` SCSS section appended to `app.scss` (after the BBS block) establishes the visual identity.

**Tech Stack:** Ecto query composition, ILIKE + join-based tag search (no FTS), Phoenix LiveView, Tailwind CSS, SCSS

**Scope:** Phase 7 of 7

**Codebase verified:** 2026-04-27

---

## Acceptance Criteria Coverage

### liminal-library.AC7: Browse and search
- **liminal-library.AC7.1 Success:** Library search returns folios matching title, subtitle, body, or tags
- **liminal-library.AC7.2 Success:** Library search results never include scenes or codex pages
- **liminal-library.AC7.3 Success:** Results can be filtered by author and by tag, and sorted by date/title/author
- **liminal-library.AC7.4 Success:** Existing Scenes/Archive search returns unchanged results after this feature ships

### liminal-library.AC8: Tags and deletion
- **liminal-library.AC8.1 Success:** Any folio editor can add and remove tags on any folio; tags are stored lowercased and trimmed; duplicate adds are no-ops
- **liminal-library.AC8.2 Failure:** Non-folio-editor cannot add or remove tags

---

<!-- START_SUBCOMPONENT_A (tasks 1-3) -->

<!-- START_TASK_1 -->
### Task 1: `search_folios/1` context function

**Open `lib/strangepaths/library.ex`.**

Find the existing `list_folios/0` function (added in Phase 1). Add `search_folios/1` below it:

```elixir
@doc """
Search and filter folios. Returns a list of Folio structs with :user preloaded.

Options:
  - :query       - String to search title, subtitle, and body (ILIKE; nil or "" = no search)
  - :author_id   - Filter to folios by this user id (nil = all authors)
  - :tag         - Filter to folios with this tag (nil or "" = no tag filter)
  - :sort_by     - :date (newest first, default), :title (asc), :author (asc by nickname)
"""
def search_folios(opts \\ []) do
  query_str = Keyword.get(opts, :query)
  author_id = Keyword.get(opts, :author_id)
  tag_filter = Keyword.get(opts, :tag)
  sort_by = Keyword.get(opts, :sort_by, :date)

  query =
    from(f in Folio,
      join: u in Strangepaths.Accounts.User, on: u.id == f.user_id,
      preload: [user: u]
    )

  # Text search across title, subtitle, body
  query =
    if query_str && String.trim(query_str) != "" do
      pattern = "%#{query_str}%"

      from([f] in query,
        where:
          ilike(f.title, ^pattern) or
            ilike(f.subtitle, ^pattern) or
            ilike(f.body, ^pattern)
      )
    else
      query
    end

  # Author filter
  query =
    if author_id do
      from([f] in query, where: f.user_id == ^author_id)
    else
      query
    end

  # Tag filter — join FolioTag, ILIKE match, distinct to avoid duplicates
  query =
    if tag_filter && String.trim(tag_filter) != "" do
      tag_pattern = "%#{String.downcase(String.trim(tag_filter))}%"

      from([f] in query,
        join: ft in FolioTag, on: ft.folio_id == f.id,
        where: ilike(ft.tag, ^tag_pattern),
        distinct: f.id
      )
    else
      query
    end

  # Sort
  query =
    case sort_by do
      :title -> from([f, u] in query, order_by: [asc: f.title])
      :author -> from([f, u] in query, order_by: [asc: u.nickname, asc: f.title])
      _ -> from([f, u] in query, order_by: [desc: f.inserted_at])
    end

  Repo.all(query)
end
```

**Notes:**
- `[f, u]` binding in the sort cases works because the join was added as the second binding in the base query. Use `[f, _u]` if the compiler warns about unused binding.
- The `distinct: f.id` in the tag filter prevents returning the same folio multiple times when it matches multiple tag rows. Ecto accepts `:id` atom or `f.id` expression here.
- `FolioTag` — use the full module alias `Strangepaths.Library.FolioTag` or ensure it is aliased at the top of `library.ex` alongside the other schemas.
- This function searches only `Folio` rows — it cannot return scenes or codex pages by construction (AC7.2 is trivially satisfied).

**Verify compilation:**

```bash
mix compile --no-deps-check
```
<!-- END_TASK_1 -->

<!-- START_TASK_2 -->
### Task 2: FolioList LiveView — search, filter, and sort UI

**Open `lib/strangepaths_web/live/library/folio_list_live.ex`.**

This LiveView was created in Phase 3 with basic list functionality. Extend it:

**1. Update `mount/3` to add search-state assigns:**

```elixir
# In mount/3, after existing assigns, add:
|> assign(:search_query, "")
|> assign(:filter_author_id, nil)
|> assign(:filter_tag, "")
|> assign(:sort_by, :date)
|> assign(:all_users, Accounts.list_users())
# Replace existing @folios assign with search_folios([]):
|> assign(:folios, Library.search_folios([]))
```

**2. Add a helper to rebuild folios from current filter assigns:**

Add a private helper at the bottom of the module:

```elixir
defp rebuild_folios(socket) do
  opts =
    [
      query: socket.assigns.search_query,
      author_id: socket.assigns.filter_author_id,
      tag: socket.assigns.filter_tag,
      sort_by: socket.assigns.sort_by
    ]
    |> Enum.reject(fn {_k, v} -> v == nil or v == "" end)

  assign(socket, :folios, Library.search_folios(opts))
end
```

**3. Add event handlers:**

```elixir
@impl true
def handle_event("search", %{"query" => query, "tag" => tag, "author_id" => author_id_str, "sort_by" => sort_str}, socket) do
  sort_by = case sort_str do
    "title" -> :title
    "author" -> :author
    _ -> :date
  end

  author_id =
    case Integer.parse(author_id_str) do
      {id, ""} when id > 0 -> id
      _ -> nil
    end

  socket =
    socket
    |> assign(:search_query, query)
    |> assign(:filter_tag, tag)
    |> assign(:filter_author_id, author_id)
    |> assign(:sort_by, sort_by)
    |> rebuild_folios()

  {:noreply, socket}
end
```

**4. Open `lib/strangepaths_web/live/library/folio_list_live.html.heex`.**

Add the search/filter form above the folio list. Place it after the heading and before the folio list:

```heex
<form phx-change="search" phx-submit="search" class="library-search-bar mb-6">
  <div class="flex flex-wrap gap-3 items-end">
    <div class="flex-1 min-w-40">
      <label class="library-label">Search</label>
      <input
        type="text"
        name="query"
        value={@search_query}
        placeholder="title, body, or subtitle…"
        class="library-input w-full"
        phx-debounce="300"
      />
    </div>

    <div class="min-w-32">
      <label class="library-label">Tag</label>
      <input
        type="text"
        name="tag"
        value={@filter_tag}
        placeholder="filter by tag"
        class="library-input w-full"
        phx-debounce="300"
      />
    </div>

    <div class="min-w-40">
      <label class="library-label">Author</label>
      <select name="author_id" class="library-input">
        <option value="0">All authors</option>
        <%= for user <- @all_users do %>
          <option value={user.id} selected={@filter_author_id == user.id}><%= user.nickname %></option>
        <% end %>
      </select>
    </div>

    <div class="min-w-32">
      <label class="library-label">Sort</label>
      <select name="sort_by" class="library-input">
        <option value="date" selected={@sort_by == :date}>Newest</option>
        <option value="title" selected={@sort_by == :title}>Title</option>
        <option value="author" selected={@sort_by == :author}>Author</option>
      </select>
    </div>
  </div>
</form>
```

**Note on `phx-change="search"` with `phx-debounce`:** The `phx-debounce="300"` on individual inputs fires the form's phx-change event on that input after 300ms. The select elements will fire immediately on change (no debounce needed). This is the same pattern used in the cards filter (`cosmos` LiveView) and BBS board creation form.

**Note on empty search state:** When all filters are cleared (`query: ""`, `tag: ""`, `author_id: nil`), `rebuild_folios/1` calls `Library.search_folios([])` which returns all folios sorted by date — this is equivalent to the original `list_folios/0` call from Phase 3.

**Verify compilation:**

```bash
mix compile --no-deps-check
```
<!-- END_TASK_2 -->

<!-- START_TASK_3 -->
### Task 3: Tests for `search_folios/1`

Before writing tests, read `test/strangepaths/library_test.exs` (created in Phase 1) to see the test structure and which fixtures are available.

**Add to `test/strangepaths/library_test.exs`:**

```elixir
# Verifies: liminal-library.AC7.1, liminal-library.AC7.3
describe "search_folios/1" do
  setup do
    editor1 = user_fixture()
    editor2 = user_fixture()
    [tf | _] = Library.Typefaces.all()
    Library.assign_user_typeface(editor1.id, tf.id)
    Library.assign_user_typeface(editor2.id, tf.id)

    {:ok, folio1} = Library.create_folio(editor1, %{
      "title" => "The Crimson Archives",
      "subtitle" => "A history of the tribunal",
      "body" => "These records span three centuries of rulings."
    })

    {:ok, folio2} = Library.create_folio(editor2, %{
      "title" => "Amber Studies",
      "body" => "Notes on resonance theory."
    })

    # Add a tag to folio1
    Library.add_tag(folio1, "tribunal")
    Library.add_tag(folio1, "history")

    %{editor1: editor1, editor2: editor2, folio1: folio1, folio2: folio2}
  end

  test "returns all folios when no opts given", %{folio1: f1, folio2: f2} do
    results = Library.search_folios([])
    ids = Enum.map(results, & &1.id)
    assert f1.id in ids
    assert f2.id in ids
  end

  test "filters by title match", %{folio1: f1, folio2: f2} do
    results = Library.search_folios(query: "Crimson")
    ids = Enum.map(results, & &1.id)
    assert f1.id in ids
    refute f2.id in ids
  end

  test "filters by subtitle match", %{folio1: f1} do
    results = Library.search_folios(query: "tribunal")
    ids = Enum.map(results, & &1.id)
    assert f1.id in ids
  end

  test "filters by body match", %{folio2: f2} do
    results = Library.search_folios(query: "resonance")
    ids = Enum.map(results, & &1.id)
    assert f2.id in ids
  end

  test "filters by author_id", %{editor1: ed1, folio1: f1, folio2: f2} do
    results = Library.search_folios(author_id: ed1.id)
    ids = Enum.map(results, & &1.id)
    assert f1.id in ids
    refute f2.id in ids
  end

  test "filters by tag", %{folio1: f1, folio2: f2} do
    results = Library.search_folios(tag: "history")
    ids = Enum.map(results, & &1.id)
    assert f1.id in ids
    refute f2.id in ids
  end

  test "sort_by :title returns folios alphabetically", %{folio1: f1, folio2: f2} do
    results = Library.search_folios(sort_by: :title)
    # "Amber" < "Crimson" alphabetically
    [first | _] = results
    assert first.id == f2.id
  end

  test "sort_by :date returns newest first" do
    # folio2 was inserted after folio1 in the setup
    results = Library.search_folios(sort_by: :date)
    ids = Enum.map(results, & &1.id)
    # Both folios present; since folio2 was inserted last, it should appear first
    assert length(results) >= 2
    assert List.first(ids) != nil
  end

  # Verifies: liminal-library.AC7.2
  test "results contain only Folio structs, not scenes or other types" do
    results = Library.search_folios(query: "")
    for r <- results do
      assert %Library.Folio{} = r
    end
  end

  # Verifies: liminal-library.AC7.4
  test "Scenes archive search returns same results after library feature exists" do
    # Calling Scenes.search_archived_scenes with a query that won't match library folios
    # This verifies the function signature and return type haven't changed.
    results = Strangepaths.Scenes.search_archived_scenes("crimson archives", nil, false, false, nil, nil)
    # Should return a list (may be empty); key assertion is no crash and no folios in result
    assert is_list(results)
  end
end
```

**Note on the AC7.4 test:** The `search_archived_scenes/6` call verifies the function still works with its existing arity and returns a list. Since the Library context is entirely separate from `Scenes`, there's no risk of cross-contamination — this test documents that intent.

**Note on `sort_by: :date` test:** Insertion order in tests can be non-deterministic if both inserts happen in the same millisecond. If this test is flaky, remove it and rely on the `:title` test for sort coverage, or assert only that both folios are present.

**Run these tests:**

```bash
mix test test/strangepaths/library_test.exs
```

**Commit:**

```bash
git add lib/strangepaths/library.ex \
        lib/strangepaths_web/live/library/folio_list_live.ex \
        lib/strangepaths_web/live/library/folio_list_live.html.heex \
        test/strangepaths/library_test.exs
git commit -m "liminal library phase 7: search_folios/1 and FolioList search/filter UI"
```
<!-- END_TASK_3 -->

<!-- END_SUBCOMPONENT_A -->

<!-- START_SUBCOMPONENT_B (tasks 4-5) -->

<!-- START_TASK_4 -->
### Task 4: Tag management UI in FolioLive

The `Library.add_tag/2` and `Library.remove_tag/2` context functions exist from Phase 1. Phase 3 built the FolioLive LiveView and template. This task adds the UI wiring.

**Open `lib/strangepaths_web/live/library/folio_live.ex`.**

Add two event handlers:

```elixir
@impl true
def handle_event("add_tag", %{"tag" => raw_tag}, socket) do
  tag = raw_tag |> String.downcase() |> String.trim()

  if socket.assigns.is_folio_editor && tag != "" do
    Library.add_tag(socket.assigns.folio, tag)
    folio = Library.get_folio_by_slug(socket.assigns.folio.slug)
    {:noreply, assign(socket, :folio, folio)}
  else
    {:noreply, socket}
  end
end

@impl true
def handle_event("remove_tag", %{"tag" => tag}, socket) do
  if socket.assigns.is_folio_editor do
    Library.remove_tag(socket.assigns.folio, tag)
    folio = Library.get_folio_by_slug(socket.assigns.folio.slug)
    {:noreply, assign(socket, :folio, folio)}
  else
    {:noreply, socket}
  end
end
```

**Notes:**
- Tag normalization (downcase + trim) is applied client-side here AND in `add_tag/2` in the context — no harm in double-normalizing.
- `get_folio_by_slug/1` returns `nil` for unknown slugs. The folio is known valid at this point, so the nil case cannot occur. No guard needed.
- `is_folio_editor` check in the event handler is a defense-in-depth guard. The template already hides the form from non-editors.

**Open `lib/strangepaths_web/live/library/folio_live.html.heex`.**

Find the existing folio header area (where title is displayed). Add a tags section below the subtitle (or at the bottom of the header section):

```heex
<div class="library-tags-row mt-3 flex flex-wrap gap-2 items-center">
  <%= for tag <- (@folio.tags || []) do %>
    <span class="library-tag inline-flex items-center gap-1">
      <span>#<%= tag %></span>
      <%= if @is_folio_editor do %>
        <button
          phx-click="remove_tag"
          phx-value-tag={tag}
          class="library-tag-remove"
          title={"Remove tag ##{tag}"}
        >×</button>
      <% end %>
    </span>
  <% end %>

  <%= if @is_folio_editor do %>
    <form phx-submit="add_tag" class="inline-flex items-center gap-1">
      <input
        type="text"
        name="tag"
        placeholder="add tag…"
        maxlength="50"
        class="library-tag-input"
        autocomplete="off"
      />
      <button type="submit" class="library-tag-add-btn">+</button>
    </form>
  <% end %>
</div>
```

**Notes:**
- `@folio.tags` requires the folio to have tags preloaded. The `get_folio_by_slug/1` function used in FolioLive's mount must preload the `folio_tags` association. Verify `folio_live.ex`'s mount uses a preload that includes tags — if `get_folio_by_slug/1` was written in Phase 1 without a tags preload, add it now. Check `lib/strangepaths/library.ex` and add `preload: [:user, :folio_tags]` to that query. The template references `@folio.tags` — you'll need a virtual field OR a separate assign. See the note below.

**Note on `@folio.tags`:** The `library_folio_tags` table stores tags as rows in `FolioTag`. To get a flat list of tag strings for rendering, you have two options:

1. **Preload `folio_tags` association, add a virtual field in Folio schema** — add `field :tags, {:array, :string}, virtual: true` to `Folio` schema, then compute it from the preloaded association after loading.

2. **Add a separate assign `@folio_tags`** — in mount and after add/remove, compute `folio_tags = Library.list_folio_tags(folio.id)` and assign separately.

Option 2 is simpler without schema changes. Add to `folio_live.ex`:

```elixir
# Helper at bottom of module
defp load_folio_tags(socket) do
  tags = Library.list_folio_tags(socket.assigns.folio.id)
  assign(socket, :folio_tags, tags)
end
```

Add `Library.list_folio_tags/1` to `library.ex`:

```elixir
def list_folio_tags(folio_id) do
  from(ft in FolioTag, where: ft.folio_id == ^folio_id, select: ft.tag, order_by: ft.tag)
  |> Repo.all()
end
```

Then update the template to use `@folio_tags` instead of `@folio.tags`.

Call `load_folio_tags(socket)` in mount after assigning `:folio`, and call it again after `add_tag` and `remove_tag` events in place of the `get_folio_by_slug` reload (no need to reload the full folio just for tag changes):

```elixir
def handle_event("add_tag", %{"tag" => raw_tag}, socket) do
  tag = raw_tag |> String.downcase() |> String.trim()

  if socket.assigns.is_folio_editor && tag != "" do
    Library.add_tag(socket.assigns.folio, tag)
    {:noreply, load_folio_tags(socket)}
  else
    {:noreply, socket}
  end
end

def handle_event("remove_tag", %{"tag" => tag}, socket) do
  if socket.assigns.is_folio_editor do
    Library.remove_tag(socket.assigns.folio, tag)
    {:noreply, load_folio_tags(socket)}
  else
    {:noreply, socket}
  end
end
```

**Verify compilation:**

```bash
mix compile --no-deps-check
```

**Tests — add to `test/strangepaths_web/live/library/folio_live_test.exs`** (created in Phase 3):

```elixir
# Verifies: liminal-library.AC8.1
describe "tag management" do
  test "folio editor can add a tag", %{conn: conn} do
    editor = editor_fixture()
    folio = folio_fixture(editor)
    conn = log_in_user(conn, editor)
    {:ok, view, _html} = live(conn, "/library/#{folio.slug}")

    view
    |> form("form[phx-submit='add_tag']", %{tag: "mythology"})
    |> render_submit()

    tags = Library.list_folio_tags(folio.id)
    assert "mythology" in tags
  end

  test "tag is stored lowercased", %{conn: conn} do
    editor = editor_fixture()
    folio = folio_fixture(editor)
    conn = log_in_user(conn, editor)
    {:ok, view, _html} = live(conn, "/library/#{folio.slug}")

    view
    |> form("form[phx-submit='add_tag']", %{tag: "  RITES  "})
    |> render_submit()

    tags = Library.list_folio_tags(folio.id)
    assert "rites" in tags
    refute "  RITES  " in tags
  end

  test "duplicate add is a no-op", %{conn: conn} do
    editor = editor_fixture()
    folio = folio_fixture(editor)
    Library.add_tag(folio, "ritual")
    conn = log_in_user(conn, editor)
    {:ok, view, _html} = live(conn, "/library/#{folio.slug}")

    view
    |> form("form[phx-submit='add_tag']", %{tag: "ritual"})
    |> render_submit()

    tags = Library.list_folio_tags(folio.id)
    assert Enum.count(tags, &(&1 == "ritual")) == 1
  end

  test "folio editor can remove a tag", %{conn: conn} do
    editor = editor_fixture()
    folio = folio_fixture(editor)
    Library.add_tag(folio, "purgatory")
    conn = log_in_user(conn, editor)
    {:ok, view, _html} = live(conn, "/library/#{folio.slug}")

    view
    |> element("button[phx-value-tag='purgatory']")
    |> render_click()

    tags = Library.list_folio_tags(folio.id)
    refute "purgatory" in tags
  end

  # Verifies: liminal-library.AC8.2
  test "non-folio-editor sees no add/remove tag UI", %{conn: conn} do
    editor = editor_fixture()
    folio = folio_fixture(editor)
    non_editor = user_fixture()   # no typeface assigned
    Library.add_tag(folio, "visible-tag")
    conn = log_in_user(conn, non_editor)
    {:ok, _view, html} = live(conn, "/library/#{folio.slug}")

    refute html =~ "phx-submit=\"add_tag\""
    refute html =~ "phx-click=\"remove_tag\""
    # Tag text still visible (read-only)
    assert html =~ "visible-tag"
  end
end
```

**Add fixtures to `test/support/fixtures/library_fixtures.ex`:**

Before writing tests, add these fixture helpers to the `Strangepaths.LibraryFixtures` module (created in Phase 1):

```elixir
def editor_fixture(attrs \\ %{}) do
  user = user_fixture(attrs)
  [tf | _] = Strangepaths.Library.Typefaces.all()
  Strangepaths.Library.assign_user_typeface(user.id, tf.id)
  user
end

def folio_fixture(user, attrs \\ %{}) do
  attrs = Map.merge(%{"title" => "Test Folio #{System.unique_integer()}"}, attrs)
  {:ok, folio} = Strangepaths.Library.create_folio(user, attrs)
  folio
end
```

These provide shorthand for setting up test data with pre-assigned typefaces.

**Run tests:**

```bash
mix test test/strangepaths_web/live/library/folio_live_test.exs
```

**Commit:**

```bash
git add lib/strangepaths/library.ex \
        lib/strangepaths_web/live/library/folio_live.ex \
        lib/strangepaths_web/live/library/folio_live.html.heex \
        test/strangepaths_web/live/library/folio_live_test.exs
git commit -m "liminal library phase 7: tag management UI on folio view"
```
<!-- END_TASK_4 -->

<!-- START_TASK_5 -->
### Task 5: Library-specific SCSS styles

**Open `assets/css/app.scss`.** Append the following block at the very end of the file (after the final `}` of the BBS Tippy theme block, currently around line 1609):

```scss
/* ============================================================
   LIMINAL LIBRARY
   ============================================================ */

/* CSS variable for library typography */
:root {
    --library-font: Georgia, "Times New Roman", serif;
    --library-accent: #b8975a;    /* warm amber */
    --library-accent-muted: #7a6038;
    --library-bg: #0c0b08;
    --library-surface: #141209;
    --library-border: #2a2416;
    --library-text: #d4c9a8;
    --library-text-muted: #7a7060;
}

/* Root wrapper — all library pages */
.library-root {
    font-family: var(--library-font);
    background-color: var(--library-bg);
    color: var(--library-text);
    min-height: 100vh;
}

/* Folio header area */
.library-folio-title {
    font-size: 1.6rem;
    font-weight: normal;
    color: var(--library-accent);
    letter-spacing: 0.02em;
}

.library-folio-subtitle {
    font-size: 1rem;
    color: var(--library-text-muted);
    font-style: italic;
    margin-top: 0.2rem;
}

/* Rendered body prose */
.library-body {
    line-height: 1.8;
    color: var(--library-text);
    font-size: 0.95rem;

    p {
        margin-bottom: 1em;
    }

    code {
        font-size: 0.85em;
        background: var(--library-surface);
        padding: 0.1em 0.3em;
        border-radius: 2px;
    }
}

/* Entry stream */
.library-entry {
    padding: 0.75rem 0;
    border-bottom: 1px solid var(--library-border);

    &:last-child {
        border-bottom: none;
    }
}

.library-entry-note {
    font-style: italic;
    color: var(--library-text-muted);
    padding-left: 1rem;
    border-left: 2px solid var(--library-border);
}

/* Marginalia */
.library-marginalia-toggle {
    font-size: 0.75rem;
    color: var(--library-text-muted);
    cursor: pointer;
    user-select: none;

    &:hover {
        color: var(--library-accent);
    }
}

.library-marginalia-thread {
    margin-top: 0.5rem;
    padding: 0.5rem 0 0.5rem 0.5rem;
    border-left: 2px solid var(--library-accent-muted);
}

.library-marginalia-item {
    font-size: 0.85rem;
    line-height: 1.6;
    color: var(--library-text);
    padding: 0.3rem 0;
}

.library-marginalia-meta {
    font-size: 0.75rem;
    color: var(--library-text-muted);
    margin-bottom: 0.15rem;
}

/* Tag badges */
.library-tag {
    display: inline-flex;
    align-items: center;
    gap: 0.25rem;
    font-size: 0.75rem;
    padding: 0.15rem 0.5rem;
    border-radius: 999px;
    background: var(--library-surface);
    border: 1px solid var(--library-border);
    color: var(--library-accent-muted);
}

.library-tag-remove {
    font-size: 0.8rem;
    line-height: 1;
    color: var(--library-text-muted);
    cursor: pointer;
    padding: 0 0.1rem;

    &:hover {
        color: #e05050;
    }
}

/* Search/filter form */
.library-search-bar {
    background: var(--library-surface);
    border: 1px solid var(--library-border);
    border-radius: 4px;
    padding: 0.75rem 1rem;
}

.library-label {
    display: block;
    font-size: 0.7rem;
    letter-spacing: 0.08em;
    text-transform: uppercase;
    color: var(--library-text-muted);
    margin-bottom: 0.25rem;
}

.library-input {
    background: var(--library-bg);
    border: 1px solid var(--library-border);
    border-radius: 2px;
    color: var(--library-text);
    font-family: var(--library-font);
    font-size: 0.875rem;
    padding: 0.35rem 0.6rem;

    &:focus {
        outline: none;
        border-color: var(--library-accent-muted);
    }
}

.library-tag-input {
    @extend .library-input;
    width: 8rem;
    font-size: 0.8rem;
    padding: 0.2rem 0.4rem;
}

.library-tag-add-btn {
    font-size: 1rem;
    line-height: 1;
    color: var(--library-accent-muted);
    padding: 0 0.4rem;
    cursor: pointer;

    &:hover {
        color: var(--library-accent);
    }
}

/* Folio list — individual folio row */
.library-folio-row {
    padding: 0.75rem 0;
    border-bottom: 1px solid var(--library-border);

    &:hover {
        background: var(--library-surface);
    }
}

.library-folio-row-title {
    color: var(--library-accent);
    font-size: 1rem;

    &:hover {
        color: #d4a84a;
    }
}

.library-folio-row-meta {
    font-size: 0.75rem;
    color: var(--library-text-muted);
    margin-top: 0.2rem;
}
```

**Apply `.library-root` to library page templates.** Open each library LiveView template and add `class="library-root p-6"` (or equivalent) to the outermost `<div>`:

- `lib/strangepaths_web/live/library/folio_list_live.html.heex`
- `lib/strangepaths_web/live/library/folio_live.html.heex`
- `lib/strangepaths_web/live/library/admin_live.html.heex`
- `lib/strangepaths_web/live/library/composer_live.html.heex`

Replace `class="p-6"` with `class="library-root p-6"` in each.

**Apply semantic classes to folio list template.** In `folio_list_live.html.heex`, update the folio list rows to use `.library-folio-row` and `.library-folio-row-title` in place of any Tailwind utility classes already there from Phase 3.

**Apply semantic classes to folio view template.** In `folio_live.html.heex`, update:
- Title element: add `class="library-folio-title"`
- Subtitle element: add `class="library-folio-subtitle"`
- Body rendered output: wrap in `<div class="library-body">`
- Entries container: each entry wrapper gets `class="library-entry"`
- Note-type entries: add `class="library-entry-note"` to the note content div
- Marginalia toggle button: add `class="library-marginalia-toggle"`
- Marginalia thread container: add `class="library-marginalia-thread"`
- Each marginalia item: add `class="library-marginalia-item"`

**Notes on `@extend`:** Dart Sass supports `@extend`. The `library-tag-input` class extends `library-input` — this avoids duplicating the shared properties. If the project uses LibSass or a different processor, replace `@extend .library-input;` with the actual property list copied from `.library-input`.

**Build assets to verify SCSS compiles:**

```bash
mix assets.build
```

No errors expected. If Dart Sass reports an error on `@extend` crossing file contexts, replace the `@extend` with inline properties.

**Final test run:**

```bash
mix test
```

All tests should pass.

**Commit:**

```bash
git add assets/css/app.scss \
        lib/strangepaths_web/live/library/folio_list_live.html.heex \
        lib/strangepaths_web/live/library/folio_live.html.heex \
        lib/strangepaths_web/live/library/admin_live.html.heex \
        lib/strangepaths_web/live/library/composer_live.html.heex
git commit -m "liminal library phase 7: library SCSS styles and class application"
```
<!-- END_TASK_5 -->

<!-- END_SUBCOMPONENT_B -->
