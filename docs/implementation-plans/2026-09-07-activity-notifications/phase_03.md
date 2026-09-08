# Activity Notifications Implementation Plan — Phase 3

**Goal:** Every LiveView in the app subscribes its socket to `user:#{current_user.id}:notifications` on connected mount and forwards `"activity"` broadcasts to the browser as `push_event(socket, "activity", payload)` — with no per-LiveView code and no behavioral regression. Unrelated `handle_info` messages pass straight through.

**Architecture:** One new module `StrangepathsWeb.NotificationHooks` with `on_mount(:subscribe, params, session, socket)`. It loads the user with the existing `StrangepathsWeb.LiveHelpers.find_current_user/1`, and when the socket is connected **and** a user is present it (a) `StrangepathsWeb.Endpoint.subscribe("user:#{user.id}:notifications")` and (b) `Phoenix.LiveView.attach_hook(socket, :activity_notifications, :handle_info, &handle_activity/2)`. `handle_activity/2` pattern-matches the activity broadcast and returns `{:halt, push_event(socket, "activity", payload)}`; every other message returns `{:cont, socket}`. The router wraps the app's `live` routes in `live_session` blocks that set `on_mount: {StrangepathsWeb.NotificationHooks, :subscribe}`.

**Tech Stack:** Phoenix LiveView 0.17.14 (locked in `mix.lock`; `~> 0.17.5` in `mix.exs`) — `live_session`, `on_mount`, `Phoenix.LiveView.attach_hook/4` are all new to this codebase (zero existing uses) and all present in 0.17.14. `Phoenix.LiveViewTest` provides `live/2` and `assert_push_event/4` (there is **no** `refute_push_event` in this version).

**Scope:** Phase 3 of 6 from `docs/design-plans/2026-09-07-activity-notifications.md`.

**Codebase verified:** 2026-09-08.

**Test-suite baseline:** `PGPASSWORD=1zc3edg5 mix test` = 345 tests / 212 pre-existing failures suite-wide, and `mix compile --warnings-as-errors` fails on the untouched tree. Both new test files this phase adds (`notification_hooks_test.exs`, `notification_bus_smoke_test.exs`) are new, so their "green" gates are literal. The one whole-suite gate (Task 3) is a **delta** gate — no new failures.

**Verification findings incorporated:**
- ✓ `grep -r "live_session\|on_mount\|attach_hook" lib assets` → **zero hits**. This phase introduces all three.
- ✓ `StrangepathsWeb.LiveHelpers.find_current_user/1` (`lib/strangepaths_web/live/live_helpers.ex:11-42`): `with user_token when not is_nil(user_token) <- session["user_token"], %User{} = user <- Accounts.get_user_by_session_token(user_token), do: user`. Returns `%User{}` or `nil`. (It also rewrites `user.techne`; harmless here — the hook only reads `user.id`.)
- ✓ Router (`lib/strangepaths_web/router.ex`): the app's LiveViews are declared as `live/3` and `live/4` inside `scope "/", StrangepathsWeb do pipe_through(:browser) ... end` (lines 23–79). This scope is **not** behind `:require_authenticated_user` — pages load for logged-out visitors too, so the hook **must** tolerate `current_user == nil`. A second, smaller cluster (`live("/users/admin", UserAdminLive)` and `live_dashboard`) sits under `[:browser, :require_authenticated_user]` (lines 113–122).
- ✓ `StrangepathsWeb.Endpoint` is the PubSub entry point used everywhere (`Endpoint.broadcast/3`, `Endpoint.subscribe/1`); topics are plain strings (`"scene:#{id}"`, `"rumor_map"`, `"library_folio:#{id}"`, `"music"`).
- ✓ Representative LiveViews for the smoke check: `StrangepathsWeb.Scenes` (`/scenes`), `LibraryLive.Folio` (`/library/:slug`), `BBSLive.Thread` (`/bbs/:board_slug/:thread_id`), `RumorMapLive.Show` (`/rumor`), `CardLive.Index` (`/cosmos`).
- ✓ Layout root: `{StrangepathsWeb.LayoutView, :root}` (router.ex:10). `live_session` will inherit the default `:root_layout`/`:layout` — no override needed since there is only one root layout.

**Deviation from design (documented):** The design says "a single `live_session :authenticated` wraps every authenticated route." The codebase's LiveViews span two pipelines, and a `live_session` block cannot straddle `scope` blocks with different `pipe_through`. This plan therefore uses **two** `live_session` blocks — `:app` (the main `:browser` cluster) and `:app_authenticated` (the `:require_authenticated_user` cluster) — both passing the same `on_mount: {StrangepathsWeb.NotificationHooks, :subscribe}`. Behaviour is identical to the design's intent (every LiveView runs the hook); only the block count differs. No AC references a single block. `live_dashboard` is left outside both blocks (it manages its own `live_session` internally). Residual consequence: a `live_redirect` that crosses the `:app` ↔ `:app_authenticated` boundary degrades to a full page reload. Verified impact is nil today — nothing in the codebase `live_redirect`s to `/users/admin`; all navigation there is a plain `<a>`/`redirect`. Note it so a future contributor adding cross-cluster `live_redirect` knows why it hard-navigates.

---

## Acceptance Criteria Coverage

### activity-notifications.AC3: The bus reaches every authenticated page
- **activity-notifications.AC3.1 Success:** On mount of any authenticated LiveView with a connected socket, the session is subscribed to `user:#{current_user.id}:notifications`.
- **activity-notifications.AC3.2 Success:** An `activity` broadcast on that topic results in a `push_event("activity", payload)` to that session, regardless of which LiveView is mounted.
- **activity-notifications.AC3.3 Failure:** A non-`activity` message on the topic (or any unrelated `handle_info` message) is passed through unchanged — the interceptor does not swallow it.
- **activity-notifications.AC3.4 Edge:** A disconnected (dead) mount does not subscribe and does not crash.
- **activity-notifications.AC3.5 Success:** Representative pages (scene, folio, BBS thread, rumor map, and one unrelated LiveView such as `/cosmos`) mount without error and with existing assigns intact after the `live_session` wrap.

---

<!-- START_SUBCOMPONENT_A (tasks 1-3) -->

<!-- START_TASK_1 -->
### Task 1: `StrangepathsWeb.NotificationHooks` — the `on_mount` hook

**Verifies:** activity-notifications.AC3.1, activity-notifications.AC3.2, activity-notifications.AC3.3, activity-notifications.AC3.4

**Files:**
- Create: `lib/strangepaths_web/live/notification_hooks.ex`

**Implementation:**

```elixir
defmodule StrangepathsWeb.NotificationHooks do
  @moduledoc """
  `on_mount` hook attached to every LiveView via `live_session` in the router.

  On a connected mount with a logged-in user it:
    * subscribes the LiveView process to `"user:#{user.id}:notifications"`, and
    * attaches a `:handle_info` lifecycle hook that forwards `"activity"` broadcasts
      to the client as `push_event(socket, "activity", payload)` and lets every other
      message fall through to the LiveView untouched.

  Dead (disconnected) mounts and logged-out visitors do nothing.
  """
  import Phoenix.LiveView, only: [connected?: 1, attach_hook: 4, push_event: 3]

  alias StrangepathsWeb.LiveHelpers

  def on_mount(:subscribe, _params, session, socket) do
    socket =
      case LiveHelpers.find_current_user(session) do
        %{id: user_id} when is_integer(user_id) ->
          maybe_subscribe(socket, user_id)

        _ ->
          socket
      end

    {:cont, socket}
  end

  defp maybe_subscribe(socket, user_id) do
    if connected?(socket) do
      StrangepathsWeb.Endpoint.subscribe("user:#{user_id}:notifications")

      attach_hook(socket, :activity_notifications, :handle_info, &handle_activity/2)
    else
      socket
    end
  end

  # The one message this hook consumes.
  defp handle_activity(
         %Phoenix.Socket.Broadcast{topic: "user:" <> _, event: "activity", payload: payload},
         socket
       ) do
    {:halt, push_event(socket, "activity", payload)}
  end

  # Everything else — other broadcasts on the topic, and every unrelated handle_info
  # message the LiveView expects to handle itself — passes straight through.
  defp handle_activity(_message, socket), do: {:cont, socket}
end
```

**Testing:**

- Test file: `test/strangepaths_web/live/notification_hooks_test.exs` (create; integration, `use StrangepathsWeb.ConnCase`). Import `Phoenix.LiveViewTest`. Log a user in with the ConnCase helper (`register_and_log_in_user/1` or the project equivalent — confirm in `test/support/conn_case.ex` during the RED step).
- Mount an existing, cheap LiveView through the router (e.g. `live(conn, "/cosmos")`).
- Tests must verify:
  - **activity-notifications.AC3.1 + AC3.2 (together):** after `{:ok, view, _html} = live(conn, "/cosmos")`, call `StrangepathsWeb.Endpoint.broadcast("user:#{user.id}:notifications", "activity", %{source: :bbs, event: :new_post, title: "t", excerpt: "e", url: "/bbs/x/1", context_key: "bbs_thread:1", actor_name: "A", cues: %{sound: true, web: false}})`, then `assert_push_event(view, "activity", %{context_key: "bbs_thread:1"})`. (Subscription is proven by the forward succeeding.)
  - **activity-notifications.AC3.3:** `Phoenix.LiveViewTest` (0.17.14) has `assert_push_event/4` but **no `refute_push_event`** — verify pass-through positively instead. Sequence: `StrangepathsWeb.Endpoint.broadcast("user:#{user.id}:notifications", "something_else", %{n: 1})` (a non-`activity` event on the topic), then `StrangepathsWeb.Endpoint.broadcast("user:#{user.id}:notifications", "activity", <valid payload with context_key "sentinel:1">)`. Then `assert_push_event(view, "activity", %{context_key: "sentinel:1"})` — if the interceptor had swallowed *or* mis-forwarded the first message, this first (and only) pushed `activity` would carry the wrong payload or the view would have crashed. Additionally: `send(view.pid, :some_unrelated_message)` then `assert Process.alive?(view.pid)` and `assert render(view) =~ "<"` (view still renders — the unrelated `handle_info` was not consumed into a crash). If the mounted LiveView has no catch-all `handle_info`, use a message it *does* handle, or a page known to have a catch-all (`/cosmos`).
  - **activity-notifications.AC3.4:** call `StrangepathsWeb.NotificationHooks.on_mount(:subscribe, %{}, %{"user_token" => nil}, %Phoenix.LiveView.Socket{})` directly (a struct with `transport_pid: nil` ⇒ `connected?/1` false) → returns `{:cont, socket}`, does not raise, does not call `Endpoint.subscribe`. A second variant: a valid `user_token` in the session but `connected?/1` false ⇒ still `{:cont, _}`, no subscribe (assert by `refute_receive %Phoenix.Socket.Broadcast{}` after a manual broadcast).

**Verification:**

Run: `PGPASSWORD=1zc3edg5 mix test test/strangepaths_web/live/notification_hooks_test.exs`
Expected: all tests pass.

**Commit:** `feat(notifications): NotificationHooks on_mount bus subscription`
<!-- END_TASK_1 -->

<!-- START_TASK_2 -->
### Task 2: Wrap the `:browser` LiveView cluster in `live_session :app`

**Verifies:** activity-notifications.AC3.5

**Files:**
- Modify: `lib/strangepaths_web/router.ex` — inside `scope "/", StrangepathsWeb do pipe_through(:browser) ... end` (lines 23–79), wrap **all `live/3` and `live/4` declarations** (currently lines 32–78: `/ost`, `/scenes*`, `/content*`, `/avatars/admin`, `/lab/cardgen`, `/codex*`, `/cosmos*`, `/ceremony*`, `/rumor*`, `/bbs*`, `/library*`) in a `live_session` block. Leave the `get(...)` routes (`/`, `/activity`, `/music/:guid`) where they are, outside the block.

**Implementation:**

The scope becomes (structure — keep every existing `live(...)` line verbatim, only add the wrapper):

```elixir
scope "/", StrangepathsWeb do
  pipe_through(:browser)

  get("/", PageController, :index)
  get("/activity", PageController, :activity)
  get("/music/:guid", MusicFileController, :serve)

  live_session :app, on_mount: {StrangepathsWeb.NotificationHooks, :subscribe} do
    live("/ost", OstLive)
    live("/ost/:id", SongLive)

    live("/scenes", Scenes)
    live("/scenes/archives", Scenes.Archives)
    live("/scenes/archives/elsewhere/:week", Scenes.Archives)
    live("/scenes/archives/:slug", Scenes.Archives)

    live("/content", ContentIndexLive)
    live("/content/:slug", ContentLive)

    live("/avatars/admin", AvatarAdminLive)

    live("/lab/cardgen", CardGenLive)

    live("/codex", DeckLive.Index, :index)
    live("/codex/new", DeckLive.Index, :new)
    live("/codex/:id", DeckLive.Show, :show)
    live("/codex/:id/show/edit", DeckLive.Show, :edit)

    live("/cosmos", CardLive.Index, :index)
    live("/cosmos/new", CardLive.Index, :new)
    live("/cosmos/:id", CardLive.Show, :show)
    live("/cosmos/:id/show/edit", CardLive.Show, :edit)

    live("/ceremony", CeremonyLive.Index, :index)
    live("/ceremony/new", CeremonyLive.Index, :new)
    live("/ceremony/:id", CeremonyLive.Show, :show)

    live("/rumor", RumorMapLive.Show, :show)
    live("/rumor/archive", RumorMapLive.Archive, :index)
    live("/rumor/archive/snapshot/:id", RumorMapLive.Archive, :snapshot)
    live("/rumor/snapshot/:id", RumorMapLive.Snapshot, :show)

    live("/bbs", BBSLive.BoardList, :index)
    live("/bbs/:board_slug", BBSLive.ThreadList, :index)
    live("/bbs/:board_slug/new", BBSLive.ThreadList, :new)
    live("/bbs/:board_slug/:thread_id", BBSLive.Thread, :show)

    live("/library", LibraryLive.FolioList, :index)
    live("/library/new", LibraryLive.FolioList, :new)
    live("/library/admin", LibraryLive.Admin)
    live("/library/:slug/compose", LibraryLive.Composer, :compose)
    live("/library/:slug/history", LibraryLive.FolioHistory, :show)
    live("/library/:slug", LibraryLive.Folio, :show)
  end
end
```

**Testing:**

- Test file: `test/strangepaths_web/live/notification_bus_smoke_test.exs` (create; integration, `use StrangepathsWeb.ConnCase`, `import Phoenix.LiveViewTest`).
- Log in a user. For each representative route — `/scenes`, `/rumor`, `/cosmos`, plus a folio and a BBS thread (create the minimal folio/thread records inline via `Strangepaths.Repo.insert!` or existing fixtures; for `/library/:slug` and `/bbs/:board_slug/:thread_id` you need real slugs/ids) — assert:
  - **activity-notifications.AC3.5:** `{:ok, view, html} = live(conn, route)` succeeds (no raise); `html` is non-empty.
  - **activity-notifications.AC3.5:** an assign the page is known to set is still present — e.g. for `/scenes` assert the rendered HTML contains a known scene-page marker; simplest robust check: `assert render(view) =~ "<main"` and the page's own title/nav text. (Keep assertions light; the point is "mounts without error after the wrap".)
  - **activity-notifications.AC3.2 (per page):** broadcast an `activity` payload to the user's topic and `assert_push_event(view, "activity", _)` — proving the hook is active on that page specifically.

**Verification:**

Run: `PGPASSWORD=1zc3edg5 mix test test/strangepaths_web/live/notification_bus_smoke_test.exs`
Expected: all representative pages mount and receive `assert_push_event`.

Run: `PGPASSWORD=1zc3edg5 mix compile` (plain — `--warnings-as-errors` fails on the untouched tree)
Expected: no *new* router warnings — specifically none mentioning `live_session`, "duplicate route", or the router module. Pre-existing unrelated warnings are unchanged.

**Commit:** `feat(notifications): wrap browser LiveViews in live_session :app`
<!-- END_TASK_2 -->

<!-- START_TASK_3 -->
### Task 3: Wrap the authenticated LiveView cluster in `live_session :app_authenticated`

**Verifies:** activity-notifications.AC3.5 (authenticated cluster)

**Files:**
- Modify: `lib/strangepaths_web/router.ex` — the `scope "/", StrangepathsWeb do ... pipe_through([:browser, :require_authenticated_user]) ... end` block (lines 113–122). Wrap only `live("/users/admin", UserAdminLive)` in a `live_session`. Leave `live_dashboard(...)` and the `get`/`put` routes as-is.

**Implementation:**

```elixir
scope "/", StrangepathsWeb do
  import Phoenix.LiveDashboard.Router
  pipe_through([:browser, :require_authenticated_user])

  live_dashboard("/dashboard", metrics: StrangepathsWeb.Telemetry)

  live_session :app_authenticated, on_mount: {StrangepathsWeb.NotificationHooks, :subscribe} do
    live("/users/admin", UserAdminLive)
  end

  get("/users/settings", UserSettingsController, :edit)
  put("/users/settings", UserSettingsController, :update)
  get("/users/settings/confirm_email/:token", UserSettingsController, :confirm_email)
end
```

**Testing:**

- Append to `test/strangepaths_web/live/notification_bus_smoke_test.exs`.
- Tests must verify:
  - **activity-notifications.AC3.5:** logged-in `{:ok, view, html} = live(conn, "/users/admin")` mounts without error; broadcasting an `activity` payload to the user's topic yields `assert_push_event(view, "activity", _)`.
  - Regression: an anonymous `live(conn, "/users/admin")` still redirects to log in (the `:require_authenticated_user` pipeline still applies — `live_session` does not replace it).

**Verification:**

Run: `PGPASSWORD=1zc3edg5 mix test test/strangepaths_web/live/notification_bus_smoke_test.exs`
Expected: green.

Run: `PGPASSWORD=1zc3edg5 mix test test/strangepaths_web` **before** the router edit and record the failure count; run it again after. Expected: the after-count is **≤** the before-count for router-adjacent files (no *new* failures attributable to the `live_session` wrap). The suite is heavily red at baseline (≈212 failures suite-wide) — do not fix unrelated failures; just prove you added none.

**Commit:** `feat(notifications): wrap authenticated LiveViews in live_session :app_authenticated`
<!-- END_TASK_3 -->

<!-- END_SUBCOMPONENT_A -->

---

## Phase 3 Done When

- `StrangepathsWeb.NotificationHooks.on_mount/4` exists and is referenced by both `live_session` blocks in the router.
- `PGPASSWORD=1zc3edg5 mix test test/strangepaths_web/live/notification_hooks_test.exs test/strangepaths_web/live/notification_bus_smoke_test.exs` is green.
- A connected mount of any wrapped LiveView with a logged-in user forwards `activity` broadcasts as `push_event("activity", …)`; a non-`activity` message on the topic and any unrelated `handle_info` message are not swallowed.
- A dead mount / logged-out visitor neither subscribes nor crashes.
- Representative pages (`/scenes`, `/library/:slug`, `/bbs/:board_slug/:thread_id`, `/rumor`, `/cosmos`, `/users/admin`) mount without error after the wrap.
- No client-side handler for `"activity"` exists yet (Phase 5) — the `push_event` is a no-op in the browser for now.
