# Liminal Library Phase 3: Folio View & Basic CRUD

**Goal:** Folios can be created, viewed, and deleted. Title/subtitle inline editing for author/dragon. Permission enforcement in place.

**Architecture:** Two new LiveViews — `LibraryLive.FolioList` (landing + creation, `:index`/`:new` actions) and `LibraryLive.Folio` (view, `:show` action). Follows BBS ThreadList/Thread LiveView patterns. Slug-based routing with nil-check redirect on not-found.

**Tech Stack:** Phoenix LiveView, Ecto, existing `render_library_content/2` and `render_post_content/2`

**Scope:** Phase 3 of 7

**Codebase verified:** 2026-04-27

---

## Acceptance Criteria Coverage

### liminal-library.AC2: Folio creation
- **liminal-library.AC2.1 Success:** Folio editor can create a folio with a unique title and optional subtitle
- **liminal-library.AC2.2 Success:** Slug is auto-generated from title (lowercased, hyphenated)
- **liminal-library.AC2.3 Failure:** Duplicate title returns a validation error
- **liminal-library.AC2.4 Success:** Folio with body only (no entries) is valid and viewable
- **liminal-library.AC2.5 Success:** Folio with entries only (no body) is valid and viewable
- **liminal-library.AC2.6 Failure:** Non-folio-editor cannot access folio creation

### liminal-library.AC5: Entry permissions
- **liminal-library.AC5.2 Success:** Folio author (and dragon) can reorder, delete, and edit entries in their folio
- **liminal-library.AC5.3 Failure:** Non-author folio editor cannot reorder, delete, or edit existing entries

_(Phase 3 implements the title/subtitle aspect of AC5.2/AC5.3; full entry management is Phase 5.)_

### liminal-library.AC8: Tags and deletion
- **liminal-library.AC8.3 Success:** Dragon can delete any folio
- **liminal-library.AC8.4 Failure:** Non-dragon user cannot delete a folio

---

<!-- START_SUBCOMPONENT_A (tasks 1-3) -->

<!-- START_TASK_1 -->
### Task 1: Library context additions and router updates

**A. Add functions to `lib/strangepaths/library.ex`:**

Add `get_folio_by_slug/1` (non-bang, returns nil on not found) and update `list_entries/1` to preload the scene post's user:

```elixir
# Under the FOLIOS section, add after get_folio_by_slug!/1:
def get_folio_by_slug(slug) do
  case Repo.get_by(Folio, slug: slug) do
    nil -> nil
    folio -> Repo.preload(folio, :user)
  end
end
```

Update `list_entries/1` to preload nested associations:

```elixir
def list_entries(folio_id) do
  from(e in Entry,
    where: e.folio_id == ^folio_id,
    order_by: e.position,
    preload: [scene_post: [:user]]   # ← was just [:scene_post]
  )
  |> Repo.all()
end
```

**B. Add routes to `lib/strangepaths_web/router.ex`:**

In the main browser scope, add the remaining library routes **before** the `/library/admin` line you added in Phase 2 (so the more-specific `/library/admin` is defined before the catch-all `/library/:slug`):

```elixir
live("/library", LibraryLive.FolioList, :index)
live("/library/new", LibraryLive.FolioList, :new)
live("/library/:slug", LibraryLive.Folio, :show)
# /library/admin was added in Phase 2 — must remain AFTER /library/:slug would match
```

Wait — route order matters in Phoenix. `/library/admin` must be defined **before** `/library/:slug` to prevent `/library/admin` from being matched as `slug: "admin"`. Verify the order in the file: admin before `:slug`.

**Verify:**

```bash
mix compile --no-deps-check
```
<!-- END_TASK_1 -->

<!-- START_TASK_2 -->
### Task 2: `LibraryLive.FolioList` LiveView

**Create `lib/strangepaths_web/live/library/folio_list_live.ex`:**

```elixir
defmodule StrangepathsWeb.LibraryLive.FolioList do
  use StrangepathsWeb, :live_view

  alias Strangepaths.Library

  @impl true
  def mount(_params, session, socket) do
    socket = assign_defaults(session, socket)
    user = socket.assigns.current_user
    folios = Library.list_folios()

    {:ok,
     socket
     |> assign(:page_title, "The Liminal Library")
     |> assign(:folios, folios)
     |> assign(:folio_changeset, nil)
     |> assign(:is_folio_editor, user != nil && Library.is_folio_editor?(user.id))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
  end

  defp apply_action(socket, :new, _params) do
    if socket.assigns.current_user && Library.is_folio_editor?(socket.assigns.current_user.id) do
      socket
      |> assign(:page_title, "New Folio")
      |> assign(:folio_changeset, Library.change_folio())
    else
      socket
      |> put_flash(:error, "You must be a folio editor to create folios.")
      |> push_patch(to: "/library")
    end
  end

  @impl true
  def handle_event("validate_folio", %{"folio" => attrs}, socket) do
    changeset =
      Library.change_folio(%Strangepaths.Library.Folio{}, attrs)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :folio_changeset, changeset)}
  end

  def handle_event("create_folio", %{"folio" => attrs}, socket) do
    user = socket.assigns.current_user

    if user && Library.is_folio_editor?(user.id) do
      case Library.create_folio(user, attrs) do
        {:ok, folio} ->
          {:noreply,
           socket
           |> put_flash(:info, "Folio created.")
           |> push_redirect(to: "/library/#{folio.slug}")}

        {:error, changeset} ->
          {:noreply, assign(socket, :folio_changeset, changeset)}
      end
    else
      {:noreply, socket |> put_flash(:error, "Unauthorized") |> push_patch(to: "/library")}
    end
  end
end
```

**Create `lib/strangepaths_web/live/library/folio_list_live.html.heex`:**

```heex
<div class="p-6 max-w-4xl mx-auto">
  <div class="flex items-center justify-between mb-6">
    <h1 class="text-3xl font-bold">The Liminal Library</h1>
    <%= if @is_folio_editor do %>
      <%= live_patch("+ New Folio", to: Routes.live_path(@socket, StrangepathsWeb.LibraryLive.FolioList, :new), class: "btn-secondary text-sm") %>
    <% end %>
  </div>

  <%= if @live_action == :new && @folio_changeset do %>
    <div class="mb-8 p-4 border border-gray-700 rounded">
      <h2 class="text-lg font-semibold mb-4">New Folio</h2>
      <.form let={f} for={@folio_changeset} phx-change="validate_folio" phx-submit="create_folio">
        <div class="mb-4">
          <%= label f, :title, "Title", class: "block text-sm font-medium mb-1" %>
          <%= text_input f, :title, placeholder: "Folio title", class: "w-full bg-gray-900 border border-gray-700 rounded px-3 py-2", required: true %>
          <%= error_tag f, :title %>
        </div>
        <div class="mb-4">
          <%= label f, :subtitle, "Subtitle (optional)", class: "block text-sm font-medium mb-1" %>
          <%= text_input f, :subtitle, placeholder: "Optional subtitle", class: "w-full bg-gray-900 border border-gray-700 rounded px-3 py-2" %>
          <%= error_tag f, :subtitle %>
        </div>
        <div class="flex gap-2">
          <%= submit "Create Folio", class: "btn-primary" %>
          <%= live_patch "Cancel", to: Routes.live_path(@socket, StrangepathsWeb.LibraryLive.FolioList, :index), class: "btn-secondary" %>
        </div>
      </.form>
    </div>
  <% end %>

  <%= if Enum.empty?(@folios) do %>
    <p class="text-gray-500 italic">No folios yet. The archive awaits its first entry.</p>
  <% else %>
    <div class="space-y-3">
      <%= for folio <- @folios do %>
        <div class="p-4 border border-gray-800 rounded hover:border-gray-600">
          <%= live_redirect folio.title, to: "/library/#{folio.slug}", class: "text-lg font-medium hover:underline" %>
          <%= if folio.subtitle do %>
            <p class="text-sm text-gray-400 mt-1"><%= folio.subtitle %></p>
          <% end %>
          <p class="text-xs text-gray-600 mt-1">
            <%= folio.inserted_at && format_relative_time(folio.inserted_at) %>
          </p>
        </div>
      <% end %>
    </div>
  <% end %>
</div>
```

Note: Module aliases from the LiveView are not automatically available in .heex templates. The template must use the `@is_folio_editor` boolean assign instead of calling `Library.is_folio_editor?/1` directly. This assign is set in `mount/3`:

```elixir
# In mount, add:
|> assign(:is_folio_editor, user != nil && Library.is_folio_editor?(user.id))
```

Then in the template, use `@is_folio_editor` instead of the function call. Apply this pattern everywhere in the Phase 3 templates.

**Verify:**

```bash
mix compile --no-deps-check
```
<!-- END_TASK_2 -->

<!-- START_TASK_3 -->
### Task 3: FolioList tests

**Create `test/strangepaths_web/live/library/folio_list_live_test.exs`:**

```elixir
defmodule StrangepathsWeb.LibraryLive.FolioListTest do
  use StrangepathsWeb.ConnCase

  import Phoenix.LiveViewTest
  import Strangepaths.AccountsFixtures
  import Strangepaths.LibraryFixtures

  alias Strangepaths.Library

  defp dragon_fixture do
    {:ok, user} = Strangepaths.Accounts.register_dragon(valid_user_attributes())
    user
  end

  # Verifies: liminal-library.AC2.4, AC2.5 (library index shows folios)
  describe "GET /library" do
    test "shows empty state when no folios exist", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/library")
      assert html =~ "archive awaits"
    end

    test "shows existing folios", %{conn: conn} do
      folio = folio_fixture(nil, %{"title" => "Test Folio Title"})
      {:ok, _view, html} = live(conn, "/library")
      assert html =~ "Test Folio Title"
    end

    test "shows New Folio button for folio editors", %{conn: conn} do
      user = user_typeface_fixture()
      conn = log_in_user(conn, user)
      {:ok, _view, html} = live(conn, "/library")
      assert html =~ "New Folio"
    end

    test "does not show New Folio button for non-editors", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      {:ok, _view, html} = live(conn, "/library")
      refute html =~ "New Folio"
    end
  end

  # Verifies: liminal-library.AC2.6
  describe "GET /library/new — permission enforcement" do
    test "non-folio-editor is redirected with flash", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, "/library/new")
      assert_patch(view, "/library")
    end

    test "unauthenticated user is redirected", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/library/new")
      assert_patch(view, "/library")
    end

    test "folio editor can access creation form", %{conn: conn} do
      user = user_typeface_fixture()
      conn = log_in_user(conn, user)

      {:ok, _view, html} = live(conn, "/library/new")
      assert html =~ "New Folio"
      assert html =~ "Title"
    end
  end

  # Verifies: liminal-library.AC2.1, AC2.2
  describe "create_folio event" do
    test "creates folio and redirects to view page", %{conn: conn} do
      user = user_typeface_fixture()
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, "/library/new")

      html =
        view
        |> form("form", folio: %{title: "The Weight of Names", subtitle: "A Collection"})
        |> render_submit()

      # Should redirect to the folio view
      assert {path, _flash} = assert_redirect(view)
      assert path =~ "/library/the-weight-of-names"

      # Folio exists in DB
      assert Library.get_folio_by_slug("the-weight-of-names")
    end

    # Verifies: liminal-library.AC2.2
    test "slug is auto-generated from title" do
      user = user_typeface_fixture()
      {:ok, folio} = Library.create_folio(user, %{"title" => "Letters From Afar"})
      assert folio.slug == "letters-from-afar"
    end

    # Verifies: liminal-library.AC2.3
    test "duplicate title shows validation error", %{conn: conn} do
      user = user_typeface_fixture()
      folio_fixture(user, %{"title" => "Duplicate Title"})

      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, "/library/new")

      html =
        view
        |> form("form", folio: %{title: "Duplicate Title"})
        |> render_submit()

      assert html =~ "has already been taken"
    end
  end
end
```

**Run:**

```bash
mix test test/strangepaths_web/live/library/folio_list_live_test.exs
```

Fix any failures before proceeding. Common issues:
- `assert_patch` vs `assert_redirect` — check which Phoenix LiveViewTest function matches the push type used in apply_action (`:new` uses `push_patch` back to `:index`)
- `form/3` selector — adjust if the form has a different `id` attribute
<!-- END_TASK_3 -->

<!-- END_SUBCOMPONENT_A -->

<!-- START_SUBCOMPONENT_B (tasks 4-5) -->

<!-- START_TASK_4 -->
### Task 4: `LibraryLive.Folio` view LiveView

**Create `lib/strangepaths_web/live/library/folio_live.ex`:**

```elixir
defmodule StrangepathsWeb.LibraryLive.Folio do
  use StrangepathsWeb, :live_view
  import StrangepathsWeb.SceneHelpers, only: [render_post_content: 2]

  alias Strangepaths.Library

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
        tags = Library.list_tags(folio.id)

        {:ok,
         socket
         |> assign(:page_title, folio.title)
         |> assign(:folio, folio)
         |> assign(:entries, entries)
         |> assign(:tags, tags)
         |> assign(:editing_title, false)
         |> assign(:title_changeset, Library.change_folio(folio))
         |> assign(:is_author, user != nil && folio.user_id == user.id)
         |> assign(:is_dragon, user != nil && user.role == :dragon)
         |> assign(:is_folio_editor, user != nil && Library.is_folio_editor?(user.id))}
    end
  end

  @impl true
  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  @impl true
  def handle_event("start_edit_title", _params, socket) do
    if socket.assigns.is_author || socket.assigns.is_dragon do
      {:noreply, assign(socket, :editing_title, true)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("cancel_edit_title", _params, socket) do
    {:noreply, assign(socket, :editing_title, false)}
  end

  def handle_event("save_title", %{"folio" => attrs}, socket) do
    if socket.assigns.is_author || socket.assigns.is_dragon do
      case Library.update_folio_title(socket.assigns.folio, attrs) do
        {:ok, updated_folio} ->
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
      {:noreply, socket}
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
      {:noreply, socket}
    end
  end
end
```

**Create `lib/strangepaths_web/live/library/folio_live.html.heex`:**

```heex
<div class="p-6 max-w-4xl mx-auto">

  <%# Title block %>
  <div class="mb-6">
    <%= if @editing_title do %>
      <.form let={f} for={@title_changeset} phx-submit="save_title">
        <%= text_input f, :title, class: "text-2xl font-bold w-full bg-transparent border-b border-gray-600 focus:outline-none mb-2", autofocus: true %>
        <%= error_tag f, :title %>
        <%= text_input f, :subtitle, placeholder: "Subtitle (optional)", class: "w-full bg-transparent border-b border-gray-600 focus:outline-none mt-2 text-gray-400" %>
        <div class="flex gap-2 mt-2">
          <%= submit "Save", class: "btn-primary text-sm" %>
          <button type="button" phx-click="cancel_edit_title" class="btn-secondary text-sm">Cancel</button>
        </div>
      </.form>
    <% else %>
      <div class="flex items-start gap-2">
        <div>
          <h1 class="text-3xl font-bold"><%= @folio.title %></h1>
          <%= if @folio.subtitle do %>
            <p class="text-gray-400 mt-1"><%= @folio.subtitle %></p>
          <% end %>
        </div>
        <%= if @is_author || @is_dragon do %>
          <button phx-click="start_edit_title" class="text-xs text-gray-500 hover:text-gray-300 mt-1" title="Edit title">✎</button>
        <% end %>
      </div>
    <% end %>

    <p class="text-xs text-gray-600 mt-2">
      by <%= @folio.user.nickname %> ·
      <%= format_relative_time(@folio.inserted_at) %>
    </p>

    <%# Tags %>
    <div class="flex flex-wrap gap-1 mt-2">
      <%= for tag <- @tags do %>
        <span class="text-xs bg-gray-800 px-2 py-0.5 rounded"><%= tag %></span>
      <% end %>
    </div>
  </div>

  <%# Body %>
  <%= if @folio.body do %>
    <div class="folio-body prose prose-invert mb-8">
      <%= raw render_library_content(@folio.body) %>
    </div>
  <% end %>

  <%# Entry stream %>
  <%= if Enum.any?(@entries) do %>
    <div class="folio-entries space-y-4 mb-8">
      <%= for entry <- @entries do %>
        <div id={"entry-#{entry.id}"} class="folio-entry">
          <%= case entry.kind do %>
          <% :post_ref -> %>
            <%= if entry.scene_post do %>
              <div class="folio-post-ref border-l-2 border-gray-700 pl-4">
                <div class="text-xs text-gray-500 mb-1">
                  <strong><%= entry.scene_post.user && entry.scene_post.user.nickname %></strong>
                </div>
                <div class="folio-post-content">
                  <%= raw render_post_content(entry.scene_post.content) %>
                </div>
              </div>
            <% end %>
          <% :note -> %>
            <div class="folio-note" style={"font-family: #{entry.font}; color: #{entry.color};"}>
              <%= raw render_library_content(entry.content) %>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
  <% end %>

  <%# Dragon controls %>
  <%= if @is_dragon do %>
    <div class="mt-8 pt-4 border-t border-gray-800">
      <button
        phx-click="delete_folio"
        data-confirm="Delete this folio? This cannot be undone."
        class="text-sm text-red-500 hover:text-red-400"
      >
        Delete Folio
      </button>
    </div>
  <% end %>

</div>
```

**Verify:**

```bash
mix compile --no-deps-check
```
<!-- END_TASK_4 -->

<!-- START_TASK_5 -->
### Task 5: Folio view tests

**Create `test/strangepaths_web/live/library/folio_live_test.exs`:**

```elixir
defmodule StrangepathsWeb.LibraryLive.FolioTest do
  use StrangepathsWeb.ConnCase

  import Phoenix.LiveViewTest
  import Strangepaths.AccountsFixtures
  import Strangepaths.LibraryFixtures

  alias Strangepaths.Library

  defp dragon_fixture do
    {:ok, user} = Strangepaths.Accounts.register_dragon(valid_user_attributes())
    user
  end

  # Verifies: AC2.4 (body-only folio viewable), AC2.5 (entries-only viewable)
  describe "GET /library/:slug" do
    test "anyone can view a folio", %{conn: conn} do
      folio = folio_fixture(nil, %{"title" => "The Grand Archive"})
      {:ok, _view, html} = live(conn, "/library/the-grand-archive")
      assert html =~ "The Grand Archive"
    end

    test "body-only folio renders body content (AC2.4)", %{conn: conn} do
      user = user_typeface_fixture()
      folio = folio_fixture(user, %{"title" => "Body Only", "body" => "Some prose here."})

      {:ok, _view, html} = live(conn, "/library/body-only")
      assert html =~ "Some prose here."
    end

    test "folio with no body does not crash (AC2.5)", %{conn: conn} do
      folio = folio_fixture(nil, %{"title" => "No Body Folio"})
      {:ok, _view, html} = live(conn, "/library/no-body-folio")
      assert html =~ "No Body Folio"
    end

    test "redirects with flash on unknown slug", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/library/nonexistent-slug")
      assert_redirect(view, "/library")
    end
  end

  # Verifies: AC5.2 (author can edit title)
  describe "title editing" do
    test "author sees edit button", %{conn: conn} do
      user = user_typeface_fixture()
      folio = folio_fixture(user, %{"title" => "Editable Folio"})
      conn = log_in_user(conn, user)

      {:ok, _view, html} = live(conn, "/library/editable-folio")
      assert html =~ "✎"
    end

    test "author can edit title and subtitle", %{conn: conn} do
      user = user_typeface_fixture()
      folio = folio_fixture(user, %{"title" => "Old Title"})
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, "/library/old-title")

      view |> element("button[phx-click='start_edit_title']") |> render_click()
      html = view |> form("form", folio: %{title: "New Title", subtitle: "New Subtitle"}) |> render_submit()

      # Should push_patch to new slug URL
      assert_patch(view, "/library/new-title")
    end

    # Verifies: AC5.3 (non-author folio editor cannot edit title)
    test "non-author folio editor does not see edit button", %{conn: conn} do
      author = user_typeface_fixture()
      other_editor = user_typeface_fixture()
      folio = folio_fixture(author, %{"title" => "Author Folio"})
      conn = log_in_user(conn, other_editor)

      {:ok, _view, html} = live(conn, "/library/author-folio")
      refute html =~ "✎"
    end

    test "dragon can edit any folio title", %{conn: conn} do
      author = user_typeface_fixture()
      folio = folio_fixture(author, %{"title" => "Dragon Edit Test"})
      dragon = dragon_fixture()
      conn = log_in_user(conn, dragon)

      {:ok, view, html} = live(conn, "/library/dragon-edit-test")
      assert html =~ "✎"

      view |> element("button[phx-click='start_edit_title']") |> render_click()
      view |> form("form", folio: %{title: "Dragon Renamed"}) |> render_submit()

      assert_patch(view, "/library/dragon-renamed")
    end
  end

  # Verifies: AC8.3 (dragon can delete), AC8.4 (non-dragon cannot)
  describe "folio deletion" do
    test "dragon sees delete button", %{conn: conn} do
      folio = folio_fixture(nil, %{"title" => "Dragon Delete"})
      dragon = dragon_fixture()
      conn = log_in_user(conn, dragon)

      {:ok, _view, html} = live(conn, "/library/dragon-delete")
      assert html =~ "Delete Folio"
    end

    test "non-dragon does not see delete button", %{conn: conn} do
      user = user_typeface_fixture()
      folio = folio_fixture(user, %{"title" => "Non Dragon Delete"})
      conn = log_in_user(conn, user)

      {:ok, _view, html} = live(conn, "/library/non-dragon-delete")
      refute html =~ "Delete Folio"
    end

    test "dragon can delete a folio", %{conn: conn} do
      folio = folio_fixture(nil, %{"title" => "To Be Deleted"})
      dragon = dragon_fixture()
      conn = log_in_user(conn, dragon)

      {:ok, view, _html} = live(conn, "/library/to-be-deleted")
      view |> element("button[phx-click='delete_folio']") |> render_click()

      assert_redirect(view, "/library")
      assert Library.get_folio_by_slug("to-be-deleted") == nil
    end
  end
end
```

**Run tests:**

```bash
mix test test/strangepaths_web/live/library/folio_live_test.exs
mix test test/strangepaths_web/live/library/
```

**Run full suite to check regressions:**

```bash
mix test
```

**Commit:**

```bash
git add lib/strangepaths/library.ex \
        lib/strangepaths_web/router.ex \
        lib/strangepaths_web/live/library/folio_list_live.ex \
        lib/strangepaths_web/live/library/folio_list_live.html.heex \
        lib/strangepaths_web/live/library/folio_live.ex \
        lib/strangepaths_web/live/library/folio_live.html.heex \
        test/strangepaths_web/live/library/folio_list_live_test.exs \
        test/strangepaths_web/live/library/folio_live_test.exs
git commit -m "liminal library phase 3: folio view, creation, and deletion"
```
<!-- END_TASK_5 -->

<!-- END_SUBCOMPONENT_B -->
