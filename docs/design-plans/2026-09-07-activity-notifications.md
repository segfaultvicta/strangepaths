# Activity Notifications Design

## Summary

This feature adds an opt-in layer of "louder" cues — sounds, OS desktop notifications, and in-app toasts — on top of the quiet activity signals the site already has (per-context unread badges, the `(N)` page-title counter). Each user independently chooses, per activity source (scenes, the Liminal Library, the BBS/linkpearl forum, the rumor map) and per cue type (audio, desktop notification), what they want to be alerted about — eight toggles in all, every one shipping OFF. A user who never opts in sees byte-for-byte the current behavior.

The design has three parts. **On the server**, a new `Strangepaths.Notifications` context exposes a single `publish/3` function that the four existing write paths call after a successful save. It resolves who should be told (honoring scene visibility and folio privacy), drops the person who triggered the event, filters that recipient list against each user's saved preference columns in one query, and sends a per-user `activity` broadcast carrying that recipient's resolved cue flags. **Delivery to every page is centralized** rather than threaded through ~17 LiveViews: a single `live_session` wraps all authenticated routes, and an `on_mount` hook subscribes each mounted LiveView to its user's `user:#{id}:notifications` topic and forwards `activity` payloads to the browser with `push_event`, using `attach_hook` so ordinary LiveView messages pass through untouched. **In the browser**, one global JS hook (`ActivityNotifier`) decides what to do with each payload: it stays silent for the page the viewer is already on and for the viewer's own actions, coalesces bursts into one summary cue, elects a single "primary" tab via the Web Locks API so multiple open tabs don't all fire, then plays the per-source sound, shows an OS `Notification` when the tab is hidden, or renders a dismissible toast when the tab is focused but on another page. Preferences live on the existing user settings page following the established `smart_unread_changeset` pattern, with a small script that requests browser notification permission the first time a desktop-notification toggle is enabled.

## Definition of Done

An opt-in, per-user system of "more vigorous" cues for site activity, delivered while at least one browser tab is open on the site. Off by default; nothing changes for users who don't opt in.

### Primary deliverables

1. **A per-user notification bus** — a `user:#{id}:notifications` PubSub topic (or equivalent shared mechanism) that every authenticated LiveView subscribes to, so cues fire regardless of which page the user is on.
2. **Four event sources publish to the bus:**
   - **Scene posts** — new IC/OOC posts in any scene the user can see (includes locked "backchannel" scenes). Not post edits, not system posts.
   - **Library** — folio body edits and new marginalia. Not title/tag/privacy changes.
   - **BBS / linkpearl** — new threads and new posts only. Not post edits, not pins/locks.
   - **Rumor map** — nodes created and nodes updated only. Not node moves, not node deletion, not connections, not layers.
3. **Per-user preferences** — for each of the 4 sources, an independent **audio** toggle and an independent **web-notification** toggle (8 toggles total). All default **OFF**. Live on the existing user settings page, following the `smart_unread` changeset pattern.
4. **Client-side delivery via one global JS hook:**
   - Distinct audio cue per source.
   - OS **Web Notification** when the tab is unfocused/hidden.
   - Sound **+ a dismissible in-app toast** (linking to the source) when the tab is focused but the user is on a different page than the event.
   - **No cue** when the user is actively viewing the exact source of the event with the tab focused.
   - **Suppress all cues** for events the user themselves triggered.
   - **Coalesce per source** — at most one cue per source per short window; bursts summarized (e.g. "3 new posts in <scene>").
   - **Cross-tab dedupe** — only one open tab (the "primary", elected via the Web Locks API) emits the cue.
   - Browser Notification permission requested when the user first enables any web-notification toggle.

### Success criteria

A user can enable, for example, "audio for scene posts" and "web notifications for folio edits" and nothing else. When someone else posts in any scene they can see, they hear the scene sound (once per burst) from whatever page they are on, or receive an OS notification if the tab is backgrounded. They are never cued for their own activity, nor for sources or cue-types they did not enable.

### Out of scope

- Any notification when no tab is open (web push, service workers, VAPID).
- A persistent "activity happened" indicator or notification tray/dropdown — separate later work.
- Metadata-churn events: thread pins/locks, tag changes, layer renames, node moves.
- Reworking existing notification surfaces (per-context unread badges, the `(N)` page-title counter) beyond the minimum needed to integrate.

## Acceptance Criteria

### activity-notifications.AC1: In-scope events publish; out-of-scope events do not
- **activity-notifications.AC1.1 Success:** A new scene post (non-system) triggers exactly one `publish(:scene, :new_post, …)`.
- **activity-notifications.AC1.2 Success:** A new BBS thread triggers one `publish(:bbs, :new_thread, …)`; a new BBS reply triggers one `publish(:bbs, :new_post, …)`.
- **activity-notifications.AC1.3 Success:** A folio body save triggers one `publish(:library, :body_edit, …)` with a non-empty `excerpt`; a new marginalia triggers one `publish(:library, :marginalia, …)`.
- **activity-notifications.AC1.4 Success:** A rumor `node_created` triggers one `publish(:rumor, :node_create, …)`; a `node_updated` triggers one `publish(:rumor, :node_update, …)`.
- **activity-notifications.AC1.5 Failure:** A BBS post edit (`update_post`) triggers no publish.
- **activity-notifications.AC1.6 Failure:** A folio title, tag, or privacy change triggers no publish.
- **activity-notifications.AC1.7 Failure:** A rumor `node_moved`, `node_deleted`, or any connection/layer operation triggers no publish.
- **activity-notifications.AC1.8 Edge:** A system scene post (nil `user_id`) triggers no publish.
- **activity-notifications.AC1.9 Success:** Every published payload includes `title`, `excerpt`, `url`, `context_key`, and a `cues` map.

### activity-notifications.AC2: Recipient resolution respects visibility
- **activity-notifications.AC2.1 Success:** For an open scene, a `:scene` event is broadcast to every user (with a scene flag enabled) except the actor.
- **activity-notifications.AC2.2 Success:** For a locked/backchannel scene, a `:scene` event is broadcast only to dragons and whitelisted users (minus the actor).
- **activity-notifications.AC2.3 Success:** For a non-private folio, a `:library` event reaches all flagged users except the actor.
- **activity-notifications.AC2.4 Failure:** For a private folio, a `:library` event reaches only the folio author and dragons (never other users), minus the actor.
- **activity-notifications.AC2.5 Success:** `:bbs` and `:rumor` events reach all flagged users except the actor.
- **activity-notifications.AC2.6 Edge:** When the actor is the only eligible recipient, no broadcast is sent.

### activity-notifications.AC3: The bus reaches every authenticated page
- **activity-notifications.AC3.1 Success:** On mount of any authenticated LiveView with a connected socket, the session is subscribed to `user:#{current_user.id}:notifications`.
- **activity-notifications.AC3.2 Success:** An `activity` broadcast on that topic results in a `push_event("activity", payload)` to that session, regardless of which LiveView is mounted.
- **activity-notifications.AC3.3 Failure:** A non-`activity` message on the topic (or any unrelated `handle_info` message) is passed through unchanged — the interceptor does not swallow it.
- **activity-notifications.AC3.4 Edge:** A disconnected (dead) mount does not subscribe and does not crash.
- **activity-notifications.AC3.5 Success:** Representative pages (scene, folio, BBS thread, rumor map, and one unrelated LiveView such as `/cosmos`) mount without error and with existing assigns intact after the `live_session` wrap.

### activity-notifications.AC4: Client cue-delivery rules
- **activity-notifications.AC4.1 Success:** With `cues.sound` true, an `activity` event plays the audio file for its `source`.
- **activity-notifications.AC4.2 Success:** With `cues.web` true and `document.hidden` true, an OS `Notification` is shown with the event title/excerpt and a `tag` equal to the source; clicking it focuses the tab and navigates to `url`.
- **activity-notifications.AC4.3 Success:** With `cues.web` true and the tab focused but on a different page than the event, an in-app toast is shown instead of an OS notification.
- **activity-notifications.AC4.4 Failure:** When the viewer is looking at the event's own source (`context_key` matches) with the tab focused, no sound, toast, or notification fires.
- **activity-notifications.AC4.5 Success:** With only `cues.sound` true, tab focused, on a different page, both the sound and a toast fire (so the viewer knows what happened).
- **activity-notifications.AC4.6 Edge:** A rejected `Audio.play()` promise is caught; the toast/notification path still runs.
- **activity-notifications.AC4.7 Edge:** Each of the four sources maps to a distinct audio file.

### activity-notifications.AC5: Preferences persistence and permission UX
- **activity-notifications.AC5.1 Success:** All 8 `notif_*` columns exist on `users`, non-null, default `false`.
- **activity-notifications.AC5.2 Success:** Toggling any of the 8 checkboxes on the settings page persists the new value.
- **activity-notifications.AC5.3 Failure:** `notification_prefs_changeset/2` ignores/rejects any key outside the 8 notification fields.
- **activity-notifications.AC5.4 Success:** Enabling a `_web` checkbox calls `Notification.requestPermission()`.
- **activity-notifications.AC5.5 Failure:** If the user denies the browser permission, the just-enabled `_web` checkbox reverts to unchecked and an inline note is shown.
- **activity-notifications.AC5.6 Edge:** When `Notification.permission === "denied"` at page load, `_web` checkboxes render disabled with the note; `_sound` checkboxes remain enabled.

### activity-notifications.AC6: Server-side preference gating
- **activity-notifications.AC6.1 Success:** A recipient with `notif_<source>_sound` true (and `_web` false) receives a broadcast whose `cues` is `%{sound: true, web: false}`.
- **activity-notifications.AC6.2 Success:** A recipient with both `<source>` flags false receives no broadcast for that source.
- **activity-notifications.AC6.3 Success:** Gating uses the flag values at broadcast time (a stale client cannot receive a cue type it is not entitled to).
- **activity-notifications.AC6.4 Edge:** A recipient with a flag enabled for one source but not another receives broadcasts only for the enabled source.

### activity-notifications.AC7: Cross-cutting behaviors
- **activity-notifications.AC7.1 Success:** With every one of a user's 8 flags `false`, that user's session receives zero `activity` broadcasts and the UI is byte-for-byte identical to pre-feature behavior (no toast DOM, no sound, no notification, unread badges and title counter unchanged).
- **activity-notifications.AC7.2 Success:** A user never receives a cue for an event they themselves triggered.
- **activity-notifications.AC7.3 Success:** With multiple tabs open, only the Web Locks primary tab emits a cue for a given event.
- **activity-notifications.AC7.4 Success:** When the primary tab closes, another open tab becomes primary and resumes emitting cues.
- **activity-notifications.AC7.5 Success:** A burst of same-source events within the coalesce window produces one cue whose text reflects the count ("N new … in <title>").
- **activity-notifications.AC7.6 Edge:** In a browser without `navigator.locks`, cues still fire (every tab acts as primary).

## Glossary

- **LiveView**: Phoenix's server-rendered UI model — the page's state lives on the server in a socket process; user events and server messages re-render and patch the DOM over a websocket. Most of this app's UI is LiveViews.
- **`live_session`**: A router construct that groups LiveView routes so they share `on_mount` hooks and so navigation between them stays on one websocket connection. New to this codebase; this design introduces exactly one, `:authenticated`, wrapping every logged-in route.
- **`on_mount` hook**: A function `live_session` runs during every LiveView mount in the session, before the LiveView's own `mount/3`. Used here to subscribe the session to the user's notification topic with no per-LiveView code.
- **`attach_hook`**: `Phoenix.LiveView.attach_hook/4` — injects a callback into a lifecycle stage (here `:handle_info`). The callback returns `{:halt, …}` to consume a message or `{:cont, …}` to let the LiveView handle it normally; this is how the bus intercepts `activity` broadcasts without swallowing other messages.
- **`push_event` / client hook**: `push_event/3` sends a named event from the server LiveView to a JS "hook" attached to a DOM element via `phx-hook`. The `ActivityNotifier` hook receives `"activity"` events this way.
- **PubSub / `Endpoint.broadcast` / `Endpoint.subscribe`**: Phoenix's publish-subscribe messaging over named string topics. Existing topics include `"scene:#{id}"`, `"rumor_map"`, `"music"`; this design adds `user:#{id}:notifications`, one topic per user.
- **`Phoenix.Socket.Broadcast`**: The struct a subscribed LiveView receives in `handle_info` when a PubSub message arrives (`%Broadcast{topic:, event:, payload:}`). The interceptor pattern-matches on it.
- **Context (Phoenix context)**: A plain module that is the public API boundary for a slice of domain logic (e.g. `Strangepaths.BBS`, `Strangepaths.Library`). `Strangepaths.Notifications` is a new one.
- **Ecto changeset / single-purpose changeset**: Ecto's mechanism for casting and validating a subset of a schema's fields before a DB write. `smart_unread_changeset/2` casts exactly one field; the new `notification_prefs_changeset/2` casts exactly the 8 notification fields and rejects anything else.
- **Dragon**: This app's admin role (the other role is `user`). Dragons can see locked scenes and private folios, so they appear in recipient resolution.
- **Scene / IC / OOC / system post / backchannel**: Scenes are collaborative roleplay pages. Posts are in-character (IC) or out-of-character (OOC). A *system post* has a nil `user_id` (generated, not authored) and is excluded. A *locked / backchannel* scene is visible only to dragons and a whitelist.
- **`can_view_scene?`**: `Scenes.can_view_scene?(scene, user)` — the existing visibility check the notification recipient resolver reuses for `:scene` events.
- **Liminal Library / folio / body / marginalia**: The Library is a collaborative essay-and-curation system. A *folio* has a long-form `body` (markdown) and threaded reader comments called *marginalia*. In-scope events are body edits and new marginalia; title/tag/privacy changes are not.
- **BBS / linkpearl**: The forum system (boards → threads → posts), styled as a retro "Aethernet" terminal; "linkpearl" is its in-world name. In-scope events are new threads and new replies only.
- **Rumor map / node**: An infinite-canvas node graph (`/rumor`). In scope: node creation and node updates. Out of scope: moves, deletes, connections, layers. Rumor publishes from the LiveView because the `Rumor` context functions never receive the acting user.
- **`SceneServer` / `broadcast_post`**: The GenServer that manages scene state; `SceneServer.broadcast_post` is the existing per-scene real-time push that the `:scene` publisher hooks alongside.
- **`MusicBroadcast` / `MusicPlayerComponent`**: The existing "cross-cutting concern rendered once in the layout" pattern (a component in `live.html.heex` with a `phx-hook`). This design follows it for client forwarding but diverges on subscription (centralized `on_mount` instead of every LiveView opting in).
- **`context_key`**: A short string identifying the subject of an event (`"scene:123"`, `"folio:45"`, `"bbs_thread:9"`, `"rumor"`). The client compares it to the page currently on screen to suppress redundant cues; also the extension point for a future activity indicator.
- **`cues` map**: `%{sound: boolean, web: boolean}` in each broadcast payload — the recipient's own resolved preference flags for that source, computed at broadcast time so a stale client can't act on a cue type it isn't entitled to.
- **Coalesce**: Collapsing a burst of same-source events within a short window (~12s) into one summarized cue ("3 new posts in <scene>").
- **Web Locks API (`navigator.locks`)**: A browser primitive for holding a named, origin-scoped lock across tabs. Used for *leader election*: the tab holding `sp_notif_primary` is the only one that fires cues, and the lock frees on tab close so another tab is promoted. ~4% of browsers lack it — there, every tab acts.
- **BroadcastChannel**: The cross-tab messaging primitive the music player uses. Mentioned as precedent; not used here because it offers no failover.
- **Web Notification API**: `Notification.requestPermission()` and the `new Notification(title, opts)` constructor for OS-level notifications; `tag` de-dupes, `renotify` controls re-alerting. Requires a secure context (HTTPS). iOS Safari can't use the constructor outside a PWA.
- **`document.hidden` / `document.hasFocus()`**: Browser signals for tab/visibility state. `hidden` true → OS notification; focused but on another page → toast; focused on the event's own source → nothing.
- **Toast**: A transient in-app message (here a hook-built top-right stack, auto-dismiss ~6s), shown when an OS notification would be unreliable or unwanted.
- **Web push / service workers / VAPID**: The stack required to notify a user with *no tab open*. Explicitly out of scope — this feature only works while a tab is open.
- **PWA**: Progressive Web App (installed to the OS). Relevant only as the caveat that iOS Safari needs one for the Notification constructor.
- **CC0**: A public-domain license; the four bundled sound files must be CC0.
- **ExUnit / `PGPASSWORD` prefix**: Elixir's test framework. Per project setup, test commands need a `PGPASSWORD` env prefix; new tests here are written to run in isolation because the full suite's health is unverified.

## Architecture

### The bus

A single `live_session :authenticated` (in `lib/strangepaths_web/router.ex`) wraps every authenticated route. Its `on_mount: {StrangepathsWeb.NotificationHooks, :subscribe}` runs one hook per LiveView mount:

- Loads the current user from the session token (same logic `StrangepathsWeb.LiveHelpers.assign_defaults/2` uses).
- When the socket is connected, `StrangepathsWeb.Endpoint.subscribe("user:#{user.id}:notifications")`.
- `Phoenix.LiveView.attach_hook(socket, :notifications, :handle_info, &handle_notification/2)`. `handle_notification/2` matches `%Phoenix.Socket.Broadcast{topic: "user:" <> _, event: "activity", payload: p}` and returns `{:halt, push_event(socket, "activity", p)}`; every other message returns `{:cont, socket}` so normal LiveView traffic is untouched.

No per-LiveView code changes. `live_session` is new to this codebase (nothing uses `live_session`/`on_mount`/`attach_hook` today); all authenticated routes go in one session so intra-app navigation never crosses a session boundary.

### Publish path

`Strangepaths.Notifications` (new context, `lib/strangepaths/notifications.ex`) exposes:

```elixir
@type source :: :scene | :library | :bbs | :rumor
@type event  :: :new_post | :new_thread | :body_edit | :marginalia | :node_create | :node_update

@spec publish(source, event, meta :: map) :: :ok
# meta keys:
#   :actor_id     integer            — excluded from recipients
#   :actor_name   String.t()
#   :title        String.t()         — scene name / folio title / thread title / node title
#   :excerpt      String.t()         — short plain-text preview (<= ~140 chars)
#   :url          String.t()         — where the cue links
#   :context_key  String.t()         — "scene:123" | "folio:45" | "bbs_thread:9" | "rumor"
#   :scene        Scenes.Scene.t()   — scene events only, for visibility filtering
#   :folio        Library.Folio.t()  — library events only, for visibility filtering
```

`publish/3` resolves recipients, applies server-side preference gating in one query, and for each surviving recipient calls:

```elixir
Endpoint.broadcast("user:#{id}:notifications", "activity", %{
  source: source, event: event,
  title: ..., excerpt: ..., url: ..., context_key: ...,
  cues: %{sound: boolean, web: boolean}   # this recipient's resolved flags for `source`
})
```

### Recipient resolution

| Source | Recipients (actor always excluded) |
|--------|------------------------------------|
| `:bbs` | all users |
| `:rumor` | all users |
| `:scene` | users for whom `Scenes.can_view_scene?(scene, user)` is true (open scene → everyone; locked/backchannel → dragon + whitelist) |
| `:library` | if `folio.is_private` → folio author + dragons; else all users |

### Server-side preference gating

Migration adds 8 non-null boolean columns (default `false`) to `users`:

```
notif_scene_sound    notif_scene_web
notif_library_sound  notif_library_web
notif_bbs_sound      notif_bbs_web
notif_rumor_sound    notif_rumor_web
```

`publish/3` issues one query over the recipient set: users where either column for `source` is `true`. The per-recipient `cues` map carries that user's two flags. Users with both flags `false` for the source are never returned, so no broadcast reaches them — an all-`false` user's session receives nothing and behaves exactly as today.

### Publisher call sites

Each call runs after a successful write, with the actor's `User` in scope:

- `Strangepaths.BBS.create_post/3` → `publish(:bbs, :new_post, …)`
- `Strangepaths.BBS.create_thread/3` → `publish(:bbs, :new_thread, …)`
- `Strangepaths.Library.save_body/3` → `publish(:library, :body_edit, …)` (excerpt from `body_diff_summary`)
- `Strangepaths.Library.create_marginalia/3` → `publish(:library, :marginalia, …)`
- `Strangepaths.Scenes.create_post` path (where `SceneServer.broadcast_post` fires) → `publish(:scene, :new_post, …)`; skip when `post.user_id` is nil (system posts)
- `StrangepathsWeb.RumorMapLive.Show` handlers, after the existing `Endpoint.broadcast("rumor_map", …)`: `node_created` → `publish(:rumor, :node_create, …)`, `node_updated` → `publish(:rumor, :node_update, …)`. Rumor publishes from the LiveView because the `Rumor` context functions never receive the acting user; `node_moved` publishes nothing.

### Client hook: `ActivityNotifier`

One hook, mounted once via a hidden element in `lib/strangepaths_web/templates/layout/live.html.heex` (alongside the existing `MusicPlayerComponent`). Responsibilities:

- **Current context.** Reads a `context_key` for the page the viewer is on (from `document.body[data-notif-context]`, written per-page, or derived from `window.location`; the contract is "a string or null"). Used to suppress cues for the thing already on screen.
- **Multi-tab primary election.** On mount: `navigator.locks.request("sp_notif_primary", {mode: "exclusive"}, () => new Promise(() => {}))`. The tab holding the lock is the primary and the only one that acts on `activity`. Lock frees on tab close; a queued tab is promoted. No `navigator.locks` (~4% of browsers) → every tab acts (accepted rare duplicate).
- **Per-event decision (primary only):**
  1. If `context_key === currentContext && document.hasFocus()` → do nothing.
  2. Coalesce per source: within a ~12s window, increment a counter and reset a short debounce rather than re-firing; cue text becomes "N new … in <title>".
  3. If `cues.sound` → play the per-source `Audio`; a rejected `play()` promise is caught and ignored.
  4. If `cues.web && document.hidden` → `new Notification(title, {body: excerpt, tag: source, renotify: false, data: {url}})`; `onclick` → `window.focus()` then `location = url`.
  5. If `cues.web && !document.hidden` → in-app toast instead (focused-tab OS notifications are unreliable across browsers).
  6. If only `cues.sound && !document.hidden` and context differs → sound + toast (so the viewer knows what fired).
- **Toast.** Hook-built DOM: fixed top-right stack, each toast = title + excerpt + link, auto-dismiss ~6s, click to dismiss, cap ~4 with overflow collapse. Styled by a `.notif-toast*` block in `assets/css/app.scss`.

### Preferences UI

New "Activity notifications" section in `lib/strangepaths_web/templates/user_settings/edit.html.heex`, next to the existing `smart_unread` control: a 4×2 checkbox grid (row per source, columns Sound / Desktop notification), posting to a new `update_notification_prefs` action in `lib/strangepaths_web/controllers/user_settings_controller.ex`. `Accounts.notification_prefs_changeset/2` casts exactly the 8 fields (mirrors `smart_unread_changeset/2`); `Accounts.update_notification_prefs/2` persists.

Permission handling (small hook/script on the settings form): when a `_web` box goes unchecked→checked, call `Notification.requestPermission()`; on denial, revert that box and show an inline note; if `Notification.permission === "denied"` at load, render `_web` boxes disabled with the note. Sound boxes are never gated.

## Existing Patterns

- **Cross-cutting LiveView concern via a shared helper + a persistent layout component.** `StrangepathsWeb.MusicBroadcast` + `MusicPlayerComponent` (rendered once in `live.html.heex`, `phx-hook="MusicPlayer"`, `push_event` from `update/2`) is the template this design follows for the client-forwarding half. This design **diverges** on the subscription half: instead of every LiveView calling `subscribe_to_music()` in `mount` and adding a `forward_music_event/2` clause to `handle_info`, the notification bus centralizes subscription in a `live_session` `on_mount` hook with `attach_hook(:handle_info, …)`. Justification: the music pattern touches ~17 modules for each new concern; `on_mount` is a one-time router change and the LiveView-0.17.5-supported idiom for exactly this ("respond to global broadcasts in the layout"). The music pattern remains untouched.
- **PubSub via `StrangepathsWeb.Endpoint.broadcast/3` and `Endpoint.subscribe/1`** on string topics (`"scene:#{id}"`, `"library_folio:#{id}"`, `"bbs_boards"`, `"rumor_map"`, `"music"`). The `user:#{id}:notifications` topic follows this convention.
- **Per-user boolean preference:** `Accounts.User.smart_unread` — a boolean field with a dedicated single-purpose changeset (`smart_unread_changeset/2`) and a settings-page control. The 8 notification columns replicate this exactly.
- **Existing per-source real-time broadcasts** already exist and carry actor identity where needed: scenes `SceneServer.broadcast_post` (`post.user_id`), Library `save_body` (`updated_by_id`) and `create_marginalia` (`marginalia.user`), BBS `create_post`/`create_thread` (`bbs_thread:{id}` / `bbs_board:{id}` / `bbs_boards`). Rumor's `"rumor_map"` broadcasts do **not** carry an actor, which is why rumor notifications publish from the LiveView.
- **Cross-tab coordination precedent:** `MusicPlayer` uses `BroadcastChannel('strangepaths_music')`. This design uses the Web Locks API instead for leader election (BroadcastChannel gives no failover); both are origin-scoped browser primitives in the same spirit.
- **Static assets** served from `priv/static/`; the four sound files go in `priv/static/sounds/notif/`.
- **Tests** run with a `PGPASSWORD` prefix (see project memory); new tests are written to run in isolation because the existing suite's health is unverified.

## Implementation Phases

<!-- START_PHASE_1 -->
### Phase 1: Preferences schema + settings UI

**Goal:** Users can set 8 notification preferences; nothing consumes them yet (feature ships inert).

**Components:**
- Migration in `priv/repo/migrations/` — adds `notif_{scene,library,bbs,rumor}_{sound,web}` boolean columns to `users`, `null: false, default: false`.
- `Strangepaths.Accounts.User` — 8 fields added to the schema; `notification_prefs_changeset/2` casting exactly those 8 (pattern: `smart_unread_changeset/2`).
- `Strangepaths.Accounts` — `update_notification_prefs/2`.
- `lib/strangepaths_web/controllers/user_settings_controller.ex` — `update_notification_prefs` action + route in `router.ex`.
- `lib/strangepaths_web/templates/user_settings/edit.html.heex` — "Activity notifications" section, 4×2 checkbox grid, explanatory copy.
- Small JS on the settings form — `Notification.requestPermission()` on `_web` enable, revert-on-deny, disabled state when `permission === "denied"`.

**Dependencies:** None.

**Done when:** Migration runs; toggling any checkbox persists to `users`; `notification_prefs_changeset/2` rejects keys outside the 8; denying the browser permission reverts the just-checked `_web` box. Covers `activity-notifications.AC5.*`.
<!-- END_PHASE_1 -->

<!-- START_PHASE_2 -->
### Phase 2: `Strangepaths.Notifications` context

**Goal:** `publish/3` resolves recipients + gates on preferences + broadcasts, verified against synthetic events. No caller yet.

**Components:**
- `lib/strangepaths/notifications.ex` — `publish/3`, recipient resolution per source (`can_view_scene?` for scenes, `is_private` for folios, all-users for bbs/rumor), one preference-gating query, per-recipient `Endpoint.broadcast("user:#{id}:notifications", "activity", %{… cues: %{sound, web}})`. Actor excluded from recipients.

**Dependencies:** Phase 1 (columns exist).

**Done when:** Tests (subscribing to `user:#{id}:notifications` in-test) confirm: open-scene event reaches all non-actor users with a scene flag on; locked-scene event reaches only dragon + whitelisted; private-folio event reaches only author + dragons; actor never receives; all-`false` user never receives; `cues` map matches the recipient's two columns. Covers `activity-notifications.AC2.*`, `activity-notifications.AC6.*`.
<!-- END_PHASE_2 -->

<!-- START_PHASE_3 -->
### Phase 3: The bus (`live_session` + `on_mount`)

**Goal:** Every authenticated LiveView subscribes to the user topic and forwards `activity` payloads to the client, with no per-LiveView code and no behavioral regression.

**Components:**
- `lib/strangepaths_web/live/notification_hooks.ex` — `on_mount(:subscribe, …)` loads user, subscribes when connected, `attach_hook(:handle_info, …)`; interceptor halts on `activity`, passes everything else through.
- `lib/strangepaths_web/router.ex` — authenticated routes wrapped in `live_session :authenticated, on_mount: {…, :subscribe}`.

**Dependencies:** Phase 2 (topic contract defined).

**Done when:** A representative page per area (scene, folio, bbs thread, rumor, plus one unrelated LiveView e.g. `/cosmos`) mounts without error and existing assigns/behavior are intact; a hand-published `activity` broadcast to `user:#{id}:notifications` results in a `push_event("activity", …)` to that session. Covers `activity-notifications.AC3.*`.
<!-- END_PHASE_3 -->

<!-- START_PHASE_4 -->
### Phase 4: Publisher wiring

**Goal:** All four sources publish real events through the bus.

**Components:**
- `Strangepaths.BBS.create_post/3`, `create_thread/3` — `publish(:bbs, …)` after existing broadcasts.
- `Strangepaths.Library.save_body/3`, `create_marginalia/3` — `publish(:library, …)` after existing broadcasts.
- `Strangepaths.Scenes` — `publish(:scene, :new_post, …)` on the `create_post` path; skip nil-`user_id` system posts.
- `StrangepathsWeb.RumorMapLive.Show` — `publish(:rumor, :node_create/:node_update, …)` after the `node_created` / `node_updated` `"rumor_map"` broadcasts only.

**Dependencies:** Phase 2, Phase 3.

**Done when:** Tests confirm each in-scope write triggers exactly one `activity` broadcast with the right `source`/`event`/`context_key`, and excluded paths (`BBS.update_post`, folio title/tag/privacy change, `Scenes` system post, rumor `node_moved`/`node_deleted`/connection/layer ops) trigger none. Covers `activity-notifications.AC1.*`, `activity-notifications.AC4.*`.
<!-- END_PHASE_4 -->

<!-- START_PHASE_5 -->
### Phase 5: Client hook + delivery

**Goal:** `activity` payloads become sound / OS notification / toast per the decision rules, deduped across tabs.

**Components:**
- `assets/js/app.js` — `Hooks.ActivityNotifier`: Web Locks primary election; per-event decision (context+focus suppression, per-source coalescing, sound, `Notification` with `tag`, toast); catches rejected `Audio.play()`.
- `lib/strangepaths_web/templates/layout/live.html.heex` — hidden hook element.
- `assets/css/app.scss` — `.notif-toast*` block.
- `priv/static/sounds/notif/{scene,library,bbs,rumor}.mp3` — four CC0 cues, <20 KB / <400 ms each, distinct pitch/timbre.
- Per-page `context_key` mechanism (data attribute or location-derived).

**Dependencies:** Phase 3 (client receives `activity`), Phase 4 (real events to exercise).

**Done when:** Manual test plan passes — permission grant/deny; correct sound per source; OS notification only when `document.hidden`; toast when focused-and-elsewhere; silence when viewing the source with focus; two-tab dedupe to one cue; burst coalescing to one summarized cue; all-`false` prefs → complete silence. (No JS test infra in repo; verification is the manual plan.) Covers the client half of `activity-notifications.AC1.*`, `activity-notifications.AC4.*`, `activity-notifications.AC7.*`.
<!-- END_PHASE_5 -->

<!-- START_PHASE_6 -->
### Phase 6: Polish

**Goal:** Tune the experience.

**Components:** coalesce-window and toast timing/cap tuning in `ActivityNotifier`; final selection/normalization of the four audio files; sound-level balance; manual test-plan walkthrough of every source × cue-type × focus-state combination.

**Dependencies:** Phase 5.

**Done when:** Full manual matrix walked; no known rough edges; the four cues are distinguishable and not grating at normal volume.
<!-- END_PHASE_6 -->

## Additional Considerations

**Known platform limitations (documented, not fixed):**
- **iOS Safari** cannot use the `Notification` constructor in-browser (non-PWA). iOS users get sound + toast only, and only while a tab is open and focused. Desktop Safari is unaffected.
- **Firefox** ignores `window.focus()` in a notification's `onclick`; the target still loads on the next focus. Accepted.
- **No `navigator.locks`** (~4% of browsers): every tab acts as primary — occasional duplicate cue. Accepted.
- **Coalescing is per-primary-tab.** In practice only the primary cues, so this is effectively per-user; a primary handoff mid-burst could double one summary. Minor.

**HTTPS:** the Notification and Web Locks APIs require a secure context. The app already serves HTTPS in dev (port 4001) and prod (Fly), so no change.

**Testing:** the existing ExUnit suite's health is unverified. New tests are written self-contained and run in isolation (`mix test <file>` with the `PGPASSWORD` prefix); repairing unrelated pre-existing failures is out of scope for this work.

**Extensibility:** the `context_key` in the payload and the `source`/`event` taxonomy leave room for a later persistent "activity happened" indicator (explicitly out of scope now) to consume the same broadcasts without a new bus.
