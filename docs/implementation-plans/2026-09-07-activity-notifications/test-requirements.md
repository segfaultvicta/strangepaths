# Test Requirements — Activity Notifications

**Feature:** an opt-in, per-user layer of "louder" cues (per-source sound, OS desktop notification, in-app toast) over the four existing activity sources (scenes, Liminal Library, BBS/linkpearl, rumor map). Eight preference columns on `users` (4 sources × {sound, web}), all defaulting `false`; a `Strangepaths.Notifications.publish/3` that resolves recipients (honoring scene visibility and folio privacy), excludes the actor, gates on the recipient's saved flags, and broadcasts per-user on `user:#{id}:notifications`; two `live_session` blocks (`:app`, `:app_authenticated`) whose shared `on_mount` hook subscribes every LiveView and forwards `activity` payloads via `push_event`; and one global `ActivityNotifier` JS hook that decides sound / OS notification / toast / silence.

**Automated vs manual split.** Everything server-side — preference persistence, changeset scoping, recipient resolution, actor exclusion, preference gating, payload shape, bus subscription/forwarding, and which write paths do and do not publish — is covered by ExUnit (`Strangepaths.DataCase` for contexts, `StrangepathsWeb.ConnCase` + `Phoenix.LiveViewTest` for web). Everything client-side is **human-verified**: this repo has **no JavaScript test infrastructure** (no jest/vitest, no headless-browser harness), and the behaviors in question — browser permission prompts, autoplay policy, `document.hidden`/`hasFocus()`, OS notification surfaces, multi-tab Web Locks election, real-time coalescing — are not reachable from ExUnit at all. The manual matrix lives in **phase_05.md Task 6** (rows 1–14) and **phase_06.md Task 3** (full source × cue-type × focus-state walkthrough).

**Running tests.** All commands take the project's password prefix:

```
PGPASSWORD=1zc3edg5 mix test <file>
```

The existing suite is ~345 tests / ~212 pre-existing failures. New tests go in **new, self-contained files** wherever possible (`test/strangepaths/notifications_test.exs`, `test/strangepaths_web/live/notification_hooks_test.exs`, `test/strangepaths_web/live/notification_bus_smoke_test.exs`, `test/strangepaths_web/live/scene_notifications_test.exs`, `test/strangepaths_web/live/rumor_notifications_test.exs`) which must be **100% green**. Appends to pre-existing files (`accounts_test.exs` 4F, `user_settings_controller_test.exs` 3F, `bbs_test.exs` 2F, `library_test.exs` 2F) are held to **delta gates**: new tests pass, pre-existing failure count unchanged.

---

## AC → verification map

### AC1 — In-scope events publish; out-of-scope events do not

| AC | Type | Phase | Test file | Asserts |
|----|------|-------|-----------|---------|
| AC1.1 | automated (LiveView) + human | 4 (Task 3) | `test/strangepaths_web/live/scene_notifications_test.exs` | Mount `/scenes` as actor, submit the post event; recipient topic receives exactly one `activity` with `source: :scene, event: :new_post, context_key: "scene:" <> _` (`assert_receive` then `refute_receive`). **Human leg only if Phase 4 Task 3 deferred driving the LiveView** → phase_05 Task 6 row 13. |
| AC1.2 | automated (integration) | 4 (Task 2) | `test/strangepaths/bbs_test.exs` (append) | `BBS.create_thread/3` → one `activity` with `source: :bbs, event: :new_thread`; `BBS.create_post/3` → one with `event: :new_post`. |
| AC1.3 | automated (unit + integration) | 4 (Tasks 1, 2) | `test/strangepaths/notifications_test.exs`, `test/strangepaths/library_test.exs` (append) | `Library.save_body/3` → one `event: :body_edit` with non-empty `excerpt`; `Library.create_marginalia/3` → one `event: :marginalia`. Builder test asserts the excerpt contains no residual diff markup (`[+`, `[-`, `]`). |
| AC1.4 | automated (LiveView) | 4 (Task 4) | `test/strangepaths_web/live/rumor_notifications_test.exs` | `render_hook` the create-node event → one `activity` `source: :rumor, event: :node_create, context_key: "rumor"`; save-node with changed params → one `event: :node_update`. |
| AC1.5 | automated (integration) | 4 (Task 2) | `test/strangepaths/bbs_test.exs` (append) | `BBS.update_post/3` → `refute_receive` any `activity` broadcast. |
| AC1.6 | automated (integration) | 4 (Task 2) | `test/strangepaths/library_test.exs` (append) | `update_folio_title/2`, `update_folio_privacy/2`, `add_tag/2`, `remove_tag/2` each → `refute_receive` any `activity`. |
| AC1.7 | automated (LiveView) + human | 4 (Task 4) | `test/strangepaths_web/live/rumor_notifications_test.exs` | Behavioral: drive `update_node_position` (and delete / add-connection where drivable) — assert the matching `"rumor_map"` broadcast fires **and** `refute_receive` any `activity`. **Human leg** for ops that cannot be driven from a test → phase_05 Task 6 row 14. |
| AC1.8 | automated (integration) | 4 (Tasks 1, 3) | `test/strangepaths/notifications_test.exs`, `test/strangepaths_web/live/scene_notifications_test.exs` | `Scenes.system_message/3` (real system-post path): assert `"scene:#{id}"` receives `new_post` (path ran) and `refute_receive` any `activity`. Builder-level: `publish_scene_post/1` with `user_id: nil` returns `:ok`, broadcasts nothing. |
| AC1.9 | automated (unit) | 2 (Task 2), 4 (Task 1) | `test/strangepaths/notifications_test.exs` | Every payload from each of the six builders (`publish_bbs_new_thread/4`, `publish_bbs_new_post/3`, `publish_library_body_edit/3`, `publish_library_marginalia/3`, `publish_scene_post/1`, `publish_rumor_node/3`) carries non-empty string `title`, string `excerpt`, `url` starting with `/`, correctly-shaped `context_key`, and a `cues` map. |

### AC2 — Recipient resolution respects visibility

| AC | Type | Phase | Test file | Asserts |
|----|------|-------|-----------|---------|
| AC2.1 | automated (integration) | 2 (Tasks 1, 3) | `test/strangepaths/notifications_test.exs` | Open scene: every flagged non-actor user's topic receives the broadcast; actor's topic receives nothing. |
| AC2.2 | automated (integration) | 2 (Tasks 1, 3) | `test/strangepaths/notifications_test.exs` | Locked/backchannel scene: only dragons and whitelisted users receive (via `Scenes.can_view_scene?/2`); a non-whitelisted flagged user does not. |
| AC2.3 | automated (integration) | 2 (Tasks 1, 3) | `test/strangepaths/notifications_test.exs` | Non-private folio: all flagged non-actor users receive. |
| AC2.4 | automated (integration) | 2 (Tasks 1, 3) | `test/strangepaths/notifications_test.exs` | Private folio: only folio author + dragons receive; an unrelated flagged user does not. |
| AC2.5 | automated (integration) | 2 (Tasks 1, 3) | `test/strangepaths/notifications_test.exs` | `:bbs` and `:rumor` events reach every flagged user except the actor. |
| AC2.6 | automated (unit) | 2 (Task 2) | `test/strangepaths/notifications_test.exs` | When the actor is the only eligible recipient, `publish/3` returns `:ok` and no broadcast is sent (`refute_receive`). |

### AC3 — The bus reaches every authenticated page

| AC | Type | Phase | Test file | Asserts |
|----|------|-------|-----------|---------|
| AC3.1 | automated (LiveView) | 3 (Task 1) | `test/strangepaths_web/live/notification_hooks_test.exs` | On a connected mount of a `live_session` LiveView as a logged-in user, the session process is subscribed to `user:#{id}:notifications`. |
| AC3.2 | automated (LiveView) | 3 (Task 1) | `test/strangepaths_web/live/notification_hooks_test.exs` | A hand-published `activity` broadcast on that topic yields a `push_event("activity", payload)` to the session, whichever LiveView is mounted. |
| AC3.3 | automated (LiveView) | 3 (Task 1) | `test/strangepaths_web/live/notification_hooks_test.exs` | A non-`activity` message on the topic (and an unrelated `handle_info` message) is passed through unchanged — `attach_hook` returns `{:cont, socket}`, nothing is swallowed. |
| AC3.4 | automated (LiveView) | 3 (Task 1) | `test/strangepaths_web/live/notification_hooks_test.exs` | Disconnected (dead) mount does not subscribe and does not crash. |
| AC3.5 | automated (LiveView) | 3 (Tasks 2, 3) | `test/strangepaths_web/live/notification_bus_smoke_test.exs` | Scene, folio, BBS thread, rumor map, and one unrelated LiveView (`/cosmos`) mount without error with existing assigns intact after both `live_session` wraps (`:app`, `:app_authenticated`). |

### AC4 — Client cue-delivery rules

All AC4 rows are **human**: the `ActivityNotifier` hook is browser JS with no test harness in this repo, and each behavior depends on a browser-only signal (audio playback, `document.hidden`, `document.hasFocus()`, the OS notification surface).

| AC | Type | Phase | Justification | Manual step |
|----|------|-------|---------------|-------------|
| AC4.1 | human | 5 (Tasks 1, 2) | No JS test infra; audio playback is not observable from ExUnit. | phase_05 Task 6 **row 3** — A on `/rumor`, B posts in an open scene → A hears `scene.mp3` once (served from `/audio/notif/`). |
| AC4.2 | human | 5 (Task 2) | OS notification surface + `document.hidden` + click-to-focus are browser/OS behaviors. | phase_05 Task 6 **row 5** — A's tab hidden → OS notification with title/excerpt and `tag: "scene"`; click focuses the tab and navigates to `url`. |
| AC4.3 | human | 5 (Task 2) | Requires a focused tab on a different page — browser focus state. | phase_05 Task 6 **row 6** — A focused on `/rumor`, B edits a folio body → in-app toast (not OS notification), linking to `/library/<slug>`. |
| AC4.4 | human | 5 (Tasks 2, 5) | Depends on `data-notif-context` read at runtime + `document.hasFocus()`. | phase_05 Task 6 **row 4** — A viewing scene X focused: post in X → nothing; post in scene Y → sound. |
| AC4.5 | human | 5 (Task 2) | Combined sound+toast decision branch; browser-only. | phase_05 Task 6 **row 7** — `notif_bbs_sound` on / `_web` off, A on `/cosmos` focused, B posts a BBS reply → sound **and** toast. |
| AC4.6 | human | 5 (Task 2) | Autoplay rejection only occurs under a real browser gesture policy. | phase_05 Task 6 **row 12** — fresh tab, cue before any user gesture → no console error; toast/notification path still runs. |
| AC4.7 | human | 5 (Task 1), 6 (Task 1) | Audible distinctness is a listening judgment. | phase_05 Task 6 **row 8** + phase_06 Task 3 — one event per source, four audibly different CC0 cues from `/audio/notif/{scene,library,bbs,rumor}.mp3`. |

### AC5 — Preferences persistence and permission UX

| AC | Type | Phase | Test file / manual step | Asserts |
|----|------|-------|-------------------------|---------|
| AC5.1 | automated (unit) | 1 (Tasks 1, 2) | `test/strangepaths/accounts_test.exs` (append) | All 8 `notif_*` fields exist on `User`, are non-null with DB default `false`; a freshly inserted user has all 8 `false`. |
| AC5.2 | automated (unit + integration) | 1 (Tasks 3, 5) | `test/strangepaths/accounts_test.exs`, `test/strangepaths_web/controllers/user_settings_controller_test.exs` (append) | `Accounts.update_notification_prefs/2` persists each of the 8 fields; the `update_notification_prefs` controller action round-trips a toggle and reloads it from the DB. |
| AC5.3 | automated (unit) | 1 (Task 2) | `test/strangepaths/accounts_test.exs` (append) | `notification_prefs_changeset/2` casts exactly the 8 fields — a foreign key (e.g. `role`, `email`, `smart_unread`) in the attrs is not applied to the changeset. |
| AC5.4 | human | 1 (Task 6) | phase_05 Task 6 **row 1** (grant path); phase_01 Task 6 (deny path) | Browser permission prompt cannot be driven from ExUnit. Checking a `_web` box calls `Notification.requestPermission()` and the prompt appears. |
| AC5.5 | human | 1 (Task 6) | phase_01 Task 6 deny path (re-walk in phase_06 Task 3) | Permission denial is a browser-modal outcome. Denying reverts the just-checked `_web` box to unchecked and shows the inline note. |
| AC5.6 | human | 1 (Task 6) | phase_01 Task 6 / phase_06 Task 3 | `Notification.permission` is a browser global. With permission pre-denied, `_web` boxes render disabled with the note; `_sound` boxes stay enabled. |

### AC6 — Server-side preference gating

| AC | Type | Phase | Test file | Asserts |
|----|------|-------|-----------|---------|
| AC6.1 | automated (unit) | 2 (Task 2) | `test/strangepaths/notifications_test.exs` | Recipient with `notif_<source>_sound: true, _web: false` receives a payload whose `cues == %{sound: true, web: false}`. |
| AC6.2 | automated (unit) | 2 (Task 2) | `test/strangepaths/notifications_test.exs` | Recipient with both `<source>` flags false receives no broadcast for that source (`refute_receive`). |
| AC6.3 | automated (unit) | 2 (Task 2) | `test/strangepaths/notifications_test.exs` | Flipping a flag in the DB between two `publish/3` calls changes the second payload's `cues` — gating reads flag values at broadcast time, not from the client. |
| AC6.4 | automated (unit) | 2 (Task 2) | `test/strangepaths/notifications_test.exs` | Recipient flagged for one source only receives broadcasts for that source and none for the others. |

### AC7 — Cross-cutting behaviors

| AC | Type | Phase | Test file / manual step | Asserts |
|----|------|-------|-------------------------|---------|
| AC7.1 | automated (unit) + human | 2 (Task 2), 5 (Tasks 3, 6) | `test/strangepaths/notifications_test.exs`; phase_05 Task 6 **row 2**, phase_06 Task 3 | Server: an all-`false` user's topic receives zero `activity` broadcasts for any source. Human: no sound, no `#notif-toast-stack` in the DOM, no OS notification; unread badges and the `(N)` title counter behave exactly as pre-feature (the `#activity-notifier` element is `display:none` / `phx-update="ignore"` and inert). |
| AC7.2 | automated (unit) + human | 2 (Task 2), 4 (all tasks), 5 (Task 6) | `test/strangepaths/notifications_test.exs`, all Phase 4 test files; phase_05 Task 6 rows 3–9 | Server: actor exclusion in `publish/3` — the actor's own topic receives nothing in every AC2 test and in every Phase 4 wiring test (each uses a separate recipient). Human: performing an action yourself produces no cue in the UI. |
| AC7.3 | human | 5 (Task 2) | phase_05 Task 6 **row 10** | Web Locks election across two real tabs cannot be simulated in ExUnit. Two tabs open (`/rumor`, `/cosmos`) → cue fires in exactly one; devtools shows exactly one `isPrimary === true`. |
| AC7.4 | human | 5 (Task 2) | phase_05 Task 6 **row 10** (second half) | Lock release on tab close is a browser lifecycle event. Close the primary tab → the other becomes primary and resumes cueing. |
| AC7.5 | human | 5 (Task 2), 6 (Task 2) | phase_05 Task 6 **row 9**, phase_06 Task 3 | Coalescing is a wall-clock client-side debounce window. 3 scene posts within ~5 s → one cue reading "3 new posts in \<scene\>". |
| AC7.6 | human | 5 (Task 2) | phase_05 Task 6 **row 11** (optional) | Requires a browser/flag without `navigator.locks`. Cues still fire (every tab acts as primary; duplicate accepted). |

---

## Human verification checklist

Run against the dev server at `https://localhost:4001` with **two browser profiles / two users** (A = observer, B = actor). Source rows: phase_05.md Task 6 (1–14), phase_06.md Task 3.

- [ ] **1. Permission grant** (AC5.4) — A on `/users/settings`, enable "audio for scene posts" + "desktop for library edits"; the browser prompt appears on the first `_web` enable; grant it.
- [ ] **2. Permission deny + revert** (AC5.5) — enable another `_web` box and deny; the box reverts to unchecked and the inline note appears.
- [ ] **3. Pre-denied render state** (AC5.6) — with site notifications set to "denied" in browser settings, reload `/users/settings`: all 4 `_web` boxes are disabled with the note; all 4 `_sound` boxes are enabled.
- [ ] **4. All-`false` baseline** (AC7.1) — user with all 8 prefs off, while B generates events on every source: no sound, no `#notif-toast-stack` in the DOM, no OS notification; unread badges and the `(N)` title counter behave exactly as before.
- [ ] **5. Per-source sound** (AC4.1) — A on `/rumor` with scene audio on; B posts in an open scene → A hears `scene.mp3` exactly once.
- [ ] **6. Distinct sounds** (AC4.7) — trigger one event per source; the four cues from `/audio/notif/` are audibly different and loudness-matched.
- [ ] **7. Silence on own source** (AC4.4) — A viewing scene X with the tab focused; B posts in scene X → nothing at all. B posts in scene Y → A gets the scene sound. Spot-check `data-notif-context` is present on all four source pages (`/scenes`, `/library/<slug>`, `/bbs/<board>/<thread>`, `/rumor`).
- [ ] **8. OS notification only when hidden** (AC4.2) — A with scene desktop notifications on, switched to another app; B posts → OS notification with title + excerpt and `tag: "scene"`; clicking it focuses the tab and navigates to the URL. Confirm no OS notification is emitted while the tab is focused.
- [ ] **9. Toast when focused-elsewhere** (AC4.3) — A focused on `/rumor` with library desktop notifications on; B edits a folio body → in-app toast (not OS notification) linking to `/library/<slug>`.
- [ ] **10. Sound-only + toast** (AC4.5) — `notif_bbs_sound` on, `notif_bbs_web` off, A on `/cosmos` focused; B posts a BBS reply → both sound and toast.
- [ ] **11. Own-action suppression at the UI** (AC7.2) — A, with all 8 prefs on, posts a scene message / BBS reply / marginalia / creates a rumor node → no cue of any kind for A.
- [ ] **12. Two-tab dedupe** (AC7.3) — A opens `/rumor` and `/cosmos`; B posts → cue fires in exactly one tab (devtools: exactly one `isPrimary === true`).
- [ ] **13. Primary-tab failover** (AC7.4) — close the cueing tab; B posts again → the remaining tab now fires.
- [ ] **14. Burst coalescing** (AC7.5) — B posts 3 scene messages within ~5 s → A gets one cue reading "3 new posts in \<scene\>".
- [ ] **15. No-`navigator.locks` fallback** (AC7.6, optional) — in a browser/flag lacking Web Locks, cues still fire (duplicates across tabs acceptable).
- [ ] **16. Autoplay-rejection resilience** (AC4.6) — fresh tab, cue delivered before any user gesture → no console error; the toast/notification path still runs.
- [ ] **17. Deferred AC1.1 end-to-end** (only if Phase 4 Task 3 deferred the LiveView leg; else N/A) — A anywhere with scene audio on; B makes one real scene post → exactly one cue.
- [ ] **18. Deferred AC1.7 rumor out-of-scope ops** (only for ops Phase 4 Task 4 could not drive; else N/A) — A with all `notif_rumor_*` on; B moves a node, deletes a node, adds a connection, renames a layer → no cue for any.
- [ ] **19. Full matrix sweep** (phase_06 Task 3) — 4 sources × {sound only, web only, both} × {focused on source, focused elsewhere, hidden} × {single event, burst}; record pass/fail per row.
- [ ] **20. Known platform limits behave as documented** — iOS Safari: sound + toast only (no `Notification` constructor outside a PWA); Firefox: `window.focus()` in notification `onclick` ignored, target loads on next focus; no-`navigator.locks`: occasional duplicate cue.

---

## Coverage confirmation

Every acceptance criterion (AC1.1–AC1.9, AC2.1–AC2.6, AC3.1–AC3.5, AC4.1–AC4.7, AC5.1–AC5.6, AC6.1–AC6.4, AC7.1–AC7.6 — **43 total**) maps to at least one row above.

- **Automated only — 25:** AC1.2, AC1.3, AC1.4, AC1.5, AC1.6, AC1.8, AC1.9, AC2.1–AC2.6, AC3.1–AC3.5, AC5.1, AC5.2, AC5.3, AC6.1–AC6.4.
- **Human only — 14:** AC4.1–AC4.7 (7), AC5.4–AC5.6 (3), AC7.3–AC7.6 (4). All are browser-side: no JS test infra in the repo, plus browser-permission prompts, multi-tab Web Locks election, OS notification surfaces, autoplay policy, and wall-clock coalescing.
- **Both automated and human — 4:** AC1.1 (LiveView-driven scene post in Phase 4 **plus** manual fallback row 13 if that leg was deferred), AC1.7 (behavioral rumor-op tests **plus** manual fallback row 14 for undrivable ops), AC7.1 (server-side "no broadcast for all-`false` users" **plus** the manual no-visible-change sweep), AC7.2 (Phase 2 actor-exclusion tests and every Phase 4 wiring test **plus** the manual own-action row).

No AC is unmapped. Phase 6 introduces no new ACs — it re-walks the manual matrix and re-confirms the Phase 1–4 automated suites are green.
