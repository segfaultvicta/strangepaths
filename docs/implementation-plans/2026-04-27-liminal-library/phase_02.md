# Liminal Library Phase 2: Typeface System & Dragon Admin

**Goal:** Rendering pipeline for typeface tags and the dragon-only admin UI for assigning typefaces to users.

**Architecture:** A new `StrangepathsWeb.LibraryHelpers` module provides `render_library_content/2` which prepends a `[name]text[/name]` tag pass before delegating to the existing `render_post_content/2`. A new LiveView at `/library/admin` lets the dragon view all users and toggle their typeface assignments.

**Tech Stack:** Elixir regex (stdlib), Phoenix.HTML, existing glyph+Earmark pipeline in `scene_helpers.ex`, Phoenix LiveView

**Scope:** Phase 2 of 7

**Codebase verified:** 2026-04-27

---

## Acceptance Criteria Coverage

### liminal-library.AC1: Dragon manages typeface assignment (folio access)
- **liminal-library.AC1.1 Success:** Dragon can view all users and their current typeface assignments at `/library/admin`
- **liminal-library.AC1.2 Success:** Dragon can assign one or more typefaces to any user, including themselves
- **liminal-library.AC1.3 Success:** Dragon can revoke a typeface assignment

### liminal-library.AC3: Body editor with mutex and live preview
- **liminal-library.AC3.4 Success:** `[name]text[/name]` with a known typeface name renders as a styled span
- **liminal-library.AC3.5 Success:** `[name]text[/name]` with an unknown name renders as literal text (brackets visible)

---

<!-- START_SUBCOMPONENT_A (tasks 1-2) -->

<!-- START_TASK_1 -->
### Task 1: `render_library_content/2` helper module

**Create `lib/strangepaths_web/library_helpers.ex`:**

```elixir
defmodule StrangepathsWeb.LibraryHelpers do
  import StrangepathsWeb.SceneHelpers, only: [render_post_content: 2]

  def render_library_content(content, opts \\ []) when is_binary(content) do
    {tokenized, token_map} = extract_typeface_tokens(content)

    tokenized
    |> render_post_content(opts)
    |> restore_typeface_tokens(token_map)
  end

  defp extract_typeface_tokens(content) do
    pattern = ~r/\[([a-z][a-z0-9_-]*)\](.*?)\[\/\1\]/su

    Regex.scan(pattern, content)
    |> Enum.reduce({content, %{}}, fn [full_match, name, text], {acc_content, acc_tokens} ->
      token = "LLITOK#{map_size(acc_tokens)}LLITOK"

      {
        String.replace(acc_content, full_match, token, global: false),
        Map.put(acc_tokens, token, {name, text})
      }
    end)
  end

  defp restore_typeface_tokens(html, token_map) do
    Enum.reduce(token_map, html, fn {token, {name, raw_text}}, acc ->
      replacement =
        case Strangepaths.Library.Typefaces.find(name) do
          nil ->
            "[#{name}]#{raw_text}[/#{name}]"

          tf ->
            escaped = Phoenix.HTML.html_escape(raw_text) |> Phoenix.HTML.safe_to_string()
            ~s(<span style="font-family: #{tf.font}; color: #{tf.color};">#{escaped}</span>)
        end

      String.replace(acc, token, replacement)
    end)
  end
end
```

**Notes:**
- This function uses a tokenize-before/restore-after pattern to avoid Earmark interference with inline HTML spans.
- The `/s` and `/u` regex flags allow matching newlines and Unicode in typeface tags.
- `raw_text` is extracted before markdown processing and stored in a token. This prevents Earmark from double-escaping or interfering with the span.
- After markdown and glyph rendering, tokens are restored to their final HTML spans.
- `raw_text` is HTML-escaped before embedding in the span — it is user input and must be safe. The `font` and `color` come from the hardcoded `Typefaces` master list (safe).
- Return value follows the same convention as `render_post_content/2` — a string containing HTML.

**Add `LibraryHelpers` import to `lib/strangepaths_web.ex`:**

Find the `view_helpers/0` function (around line 87) and add the import:

```elixir
defp view_helpers do
  quote do
    use Phoenix.HTML
    import Phoenix.LiveView.Helpers
    import StrangepathsWeb.LiveHelpers
    import Phoenix.View
    import StrangepathsWeb.ErrorHelpers
    import StrangepathsWeb.Gettext
    import StrangepathsWeb.LibraryHelpers   # ← ADD THIS LINE
    alias StrangepathsWeb.Router.Helpers, as: Routes
  end
end
```

**Verify compilation:**

```bash
mix compile --no-deps-check
```
<!-- END_TASK_1 -->

<!-- START_TASK_2 -->
### Task 2: Tests for `render_library_content/2`

**Create `test/strangepaths_web/library_helpers_test.exs`:**

```elixir
defmodule StrangepathsWeb.LibraryHelpersTest do
  use ExUnit.Case

  import StrangepathsWeb.LibraryHelpers

  # Verifies: liminal-library.AC3.4
  describe "render_library_content/2 - known typeface tags" do
    test "renders known typeface tag as styled span" do
      # "jorule" must be a valid typeface id in Strangepaths.Library.Typefaces
      [tf | _] = Strangepaths.Library.Typefaces.all()
      content = "[#{tf.id}]some text[/#{tf.id}]"

      result = render_library_content(content)

      assert result =~ "<span style=\"font-family: #{tf.font}; color: #{tf.color};\""
      assert result =~ "some text"
      refute result =~ "[#{tf.id}]"
    end

    test "renders multiple typeface tags in one string" do
      [tf1, tf2 | _] = Strangepaths.Library.Typefaces.all()
      content = "[#{tf1.id}]first[/#{tf1.id}] and [#{tf2.id}]second[/#{tf2.id}]"

      result = render_library_content(content)

      assert result =~ tf1.color
      assert result =~ tf2.color
      assert result =~ "first"
      assert result =~ "second"
    end
  end

  # Verifies: liminal-library.AC3.5
  describe "render_library_content/2 - unknown typeface tags" do
    test "renders unknown typeface name as literal text with brackets" do
      content = "[unknowntypeface]some text[/unknowntypeface]"

      result = render_library_content(content)

      assert result =~ "[unknowntypeface]"
      assert result =~ "[/unknowntypeface]"
      assert result =~ "some text"
      refute result =~ "<span"
    end
  end

  describe "render_library_content/2 - XSS safety" do
    test "HTML-escapes user text inside a typeface tag" do
      [tf | _] = Strangepaths.Library.Typefaces.all()
      content = "[#{tf.id}]<script>alert('xss')</script>[/#{tf.id}]"

      result = render_library_content(content)

      refute result =~ "<script>alert"
      assert result =~ "&lt;script&gt;"
    end
  end

  describe "render_library_content/2 - passthrough" do
    test "content with no typeface tags passes through unchanged (modulo markdown)" do
      content = "Plain text with **bold**."

      result = render_library_content(content)

      assert result =~ "Plain text with"
      assert result =~ "<strong>bold</strong>"
    end

    test "glyph pairs in content still render correctly" do
      [tf | _] = Strangepaths.Library.Typefaces.all()
      content = "[#{tf.id}]hello[/#{tf.id}] and some other text"

      result = render_library_content(content)

      assert result =~ "hello"
      assert result =~ "some other text"
    end
  end
end
```

**Run the tests:**

```bash
mix test test/strangepaths_web/library_helpers_test.exs
```

All tests should pass. If a test fails because there aren't two distinct typefaces in `Typefaces.all()`, add a second typeface to `lib/strangepaths/library/typefaces.ex`.

**Commit:**

```bash
git add lib/strangepaths_web/library_helpers.ex \
        lib/strangepaths_web.ex \
        test/strangepaths_web/library_helpers_test.exs
git commit -m "liminal library phase 2: render_library_content/2 with typeface tag pass"
```
<!-- END_TASK_2 -->

<!-- END_SUBCOMPONENT_A -->

<!-- START_SUBCOMPONENT_B (tasks 3-5) -->

<!-- START_TASK_3 -->
### Task 3: Router — add `/library/admin` route

Open `lib/strangepaths_web/router.ex`. Find the main browser scope (the `scope "/"` block that contains `/bbs/*` and `/scenes`, roughly lines 23–71). Add the admin route there:

```elixir
live("/library/admin", LibraryLive.Admin)
```

The full library routes (`/library`, `/library/:slug`, etc.) will be added in later phases as their LiveViews are built. Adding `/library/admin` first avoids issues with the catch-all `/library/:slug` pattern intercepting it — route order matters, and admin must be defined before `/:slug`.

**Verify it compiles:**

```bash
mix compile --no-deps-check
```

You'll see a warning that `LibraryLive.Admin` doesn't exist yet — that's expected. The warning will clear in Task 4.
<!-- END_TASK_3 -->

<!-- START_TASK_4 -->
### Task 4: Dragon Admin LiveView

**Create the directory:**

```bash
mkdir -p lib/strangepaths_web/live/library
```

**Create `lib/strangepaths_web/live/library/admin_live.ex`:**

```elixir
defmodule StrangepathsWeb.LibraryLive.Admin do
  use StrangepathsWeb, :live_view

  alias Strangepaths.Accounts
  alias Strangepaths.Library

  @impl true
  def mount(_params, session, socket) do
    socket = assign_defaults(session, socket)

    if socket.assigns.current_user && socket.assigns.current_user.role == :dragon do
      users = load_users_with_typefaces()

      {:ok,
       socket
       |> assign(:page_title, "Library Admin — Typeface Assignments")
       |> assign(:users, users)
       |> assign(:typefaces, Library.Typefaces.all())}
    else
      {:ok,
       socket
       |> put_flash(:error, "Unauthorized")
       |> push_redirect(to: "/")}
    end
  end

  @impl true
  def handle_event("toggle_typeface", %{"user-id" => user_id_str, "typeface-id" => typeface_id}, socket) do
    user_id = String.to_integer(user_id_str)
    assigned_ids = socket.assigns.users |> Enum.find(&(&1.id == user_id)) |> Map.get(:typeface_ids)

    if typeface_id in assigned_ids do
      Library.remove_user_typeface(user_id, typeface_id)
    else
      Library.assign_user_typeface(user_id, typeface_id)
    end

    users = load_users_with_typefaces()
    {:noreply, assign(socket, :users, users)}
  end

  defp load_users_with_typefaces do
    Accounts.list_users()
    |> Enum.map(fn user ->
      typeface_ids = Library.list_user_typefaces(user.id)
      Map.put(user, :typeface_ids, typeface_ids)
    end)
  end
end
```

**Create `lib/strangepaths_web/live/library/admin_live.html.heex`:**

```heex
<div class="p-6">
  <h1 class="text-2xl font-bold mb-6">Library Admin — Typeface Assignments</h1>

  <p class="mb-4 text-sm text-gray-400">
    Users with at least one assigned typeface become folio editors.
  </p>

  <table class="w-full text-sm">
    <thead>
      <tr class="border-b border-gray-700">
        <th class="text-left py-2 pr-4">User</th>
        <%= for tf <- @typefaces do %>
          <th class="text-center py-2 px-2"><%= tf.name %></th>
        <% end %>
      </tr>
    </thead>
    <tbody>
      <%= for user <- @users do %>
        <tr class="border-b border-gray-800 hover:bg-gray-900">
          <td class="py-2 pr-4 font-medium"><%= user.nickname %></td>
          <%= for tf <- @typefaces do %>
            <td class="text-center py-2 px-2">
              <button
                phx-click="toggle_typeface"
                phx-value-user-id={user.id}
                phx-value-typeface-id={tf.id}
                title={if tf.id in user.typeface_ids, do: "Revoke #{tf.name}", else: "Assign #{tf.name}"}
                class="text-lg leading-none"
              >
                <%= if tf.id in user.typeface_ids, do: "✓", else: "·" %>
              </button>
            </td>
          <% end %>
        </tr>
      <% end %>
    </tbody>
  </table>
</div>
```

**Verify compilation:**

```bash
mix compile --no-deps-check
```

No errors expected.
<!-- END_TASK_4 -->

<!-- START_TASK_5 -->
### Task 5: Admin LiveView tests

Check `test/strangepaths_web/live/` for an existing example test to see how LiveView tests are structured in this project before writing. The test pattern for dragon-only LiveViews is:
1. Create a user and a dragon
2. Test with dragon session — expect success
3. Test with regular user session — expect redirect

**Create `test/strangepaths_web/live/library/admin_live_test.exs`:**

```elixir
defmodule StrangepathsWeb.LibraryLive.AdminTest do
  use StrangepathsWeb.ConnCase

  import Phoenix.LiveViewTest
  import Strangepaths.AccountsFixtures

  alias Strangepaths.Library

  defp dragon_fixture do
    {:ok, user} = Strangepaths.Accounts.register_dragon(valid_user_attributes())
    user
  end

  # Verifies: liminal-library.AC1.1
  describe "GET /library/admin" do
    test "dragon can view the admin page", %{conn: conn} do
      dragon = dragon_fixture()
      conn = log_in_user(conn, dragon)

      {:ok, _view, html} = live(conn, "/library/admin")

      assert html =~ "Library Admin"
      assert html =~ "Typeface Assignments"
    end

    test "non-dragon is redirected", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, "/library/admin")

      # Should have redirected to "/" with error flash
      assert_redirect(view, "/")
    end

    test "unauthenticated user is redirected", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/library/admin")

      assert_redirect(view, "/")
    end
  end

  # Verifies: liminal-library.AC1.2
  describe "assign typeface" do
    test "dragon can assign a typeface to a user", %{conn: conn} do
      dragon = dragon_fixture()
      target_user = user_fixture()
      [tf | _] = Library.Typefaces.all()

      conn = log_in_user(conn, dragon)
      {:ok, view, _html} = live(conn, "/library/admin")

      refute Library.is_folio_editor?(target_user.id)

      view
      |> element("button[phx-value-user-id='#{target_user.id}'][phx-value-typeface-id='#{tf.id}']")
      |> render_click()

      assert Library.is_folio_editor?(target_user.id)
    end

    test "dragon can assign typeface to themselves", %{conn: conn} do
      dragon = dragon_fixture()
      [tf | _] = Library.Typefaces.all()

      conn = log_in_user(conn, dragon)
      {:ok, view, _html} = live(conn, "/library/admin")

      view
      |> element("button[phx-value-user-id='#{dragon.id}'][phx-value-typeface-id='#{tf.id}']")
      |> render_click()

      assert Library.is_folio_editor?(dragon.id)
    end
  end

  # Verifies: liminal-library.AC1.3
  describe "revoke typeface" do
    test "dragon can revoke a typeface from a user", %{conn: conn} do
      dragon = dragon_fixture()
      target_user = user_fixture()
      [tf | _] = Library.Typefaces.all()

      # Pre-assign
      Library.assign_user_typeface(target_user.id, tf.id)
      assert Library.is_folio_editor?(target_user.id)

      conn = log_in_user(conn, dragon)
      {:ok, view, _html} = live(conn, "/library/admin")

      # Click the same button to toggle off
      view
      |> element("button[phx-value-user-id='#{target_user.id}'][phx-value-typeface-id='#{tf.id}']")
      |> render_click()

      refute Library.is_folio_editor?(target_user.id)
    end
  end
end
```

**Note on `log_in_user/2`:** Check `test/support/conn_case.ex` to confirm this helper exists. If it's named differently (e.g., `login_user/2`), adjust. In many Phoenix setups it's generated by `mix phx.gen.auth` — look at an existing LiveView test in `test/strangepaths_web/live/` for the exact helper name.

**Note on `user_fixture/1` with `%{role: :dragon}`:** Check `test/support/fixtures/accounts_fixtures.ex` to confirm `user_fixture` accepts a `role` override. If not, you may need to create a separate `dragon_fixture/0` that calls `Accounts.update_user_role/2` or a direct Repo insert. Read the fixture module before writing the test.

**Run the tests:**

```bash
mix test test/strangepaths_web/live/library/admin_live_test.exs
```

**Run full suite:**

```bash
mix test
```

**Commit:**

```bash
git add lib/strangepaths_web/router.ex \
        lib/strangepaths_web/live/library/admin_live.ex \
        lib/strangepaths_web/live/library/admin_live.html.heex \
        test/strangepaths_web/live/library/admin_live_test.exs
git commit -m "liminal library phase 2: admin LiveView for typeface assignment"
```
<!-- END_TASK_5 -->

<!-- END_SUBCOMPONENT_B -->
