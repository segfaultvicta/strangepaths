# Liminal Library Phase 4: Body Editor

**Goal:** Collaborative inline body editing with live preview and database mutex preventing concurrent edits.

**Architecture:** Extend `LibraryLive.Folio` with body editing state. Database-level mutex using `body_locked_by_id`/`body_locked_at` on `library_folios` (already migrated in Phase 1). `Process.send_after` for stale-lock timeout. Live preview rendered server-side on `phx-change` events. New `LibraryBodyEditor` JS hook for typeface tag insertion.

**Key finding from codebase investigation:** The rumor map uses Phoenix Presence for node locks (not DB fields). The folio body editor uses the DB fields added in Phase 1, which is more persistent (survives server restarts) and allows stale-lock detection.

**Tech Stack:** Elixir/Ecto (update_all for atomic lock claims), Phoenix LiveView, `Process.send_after`, Grimoire hook (existing), new `LibraryBodyEditor` JS hook

**Scope:** Phase 4 of 7

**Codebase verified:** 2026-04-27

---

## Acceptance Criteria Coverage

### liminal-library.AC3: Body editor with mutex and live preview
- **liminal-library.AC3.1 Success:** Any folio editor can open the body editor and save changes to any folio
- **liminal-library.AC3.2 Failure:** When editor A holds the mutex, editor B sees a locked state and cannot open the editor
- **liminal-library.AC3.3 Success:** Mutex releases on save, on cancel, and on inactivity timeout
- **liminal-library.AC3.6 Success:** Glyph pairs in body render correctly in preview and on the view page
- **liminal-library.AC3.7 Success:** Live preview pane updates on body text change

_(AC3.4 and AC3.5 were tested in Phase 2; they are also exercised here via the preview pane.)_

---

<!-- START_SUBCOMPONENT_A (tasks 1-2) -->

<!-- START_TASK_1 -->
### Task 1: Library context — mutex and body functions

**Add to `lib/strangepaths/library/folio.ex`:**

Add a `body_changeset/2` for saving body content while clearing the lock:

```elixir
def body_changeset(folio, attrs) do
  folio
  |> cast(attrs, [:body, :body_locked_by_id, :body_locked_at])
end
```

**Add to `lib/strangepaths/library.ex`:**

```elixir
# Lock timeout in seconds — also used by the LiveView for Process.send_after
def lock_timeout_seconds, do: 300   # 5 minutes

# Atomically claims the body lock if unclaimed or stale.
# Returns :ok on success, {:error, :locked} if another user currently holds it.
def claim_body_lock(folio_id, user_id) do
  now = DateTime.utc_now() |> DateTime.truncate(:second)
  stale_before = DateTime.add(now, -lock_timeout_seconds(), :second)

  {count, _} =
    from(f in Folio,
      where:
        f.id == ^folio_id and
          (is_nil(f.body_locked_by_id) or f.body_locked_at < ^stale_before)
    )
    |> Repo.update_all(set: [body_locked_by_id: user_id, body_locked_at: now])

  if count == 1, do: :ok, else: {:error, :locked}
end

# Releases the lock unconditionally.
def release_body_lock(folio_id) do
  from(f in Folio, where: f.id == ^folio_id)
  |> Repo.update_all(set: [body_locked_by_id: nil, body_locked_at: nil])
  :ok
end

# Saves body content and releases the lock atomically.
# Verifies the caller (user_id) currently holds the lock before saving.
# Returns :ok on success, {:error, :lock_lost} if the lock is not held by the caller.
def save_body(folio, user_id, content) do
  {count, _} =
    from(f in Folio,
      where: f.id == ^folio.id and f.body_locked_by_id == ^user_id
    )
    |> Repo.update_all(
      set: [body: content, body_locked_by_id: nil, body_locked_at: nil, updated_at: DateTime.utc_now()]
    )

  if count == 1, do: :ok, else: {:error, :lock_lost}
end

# Returns a locked folio (with lock metadata) — used by the LiveView to check lock holder.
def get_folio_lock_info(folio_id) do
  from(f in Folio,
    where: f.id == ^folio_id,
    select: %{locked_by_id: f.body_locked_by_id, locked_at: f.body_locked_at}
  )
  |> Repo.one()
end
```

**Verify:**

```bash
mix compile --no-deps-check
```

**Run existing context tests to confirm no regressions:**

```bash
mix test test/strangepaths/library_test.exs
```
<!-- END_TASK_1 -->

<!-- START_TASK_2 -->
### Task 2: Context tests for mutex functions

Add a new `describe "body mutex"` block to `test/strangepaths/library_test.exs`:

```elixir
describe "body mutex" do
  test "claim_body_lock succeeds when no lock" do
    folio = folio_fixture()
    assert :ok = Library.claim_body_lock(folio.id, 1)

    info = Library.get_folio_lock_info(folio.id)
    assert info.locked_by_id == 1
  end

  test "claim_body_lock fails when another user holds the lock" do
    folio = folio_fixture()
    user1 = user_typeface_fixture()
    user2 = user_typeface_fixture()

    :ok = Library.claim_body_lock(folio.id, user1.id)
    assert {:error, :locked} = Library.claim_body_lock(folio.id, user2.id)
  end

  test "claim_body_lock succeeds when existing lock is stale" do
    folio = folio_fixture()
    user1 = user_typeface_fixture()
    user2 = user_typeface_fixture()

    # Manually insert a stale lock (older than lock_timeout_seconds)
    stale_at =
      DateTime.utc_now()
      |> DateTime.add(-(Library.lock_timeout_seconds() + 10), :second)
      |> DateTime.truncate(:second)

    from(f in Strangepaths.Library.Folio, where: f.id == ^folio.id)
    |> Strangepaths.Repo.update_all(
      set: [body_locked_by_id: user1.id, body_locked_at: stale_at]
    )

    # User 2 can claim despite user1's stale lock
    assert :ok = Library.claim_body_lock(folio.id, user2.id)
    info = Library.get_folio_lock_info(folio.id)
    assert info.locked_by_id == user2.id
  end

  test "release_body_lock clears the lock" do
    folio = folio_fixture()
    user = user_typeface_fixture()

    :ok = Library.claim_body_lock(folio.id, user.id)
    :ok = Library.release_body_lock(folio.id)

    info = Library.get_folio_lock_info(folio.id)
    assert is_nil(info.locked_by_id)
  end

  test "save_body saves content and releases lock" do
    user = user_typeface_fixture()
    folio = folio_fixture(user)

    :ok = Library.claim_body_lock(folio.id, user.id)
    :ok = Library.save_body(folio, user.id, "New body content.")

    info = Library.get_folio_lock_info(folio.id)
    assert is_nil(info.locked_by_id)
  end
end
```

**Run:**

```bash
mix test test/strangepaths/library_test.exs
```

All tests pass before proceeding.

**Commit:**

```bash
git add lib/strangepaths/library/folio.ex lib/strangepaths/library.ex test/strangepaths/library_test.exs
git commit -m "liminal library phase 4a: body mutex context functions"
```
<!-- END_TASK_2 -->

<!-- END_SUBCOMPONENT_A -->

<!-- START_SUBCOMPONENT_B (tasks 3-4) -->

<!-- START_TASK_3 -->
### Task 3: Body editor LiveView and template

**Extend `lib/strangepaths_web/live/library/folio_live.ex`:**

Add the lock timeout constant and new assigns at the top of the module:

```elixir
@lock_timeout_ms Library.lock_timeout_seconds() * 1_000
```

Add to `mount/3` (after the existing assigns):

```elixir
|> assign(:editing_body, false)
|> assign(:body_content, folio.body || "")
|> assign(:preview_html, render_library_content(folio.body || ""))
|> assign(:editor_typefaces, if(user, do: Library.folio_editor_typefaces(user.id), else: []))
```

Note: `render_library_content/2` is available in the LiveView because it was imported into `view_helpers/0` in Phase 2.

Add these event handlers:

```elixir
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
        {:noreply, put_flash(socket, :error, "Lock was lost. Your changes were not saved. Please try again.")}
    end
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
```

**Add `LibraryBodyEditor` hook to `assets/js/app.js`:**

Find where other hooks are defined (look for `Hooks.Grimoire` or `Hooks.RumorMap`) and add:

```javascript
Hooks.LibraryBodyEditor = {
  mounted() {
    this.el.querySelectorAll("[data-insert-tag]").forEach((btn) => {
      btn.addEventListener("click", () => {
        const tagName = btn.dataset.insertTag;
        const textarea = document.getElementById("library-body-textarea");
        if (!textarea) return;

        const start = textarea.selectionStart;
        const end = textarea.selectionEnd;
        const selected = textarea.value.substring(start, end);
        const insert = `[${tagName}]${selected}[/${tagName}]`;

        textarea.value =
          textarea.value.substring(0, start) +
          insert +
          textarea.value.substring(end);

        // Move cursor to inside the closing tag (after selected text)
        const newPos = start + insert.length - `[/${tagName}]`.length;
        textarea.setSelectionRange(newPos, newPos);
        textarea.focus();

        // Trigger phx-change so the LiveView preview updates
        textarea.dispatchEvent(new Event("input", { bubbles: true }));
      });
    });
  },
};
```

**Update `lib/strangepaths_web/live/library/folio_live.html.heex`:**

Replace the body display section with the full editor UI. Add after the title block and before the entry stream:

```heex
<%# Body section %>
<div class="mb-8">
  <%= if @editing_body do %>
    <%# Body editor — split pane: editor left, preview right %>
    <div id="library-body-editor" phx-hook="LibraryBodyEditor">
      <div class="flex gap-2 mb-2">
        <%# Grimoire glyph toolbar %>
        <div id="library-body-grimoire" phx-hook="Grimoire" phx-update="ignore" data-textarea-id="library-body-textarea">
          <button type="button" class="grimoire-trigger text-xs px-2 py-1 border border-gray-700 rounded" title="Insert glyph">Esoterica</button>
          <div class="grimoire-popover" style="display:none;">
            <div class="grimoire-glyphs"></div>
            <button type="button" class="grimoire-add-btn">+</button>
            <input type="text" class="grimoire-add-input" maxlength="1" style="display:none;" />
          </div>
        </div>

        <%# Typeface tag buttons — one per assigned typeface %>
        <%= for tf <- @editor_typefaces do %>
          <button
            type="button"
            data-insert-tag={tf.id}
            title={"Insert [#{tf.id}] tag"}
            class="text-xs px-2 py-1 border border-gray-700 rounded"
            style={"font-family: #{tf.font}; color: #{tf.color};"}
          >
            <%= tf.name %>
          </button>
        <% end %>
      </div>

      <.form let={f} for={%{}} as={:folio} phx-change="update_preview" phx-submit="save_body">
        <div class="grid grid-cols-2 gap-4">
          <div>
            <%= textarea :folio, :body,
              id: "library-body-textarea",
              value: @body_content,
              class: "w-full h-96 bg-gray-900 border border-gray-700 rounded px-3 py-2 font-mono text-sm resize-y",
              phx_debounce: "300" %>
          </div>
          <div class="h-96 overflow-y-auto border border-gray-700 rounded px-3 py-2 prose prose-invert">
            <%= raw @preview_html %>
          </div>
        </div>
        <div class="flex gap-2 mt-2">
          <%= submit "Save Body", class: "btn-primary text-sm" %>
          <button type="button" phx-click="cancel_edit_body" class="btn-secondary text-sm">Cancel</button>
        </div>
      </.form>
    </div>
  <% else %>
    <%= if @folio.body do %>
      <div class="folio-body prose prose-invert mb-4">
        <%= raw render_library_content(@folio.body) %>
      </div>
    <% end %>

    <%= if @is_folio_editor do %>
      <button phx-click="claim_body_lock" class="text-xs text-gray-500 hover:text-gray-300">
        <%= if @folio.body, do: "Edit body", else: "+ Add body" %>
      </button>
    <% end %>
  <% end %>
</div>
```

**Verify:**

```bash
mix compile --no-deps-check
```
<!-- END_TASK_3 -->

<!-- START_TASK_4 -->
### Task 4: Body editor LiveView tests

**Create `test/strangepaths_web/live/library/body_editor_test.exs`:**

```elixir
defmodule StrangepathsWeb.LibraryLive.BodyEditorTest do
  use StrangepathsWeb.ConnCase

  import Phoenix.LiveViewTest
  import Strangepaths.AccountsFixtures
  import Strangepaths.LibraryFixtures

  alias Strangepaths.Library

  # Verifies: liminal-library.AC3.1
  describe "body editor access" do
    test "folio editor can open body editor", %{conn: conn} do
      user = user_typeface_fixture()
      folio = folio_fixture(user, %{"title" => "Editable Body Folio"})
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, "/library/editable-body-folio")

      html = view |> element("button[phx-click='claim_body_lock']") |> render_click()
      assert html =~ "Save Body"
      assert html =~ "Cancel"
    end

    test "non-folio-editor does not see edit body button", %{conn: conn} do
      author = user_typeface_fixture()
      folio = folio_fixture(author, %{"title" => "Non Editor Body"})
      other_user = user_fixture()
      conn = log_in_user(conn, other_user)

      {:ok, _view, html} = live(conn, "/library/non-editor-body")
      refute html =~ "Edit body"
      refute html =~ "Add body"
    end
  end

  # Verifies: liminal-library.AC3.2
  describe "mutex — locked state" do
    test "second editor sees locked flash when first holds the mutex", %{conn: conn} do
      user1 = user_typeface_fixture()
      user2 = user_typeface_fixture()
      folio = folio_fixture(user1, %{"title" => "Mutex Test Folio"})

      # User 1 claims the lock directly via context
      Library.claim_body_lock(folio.id, user1.id)

      # User 2 tries to open the editor
      conn2 = log_in_user(conn, user2)
      {:ok, view, _html} = live(conn2, "/library/mutex-test-folio")

      html = view |> element("button[phx-click='claim_body_lock']") |> render_click()

      assert html =~ "Another editor" || has_flash?(view, :error)
    end
  end

  # Verifies: liminal-library.AC3.3
  describe "mutex release" do
    test "save_body releases the lock" do
      user = user_typeface_fixture()
      folio = folio_fixture(user, %{"title" => "Save Release Test"})

      Library.claim_body_lock(folio.id, user.id)
      Library.save_body(folio, "Saved content")

      info = Library.get_folio_lock_info(folio.id)
      assert is_nil(info.locked_by_id)
    end

    test "release_body_lock releases on cancel" do
      user = user_typeface_fixture()
      folio = folio_fixture(user)

      Library.claim_body_lock(folio.id, user.id)
      Library.release_body_lock(folio.id)

      info = Library.get_folio_lock_info(folio.id)
      assert is_nil(info.locked_by_id)
    end
  end

  # Verifies: liminal-library.AC3.7
  describe "live preview" do
    test "update_preview event updates preview html", %{conn: conn} do
      user = user_typeface_fixture()
      folio = folio_fixture(user, %{"title" => "Preview Test Folio"})

      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, "/library/preview-test-folio")

      # Open editor
      view |> element("button[phx-click='claim_body_lock']") |> render_click()

      # Trigger preview update
      html =
        view
        |> element("form")
        |> render_change(%{folio: %{body: "**preview content**"}})

      assert html =~ "<strong>preview content</strong>"
    end
  end
end
```

**Note on `has_flash?/2`:** Check how existing tests verify flash messages — it might be `assert render(view) =~ "flash-error"` or a project-specific helper. Adjust accordingly.

**Run:**

```bash
mix test test/strangepaths_web/live/library/body_editor_test.exs
mix test
```

**Commit:**

```bash
git add lib/strangepaths/library.ex \
        lib/strangepaths/library/folio.ex \
        lib/strangepaths_web/live/library/folio_live.ex \
        lib/strangepaths_web/live/library/folio_live.html.heex \
        assets/js/app.js \
        test/strangepaths/library_test.exs \
        test/strangepaths_web/live/library/body_editor_test.exs
git commit -m "liminal library phase 4: body editor with live preview and mutex"
```
<!-- END_TASK_4 -->

<!-- END_SUBCOMPONENT_B -->
