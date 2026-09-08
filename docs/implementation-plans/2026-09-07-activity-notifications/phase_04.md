# Activity Notifications Implementation Plan — Phase 4

**Goal:** All four sources publish real events through the bus: BBS new threads/replies, Library body edits/marginalia, Scene IC & narrative posts (never system posts), and Rumor node create/update (never moves/deletes/connections/layers).

**Architecture:** Add six thin payload-builder functions to `Strangepaths.Notifications` (`publish_bbs_new_thread/4`, `publish_bbs_new_post/3`, `publish_library_body_edit/3`, `publish_library_marginalia/4`, `publish_scene_post/1`, `publish_rumor_node/3`). Each assembles the `meta` map (title / excerpt / url / context_key / actor_id / actor_name, plus `:scene` or `:folio` for visibility) and delegates to `publish/3` from Phase 2. Call sites become one-liners placed **immediately after the existing real-time broadcast** in each write path.

**Deviation from design (documented):** The design lists the call sites as `BBS.create_post/3 → publish(:bbs, :new_post, …)` etc. — i.e. build `meta` inline at each call site. This plan instead routes each call site through a named builder in `Notifications`. Rationale: (a) call-site diffs stay to one line, lowering regression risk in four hot write paths; (b) every builder is directly unit-testable by subscribing to a recipient topic, without driving the scene/rumor LiveViews (which carry heavy Presence/SceneServer setup). Trade-off: URL shapes and a little schema knowledge (`board.slug`, `folio.slug`, `node.id`) now live in `Notifications` rather than in each context. Accepted — it is the same knowledge the design would have inlined, just centralised. No AC is affected (`{source, event, context_key}` are unchanged).

**Tech Stack:** Elixir/Phoenix, ExUnit (`Strangepaths.DataCase`), `StrangepathsWeb.Endpoint.subscribe` + `assert_receive`.

**Scope:** Phase 4 of 6 from `docs/design-plans/2026-09-07-activity-notifications.md`.

**Test-suite baseline:** `PGPASSWORD=1zc3edg5 mix test` = 345 tests / ≈212 pre-existing failures suite-wide (out of scope). Per-file this phase touches: `bbs_test.exs` 2F, `library_test.exs` 2F. New files (`notifications_test.exs` additions, `scene_notifications_test.exs`, `rumor_notifications_test.exs`) must be 100% green. All whole-file / whole-suite gates are delta gates.

**Codebase verified:** 2026-09-08 — exact call sites and locals in scope:

| Source / event | File:line (anchor) | Locals in scope at insertion point |
|---|---|---|
| BBS new thread | `lib/strangepaths/bbs.ex:363` (after `Endpoint.broadcast("bbs_board:#{board.id}", "new_thread", …)`) | `board` (`%Board{}`, has `slug`), `user` (`%User{}`), `result == {:ok, {thread, post}}` — rebind `post` |
| BBS new reply | `lib/strangepaths/bbs.ex:437` (after `Endpoint.broadcast("bbs_thread:#{thread.id}", "new_post", …)`) | `thread` (`%Thread{}`, has `title`, `board_id`; preload `:board` for slug), `user`, `post` |
| BBS post edit | `lib/strangepaths/bbs.ex:452-466` `update_post/3` | **no publish — leave untouched** |
| Library body edit | `lib/strangepaths/library.ex:457` (right after `summary = body_diff_summary(folio.body, content)`) | `folio` (`%Folio{}`, has `title`, `slug`, `is_private`, `user_id`), `user_id` (integer), `content`, `summary` |
| Library marginalia | `lib/strangepaths/library.ex:869` (after `Endpoint.broadcast("library_folio:#{entry.folio_id}", "new_marginalia", …)`) | `entry` (`%Entry{}`, has `id`, `folio_id`), `user` (`%User{}`), `marginalia` (`%Marginalia{}`, has `content`) |
| Library title/tag/privacy | `update_folio_title/2` (`library.ex:383`), `update_folio_privacy(folio, is_private_boolean)` (`library.ex:389` — 2nd arg is a **bool**, not a map), `add_tag/2` (`library.ex:513`), `remove_tag/2` (`library.ex:525`) | **no publish — leave untouched** |
| Scene IC post | `lib/strangepaths_web/live/scenes.ex:566` (after `SceneServer.broadcast_post(scene.id, post)` in the `post_message` handler) | `scene` (`%Scene{}`), `post` (preloaded `[:user, :avatar]`, `post.user_id` set) |
| Scene narrative post | `lib/strangepaths_web/live/scenes.ex:617` (after `SceneServer.broadcast_post(scene.id, post)` in the `post_narrative` handler) | `scene`, `post` (preloaded, `post.user_id` set) |
| Scene system post | `Strangepaths.Scenes.system_message/3` (`scenes.ex:567-585`, the only other `SceneServer.broadcast_post` caller — calls `create_system_post/1` at `:422`, post has nil `user_id`) | **no publish — no call site added; AC1.8 satisfied structurally** |
| Rumor node create | `lib/strangepaths_web/live/rumor_map_live/show.ex:275` (after `Endpoint.broadcast("rumor_map", "node_created", %{node: node})`) | `node` (`%Node{}`, has `id`, `title`, `content`), `socket.assigns.current_user` |
| Rumor node update | `lib/strangepaths_web/live/rumor_map_live/show.ex:476-478` (after `Endpoint.broadcast("rumor_map", "node_updated", %{node: updated_node})`) | `updated_node` (`%Node{}`), `socket.assigns.current_user` |
| Rumor node move | `lib/strangepaths_web/live/rumor_map_live/show.ex:~311` (`"update_node_position"` → `"node_moved"`) | **no publish — leave untouched** |
| Rumor bulk seed | `lib/strangepaths_web/live/rumor_map_live/show.ex:~561` (`create_default_nodes` dragon handler — also broadcasts `"rumor_map"`/`"node_created"`) | **no publish — bulk seed, would be an N-node cue storm** |
| Rumor delete / connection / layer ops | elsewhere in `show.ex` | **no publish — leave untouched** |

Additional facts:
- `body_diff_summary/2` is **private** in `Strangepaths.Library` and returns diff-markup text (`[+word+]`, `[-word-]`, `...`). The body-edit builder receives the already-computed `summary` string and truncates it — no need to make the function public.
- `save_body/3` has only `user_id` (no user struct / name). The builder loads the actor via `Strangepaths.Accounts.get_user!/1` (one extra query; body saves are infrequent).
- Scene active pages have no per-slug route — url for scene events is `"/scenes"`; `context_key` is `"scene:#{scene.id}"`.
- Rumor deep-links via `"/rumor?node=#{id}"` (handled in `handle_params/3`); `context_key` is the literal `"rumor"`.
- `User` has `nickname` (used across the app for display names).

---

## Acceptance Criteria Coverage

### activity-notifications.AC1: In-scope events publish; out-of-scope events do not
- **activity-notifications.AC1.1 Success:** A new scene post (non-system) triggers exactly one `publish(:scene, :new_post, …)`.
- **activity-notifications.AC1.2 Success:** A new BBS thread triggers one `publish(:bbs, :new_thread, …)`; a new BBS reply triggers one `publish(:bbs, :new_post, …)`.
- **activity-notifications.AC1.3 Success:** A folio body save triggers one `publish(:library, :body_edit, …)` with a non-empty `excerpt`; a new marginalia triggers one `publish(:library, :marginalia, …)`.
- **activity-notifications.AC1.4 Success:** A rumor `node_created` triggers one `publish(:rumor, :node_create, …)`; a `node_updated` triggers one `publish(:rumor, :node_update, …)`.
- **activity-notifications.AC1.5 Failure:** A BBS post edit (`update_post`) triggers no publish.
- **activity-notifications.AC1.6 Failure:** A folio title, tag, or privacy change triggers no publish.
- **activity-notifications.AC1.7 Failure:** A rumor `node_moved`, `node_deleted`, or any connection/layer operation triggers no publish.
- **activity-notifications.AC1.8 Edge:** A system scene post (nil `user_id`) triggers no publish.
- **activity-notifications.AC1.9 Success:** Every published payload includes `title`, `excerpt`, `url`, `context_key`, and a `cues` map. *(payload shape already enforced by `publish/3` in Phase 2; re-checked here through real events.)*

---

<!-- START_SUBCOMPONENT_A (tasks 1-2) -->

<!-- START_TASK_1 -->
### Task 1: Payload-builder functions on `Strangepaths.Notifications`

**Verifies:** activity-notifications.AC1.9 (real-event payload shape); groundwork for AC1.1–AC1.4

**Files:**
- Modify: `lib/strangepaths/notifications.ex` (add public builders + a private `excerpt/1`; add `alias Strangepaths.Accounts`)

**Implementation:**

```elixir
  alias Strangepaths.Accounts

  @excerpt_limit 140

  # Collapse whitespace, drop markdown/diff markup, truncate with an ellipsis.
  defp excerpt(nil), do: ""

  defp excerpt(text) when is_binary(text) do
    cleaned =
      text
      # `body_diff_summary/2` output: unwrap [+ins+] / [-del-] to their inner words,
      # collapse its literal "..." separators to a single ellipsis.
      |> String.replace(~r/\[\+(.*?)\+\]/s, "\\1")
      |> String.replace(~r/\[-(.*?)-\]/s, "\\1")
      |> String.replace(~r/\.{3,}/, "… ")
      # markdown noise
      |> String.replace(~r/[*_`#>]/u, "")
      |> String.replace(~r/\s+/u, " ")
      |> String.trim()

    if String.length(cleaned) > @excerpt_limit do
      String.slice(cleaned, 0, @excerpt_limit - 1) <> "…"
    else
      cleaned
    end
  end

  # ---- BBS ---------------------------------------------------------------

  def publish_bbs_new_thread(board, thread, post, actor) do
    publish(:bbs, :new_thread, %{
      actor_id: actor.id,
      actor_name: post.display_name || actor.nickname,
      title: thread.title,
      excerpt: excerpt(post.content),
      url: "/bbs/#{board.slug}/#{thread.id}",
      context_key: "bbs_thread:#{thread.id}"
    })
  end

  def publish_bbs_new_post(thread, post, actor) do
    thread = Strangepaths.Repo.preload(thread, :board)

    publish(:bbs, :new_post, %{
      actor_id: actor.id,
      actor_name: post.display_name || actor.nickname,
      title: thread.title,
      excerpt: excerpt(post.content),
      url: "/bbs/#{thread.board.slug}/#{thread.id}",
      context_key: "bbs_thread:#{thread.id}"
    })
  end

  # ---- Library --------------------------------------------------------

  def publish_library_body_edit(folio, actor_id, diff_summary) do
    actor = Accounts.get_user!(actor_id)

    publish(:library, :body_edit, %{
      actor_id: actor.id,
      actor_name: actor.nickname,
      title: folio.title,
      excerpt: excerpt(diff_summary),
      url: "/library/#{folio.slug}",
      context_key: "folio:#{folio.id}",
      folio: folio
    })
  end

  def publish_library_marginalia(folio, _entry, marginalia, actor) do
    publish(:library, :marginalia, %{
      actor_id: actor.id,
      actor_name: actor.nickname,
      title: folio.title,
      excerpt: excerpt(marginalia.content),
      url: "/library/#{folio.slug}",
      context_key: "folio:#{folio.id}",
      folio: folio
    })
  end

  # ---- Scenes --------------------------------------------------------

  # Called from the scene LiveView right after SceneServer.broadcast_post/2 as
  # `publish_scene_post(%{post: post, scene: scene})`. The `when not is_nil(post.user_id)`
  # guard is the AC1.8 protection; the trailing `_` clause absorbs system posts.
  def publish_scene_post(%{post: post, scene: scene}) when not is_nil(post.user_id) do
    actor = Accounts.get_user!(post.user_id)

    publish(:scene, :new_post, %{
      actor_id: actor.id,
      actor_name: actor.nickname,
      title: scene.name,
      excerpt: excerpt(post.content),
      url: "/scenes",
      context_key: "scene:#{scene.id}",
      scene: scene
    })
  end

  def publish_scene_post(_), do: :ok

  # ---- Rumor -------------------------------------------------------

  # event :: :node_create | :node_update. Called from RumorMapLive.Show, which
  # supplies the acting user (the Rumor context never receives it).
  def publish_rumor_node(event, node, actor) when event in [:node_create, :node_update] do
    publish(:rumor, event, %{
      actor_id: actor.id,
      actor_name: actor.nickname,
      title: node.title || "a node",
      excerpt: excerpt(node.content),
      url: "/rumor?node=#{node.id}",
      context_key: "rumor"
    })
  end
```

> Note: `publish_scene_post/1` takes a single map so the LiveView call reads `Notifications.publish_scene_post(%{post: post, scene: scene})`. The `when not is_nil(post.user_id)` guard plus the trailing `def publish_scene_post(_), do: :ok` fully covers system posts; the primary guarantee remains that no call site is added on the `create_system_post` / `system_message/3` path.

**Testing:**

- Test file: `test/strangepaths/notifications_test.exs` (append; unit).
- Give one recipient user all 8 `notif_*` flags `true`; subscribe the test process to that user's topic. For each builder, call it with minimal real structs (insert a board/thread/post, folio, scene, node as needed) and:
  - **activity-notifications.AC1.9:** assert the received `payload` has string `:title` (non-empty), string `:excerpt`, string `:url` starting with `/`, string `:context_key` matching the expected shape, and `:cues == %{sound: true, web: true}`.
  - Assert `:source` / `:event` are the expected atoms per builder.
  - For `publish_library_body_edit/3` specifically: pass a `diff_summary` string that contains raw diff markup, e.g. `"The [+quick+] brown [-lazy-] fox ... jumps"`, and assert `payload.excerpt != ""` **and** `payload.excerpt` contains neither `"[+"` nor `"[-"` nor `"]"` (diff markup unwrapped) — it should read roughly `"The quick brown lazy fox … jumps"` — exact whitespace around the collapsed ellipsis is not asserted; the real assertion is the absence of `[+` / `[-` / `]` (**activity-notifications.AC1.3**, I6).
  - For `publish_scene_post/1` with `%{post: %{...post with user_id: nil...}, scene: scene}`: assert it returns `:ok` and `refute_receive` any broadcast (**activity-notifications.AC1.8**).

**Verification:**

Run: `PGPASSWORD=1zc3edg5 mix test test/strangepaths/notifications_test.exs`
Expected: all builder tests pass.

**Commit:** `feat(notifications): payload builders for the four sources`
<!-- END_TASK_1 -->

<!-- START_TASK_2 -->
### Task 2: Wire BBS + Library call sites

**Verifies:** activity-notifications.AC1.2, activity-notifications.AC1.3, activity-notifications.AC1.5, activity-notifications.AC1.6

**Files:**
- Modify: `lib/strangepaths/bbs.ex` — add `alias Strangepaths.Notifications` near the top aliases; in `create_thread/3` `case result do {:ok, {thread, post}} ->` branch (line ~362), rebind the post and call the builder after the two existing `Endpoint.broadcast` lines; in `create_post/3` `{:ok, post} ->` branch (line ~440), call the builder after the three existing `Endpoint.broadcast` lines. The `user` argument is in scope in both.
- Modify: `lib/strangepaths/library.ex` — add `alias Strangepaths.Notifications` near the top aliases; in `save_body/3`, after `summary = body_diff_summary(folio.body, content)` (line ~457), add the builder call; in `create_marginalia/3`, after the `Endpoint.broadcast("library_folio:#{entry.folio_id}", "new_marginalia", …)` (line ~869), add the builder call.

**Implementation:**

1. `bbs.ex` `create_thread/3` success branch:

```elixir
{:ok, {thread, post}} ->
  StrangepathsWeb.Endpoint.broadcast("bbs_board:#{board.id}", "new_thread", %{thread_id: thread.id})
  StrangepathsWeb.Endpoint.broadcast("bbs_boards", "board_activity", %{board_id: board.id})
  Notifications.publish_bbs_new_thread(board, thread, post, user)
  result
```

2. `bbs.ex` `create_post/3` success branch:

```elixir
{:ok, post} ->
  StrangepathsWeb.Endpoint.broadcast("bbs_thread:#{thread.id}", "new_post", %{post: post})
  StrangepathsWeb.Endpoint.broadcast("bbs_board:#{thread.board_id}", "thread_updated", %{thread_id: thread.id})
  StrangepathsWeb.Endpoint.broadcast("bbs_boards", "board_activity", %{board_id: thread.board_id})
  Notifications.publish_bbs_new_post(thread, post, user)
  {:ok, post}
```

3. `library.ex` `save_body/3`, inside `if count == 1 do` after the summary line:

```elixir
summary = body_diff_summary(folio.body, content)
record_folio_edit(folio.id, user_id, "body", summary)
Notifications.publish_library_body_edit(folio, user_id, summary)

:ok
```

4. `library.ex` `create_marginalia/3` success branch:

```elixir
{:ok, marginalia} ->
  StrangepathsWeb.Endpoint.broadcast(
    "library_folio:#{entry.folio_id}",
    "new_marginalia",
    %{marginalia: Repo.preload(marginalia, :user), entry_id: entry.id}
  )

  Notifications.publish_library_marginalia(
    get_folio!(entry.folio_id),
    entry,
    marginalia,
    user
  )

  {:ok, marginalia}
```

**Testing:**

- Test file: `test/strangepaths/bbs_test.exs` and `test/strangepaths/library_test.exs` (both exist; append — match each file's existing `use Strangepaths.DataCase` header). Baseline pre-existing failures: `bbs_test.exs` **2F**, `library_test.exs` **2F** — the gates below are delta gates (new tests pass, failure count unchanged).
- Set up: a recipient user with the relevant `notif_*` flags true (e.g. `notif_bbs_sound: true` / `notif_library_web: true`); an actor user; subscribe the test process to the recipient's `"user:#{id}:notifications"` topic.
- Tests must verify:
  - **activity-notifications.AC1.2:** `BBS.create_thread(board, actor, %{"title" => "T", "content" => "hello"})` → exactly one `%Phoenix.Socket.Broadcast{event: "activity", payload: %{source: :bbs, event: :new_thread, context_key: "bbs_thread:" <> _}}` received (`assert_receive` once, then `refute_receive` a second).
  - **activity-notifications.AC1.2:** `BBS.create_post(thread, actor, %{"content" => "reply"})` → one `payload.source == :bbs`, `payload.event == :new_post`.
  - **activity-notifications.AC1.5:** `BBS.update_post(post, actor, %{"content" => "edited"})` → `refute_receive %Phoenix.Socket.Broadcast{event: "activity"}`.
  - **activity-notifications.AC1.3:** `Library.save_body(folio, actor.id, "new body text")` (actor must hold the body lock — set `body_locked_by_id: actor.id` on the folio first) → one `payload.source == :library`, `payload.event == :body_edit`, `payload.excerpt != ""`.
  - **activity-notifications.AC1.3:** `Library.create_marginalia(entry, actor, %{"content" => "a note"})` → one `payload.event == :marginalia`.
  - **activity-notifications.AC1.6:** `Library.update_folio_title(folio, %{title: "new"})`, `Library.update_folio_privacy(folio, true)` (2nd arg is a boolean), `Library.add_tag(folio, "x")` (arity 2), `Library.remove_tag(folio, "x")` → `refute_receive %Phoenix.Socket.Broadcast{event: "activity"}` after each.

**Verification:**

Run: `PGPASSWORD=1zc3edg5 mix test test/strangepaths/bbs_test.exs test/strangepaths/library_test.exs test/strangepaths/notifications_test.exs`
Expected: `notifications_test.exs` fully green; `bbs_test.exs` / `library_test.exs` — new tests pass, failure count unchanged at 2F each (delta gate).

**Commit:** `feat(notifications): publish from BBS and Library write paths`
<!-- END_TASK_2 -->

<!-- END_SUBCOMPONENT_A -->

<!-- START_SUBCOMPONENT_B (tasks 3-4) -->

<!-- START_TASK_3 -->
### Task 3: Wire the Scene LiveView call sites

**Verifies:** activity-notifications.AC1.1, activity-notifications.AC1.8

**Files:**
- Modify: `lib/strangepaths_web/live/scenes.ex` — add `alias Strangepaths.Notifications` to the module aliases; in `handle_scene_event("post_message", …)` after `SceneServer.broadcast_post(scene.id, post)` (line ~566); in `handle_scene_event("post_narrative", …)` after `SceneServer.broadcast_post(scene.id, post)` (line ~617).

**Implementation:**

Both call sites get the same one-liner immediately after the existing `SceneServer.broadcast_post/2`:

```elixir
SceneServer.broadcast_post(scene.id, post)
Notifications.publish_scene_post(%{post: post, scene: scene})
```

(`post` is already `Repo.preload(post, [:user, :avatar])` at both sites and carries `post.user_id`; `scene` is `socket.assigns.current_scene`.)

**Testing:**

- Test file: `test/strangepaths_web/live/scene_notifications_test.exs` (create; integration, `use StrangepathsWeb.ConnCase`, `import Phoenix.LiveViewTest`). First check for `test/strangepaths_web/live/scenes_test.exs` and mirror its setup verbatim (scene fixture, user with `public_ascension`/posting rights, avatar).
- Tests must verify:
  - **activity-notifications.AC1.1 (primary — drive the LiveView):** mount `/scenes` as the actor, select a scene, subscribe a separate recipient (`notif_scene_sound: true`) to their notifications topic, then submit the scene's post form/event the way the page wires it (inspect `scenes.ex` / the template for the exact `phx-submit`/`phx-hook` name feeding `handle_scene_event("post_message", …)`). `assert_receive %Phoenix.Socket.Broadcast{event: "activity", payload: %{source: :scene, event: :new_post, context_key: "scene:" <> _}}` exactly once (`assert_receive` then `refute_receive` a duplicate).
  - **activity-notifications.AC1.8 (drive the real system path):** call `Strangepaths.Scenes.system_message("sys", false, scene.id)` (the actual production path that inserts a system post + calls `SceneServer.broadcast_post`), subscribe to `"scene:#{scene.id}"` and `assert_receive %{event: "new_post"}` (proves the path ran), and `refute_receive %Phoenix.Socket.Broadcast{event: "activity"}` on the recipient topic. This is a behavioral test, not code inspection.

> Fallback only if the scene LiveView genuinely cannot be driven (document why in the commit): keep AC1.8 as above (it does **not** need the LiveView — it calls `system_message/3` directly), keep the Task 1 direct-builder scene-payload assertion, mark AC1.1's end-to-end leg as **deferred to the Phase 5 manual matrix** (add an explicit row there: "post in a scene → exactly one cue"), and say so in the commit message. Do **not** mock `SceneServer` or `Notifications`.

**Verification:**

Run: `PGPASSWORD=1zc3edg5 mix test test/strangepaths_web/live/scene_notifications_test.exs`
Expected: new file fully green (it is new). The AC1.8 behavioral test must pass regardless of which AC1.1 approach is used.

**Commit:** `feat(notifications): publish scene IC and narrative posts`
<!-- END_TASK_3 -->

<!-- START_TASK_4 -->
### Task 4: Wire the Rumor LiveView call sites

**Verifies:** activity-notifications.AC1.4, activity-notifications.AC1.7

**Files:**
- Modify: `lib/strangepaths_web/live/rumor_map_live/show.ex` — add `alias Strangepaths.Notifications` to the module aliases; in `handle_rumormap_event("create_node", …)` after `Endpoint.broadcast("rumor_map", "node_created", %{node: node})` (line ~275); in `handle_rumormap_event("save_node", …)` after `Endpoint.broadcast("rumor_map", "node_updated", %{node: updated_node})` (line ~476). Do **not** touch `"update_node_position"` / `"node_moved"`, the `create_default_nodes` bulk-seed handler (`show.ex:~561`), node deletion, connection, or layer handlers.

**Implementation:**

1. `create_node` success branch:

```elixir
{:ok, node} ->
  StrangepathsWeb.Endpoint.broadcast("rumor_map", "node_created", %{node: node})
  Notifications.publish_rumor_node(:node_create, node, socket.assigns.current_user)

  log_rumor_change(socket, "node_created", %{ ... })   # unchanged
```

2. `save_node` success branch:

```elixir
{:ok, updated_node} ->
  # ... existing lock release ...
  StrangepathsWeb.Endpoint.broadcast("rumor_map", "node_updated", %{node: updated_node})
  Notifications.publish_rumor_node(:node_update, updated_node, socket.assigns.current_user)

  # ... existing diff/log/state code unchanged ...
```

**Testing:**

- Test file: `test/strangepaths_web/live/rumor_notifications_test.exs` (create; integration, `use StrangepathsWeb.ConnCase`, `import Phoenix.LiveViewTest`).
- Mount `/rumor` as a logged-in actor; subscribe a separate recipient (all `notif_rumor_*` flags true) to their notifications topic.
- Tests must verify:
  - **activity-notifications.AC1.4:** trigger the `create_node` event (`render_hook(view, "create_node", %{"x" => 10, "y" => 10})` or the page's actual event name/params) → `assert_receive %Phoenix.Socket.Broadcast{event: "activity", payload: %{source: :rumor, event: :node_create, context_key: "rumor"}}` once.
  - **activity-notifications.AC1.4:** trigger `save_node` with changed params → one `payload.event == :node_update`.
  - **activity-notifications.AC1.7 (behavioral, not inspection):** subscribe the test process to **both** `"rumor_map"` and the recipient's notifications topic. Trigger `update_node_position` (node move) via `render_hook(view, "update_node_position", %{"node_id" => id, "x" => 20, "y" => 20})`. `assert_receive %Phoenix.Socket.Broadcast{event: "node_moved"}` (proves the move path executed) **and** `refute_receive %Phoenix.Socket.Broadcast{event: "activity"}` (no cue). Do the same for a node delete and an add-connection event if their `handle_event` names/params can be read off `show.ex` and driven; each: assert its own `"rumor_map"` broadcast fires, refute an `"activity"` broadcast. Any op that genuinely can't be driven in a test → add an explicit row to the Phase 5 manual matrix ("move / delete a node, add a connection → no cue") and note the deferral in the commit; do not fall back to grep-only.

**Verification:**

Run: `PGPASSWORD=1zc3edg5 mix test test/strangepaths_web/live/rumor_notifications_test.exs`
Expected: new file fully green.

Run: `PGPASSWORD=1zc3edg5 mix test` and compare the failure count to the baseline recorded at the start of Phase 1 (≈212).
Expected: failure count is **not higher** than baseline (Phase 4 adds no regressions). Pre-existing unrelated failures stay untouched.

**Commit:** `feat(notifications): publish rumor node create and update`
<!-- END_TASK_4 -->

<!-- END_SUBCOMPONENT_B -->

---

## Phase 4 Done When

- `PGPASSWORD=1zc3edg5 mix test test/strangepaths/notifications_test.exs test/strangepaths_web/live/scene_notifications_test.exs test/strangepaths_web/live/rumor_notifications_test.exs` — the three new/extended-here files — pass 100%.
- `PGPASSWORD=1zc3edg5 mix test test/strangepaths/bbs_test.exs test/strangepaths/library_test.exs` — new tests pass; pre-existing failure counts unchanged (2F / 2F).
- `PGPASSWORD=1zc3edg5 mix test` whole-suite failure count ≤ the Phase 1 baseline (no regressions).
- Each in-scope write (BBS thread/reply, folio body save, marginalia, scene IC/narrative post, rumor node create/update) produces exactly one `activity` broadcast with the correct `source` / `event` / `context_key`.
- Excluded paths (`BBS.update_post`, folio title/tag/privacy change via `update_folio_title` / `update_folio_privacy` / `add_tag` / `remove_tag`, `system_message/3` system posts, rumor `node_moved` / node delete / connection / layer ops) produce none — verified behaviorally where drivable, otherwise via an explicit Phase 5 manual-matrix row.
- `payload.excerpt` for a body edit contains no residual diff markup (`[+`, `[-`, `]`).
- **AC7.2** ("never cued for your own event") is already guaranteed by `publish/3`'s actor exclusion (Phase 2 tests AC2.1/AC2.2/AC2.6) and is exercised again here: every Phase 4 test uses a *separate* recipient from the actor, and the actor's own topic (subscribed in the Task 1 tests) receives nothing.
- No client handler for `"activity"` yet — Phase 5.
