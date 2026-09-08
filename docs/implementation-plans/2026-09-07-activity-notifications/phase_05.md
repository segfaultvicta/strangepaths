# Activity Notifications Implementation Plan — Phase 5

**Goal:** `"activity"` payloads arriving at the browser become a sound, an OS notification, or an in-app toast per the design's decision rules — suppressed for the page you're already on and for your own actions, coalesced per source, and deduped across tabs so only the Web-Locks "primary" tab fires.

**Architecture:** One global JS hook `Hooks.ActivityNotifier`, mounted once via a hidden element in the LiveView layout. It: elects a primary tab with `navigator.locks`; on each `activity` event (primary only) reads the current page's `context_key` from a `[data-notif-context]` attribute, applies the suppression/coalesce/cue rules, plays a per-source `Audio`, shows `new Notification(...)` when `document.hidden`, or renders a hook-built toast otherwise. Four short CC0 audio files live under `priv/static/audio/notif/` (the `audio` prefix is already in the endpoint's `Plug.Static` allowlist). Each of the four source pages gains a `data-notif-context` attribute.

**Tech Stack:** Vanilla JS (LiveView JS hook, `this.handleEvent`), Web Locks API, Web Notification API, `HTMLAudioElement`, SCSS. **No JS test infrastructure exists** — verification for this phase is the manual test plan in `test-requirements.md` (executed by the human).

**Scope:** Phase 5 of 6 from `docs/design-plans/2026-09-07-activity-notifications.md`.

**Codebase verified:** 2026-09-08.

**Verification findings incorporated:**
- ✓ `assets/js/app.js`: hooks are collected on `let Hooks = {}` (line 28), each is a plain object with `mounted()` etc., and `Hooks` is passed to `new LiveSocket("/live", Socket, { …, hooks: Hooks })` (lines 3410–3430). Server→hook events use `this.handleEvent("name", cb)` (pattern used by `Hooks.MusicPlayer`, `Hooks.RumorMap`, etc.).
- ✓ `assets/` has **no** jest/vitest/mocha — `assets/package.json` holds only build deps. Manual verification only.
- ✓ Layout: `lib/strangepaths_web/templates/layout/live.html.heex` — 21 lines; `<.live_component module={StrangepathsWeb.MusicPlayerComponent} …/>` at line 19, `<%= @inner_content %>` at line 20. Add the hidden hook element next to the music component.
- ✓ `lib/strangepaths_web/endpoint.ex:19-23`: `plug(Plug.Static, at: "/", only: ~w(art audio assets fonts images uploads favicon.ico robots.txt))`. `audio` is allowlisted → serve sounds from `priv/static/audio/notif/*.mp3` at `/audio/notif/<source>.mp3`. **No endpoint change needed.** `priv/static/audio/` does not exist yet — create it.
- ✓ Source-page templates that need a `data-notif-context` attribute:
  - Scene: `lib/strangepaths_web/live/scenes.html.heex` (or the `~H` in `scenes.ex`) — scene identity is LiveView state (`@current_scene`), not the URL, so the attribute is required here.
  - Folio: `lib/strangepaths_web/live/library/folio.html.heex` — `@folio.id` in scope.
  - BBS thread: `lib/strangepaths_web/live/bbs/thread.html.heex` — `@thread.id` in scope.
  - Rumor: `lib/strangepaths_web/live/rumor_map_live/show.html.heex` — static `"rumor"`.
- ✓ SCSS: `assets/css/app.scss` (2450 lines) ends with dedicated `.library-*` block; BBS block is also a trailing dedicated block. Append a `.notif-toast*` block at the end, same convention.

**Known platform limits (from the design — document, don't fix):** iOS Safari can't use the `Notification` constructor in-browser (those users get sound + toast only); Firefox ignores `window.focus()` in a notification `onclick` (target loads on next focus); ~4% of browsers lack `navigator.locks` (every tab acts as primary — rare duplicate cue).

---

## Acceptance Criteria Coverage

### activity-notifications.AC4: Client cue-delivery rules
- **activity-notifications.AC4.1 Success:** With `cues.sound` true, an `activity` event plays the audio file for its `source`.
- **activity-notifications.AC4.2 Success:** With `cues.web` true and `document.hidden` true, an OS `Notification` is shown with the event title/excerpt and a `tag` equal to the source; clicking it focuses the tab and navigates to `url`.
- **activity-notifications.AC4.3 Success:** With `cues.web` true and the tab focused but on a different page than the event, an in-app toast is shown instead of an OS notification.
- **activity-notifications.AC4.4 Failure:** When the viewer is looking at the event's own source (`context_key` matches) with the tab focused, no sound, toast, or notification fires.
- **activity-notifications.AC4.5 Success:** With only `cues.sound` true, tab focused, on a different page, both the sound and a toast fire (so the viewer knows what happened).
- **activity-notifications.AC4.6 Edge:** A rejected `Audio.play()` promise is caught; the toast/notification path still runs.
- **activity-notifications.AC4.7 Edge:** Each of the four sources maps to a distinct audio file.

### activity-notifications.AC7: Cross-cutting behaviors
- **activity-notifications.AC7.1 Success:** With every one of a user's 8 flags `false`, that user's session receives zero `activity` broadcasts and the UI is byte-for-byte identical to pre-feature behavior.
- **activity-notifications.AC7.2 Success:** A user never receives a cue for an event they themselves triggered.
- **activity-notifications.AC7.3 Success:** With multiple tabs open, only the Web Locks primary tab emits a cue for a given event.
- **activity-notifications.AC7.4 Success:** When the primary tab closes, another open tab becomes primary and resumes emitting cues.
- **activity-notifications.AC7.5 Success:** A burst of same-source events within the coalesce window produces one cue whose text reflects the count ("N new … in <title>").
- **activity-notifications.AC7.6 Edge:** In a browser without `navigator.locks`, cues still fire (every tab acts as primary).

> AC7.1 and AC7.2 are guaranteed server-side (Phases 2 & 4) — this phase must not regress them. "byte-for-byte identical" in AC7.1 is read as **no visible or behavioral difference**: the one DOM addition is a permanent `display:none`, `phx-update="ignore"` `#activity-notifier` element that renders nothing and does nothing until an `activity` event arrives (which an all-`false` user never receives), and the `notif-toast-stack` element is created lazily only on the first toast, so it never exists for such a user.

---

<!-- START_TASK_1 -->
### Task 1: Four notification sound files

**Verifies:** activity-notifications.AC4.7 (asset side)

**Files:**
- Create: `priv/static/audio/notif/scene.mp3`
- Create: `priv/static/audio/notif/library.mp3`
- Create: `priv/static/audio/notif/bbs.mp3`
- Create: `priv/static/audio/notif/rumor.mp3`

**Implementation:**

Preferred: source four genuinely distinct **CC0** cues (freesound.org CC0 filter, or Kenney's CC0 UI audio pack), each < 20 KB and < 400 ms, normalised to a comfortable level, and record their provenance in `priv/static/audio/notif/CREDITS.txt`.

Fallback if CC0 files can't be sourced during this task — synthesise four distinct short blips (own work, effectively public domain) so the phase is executable; flag them for replacement in Phase 6:

```bash
mkdir -p priv/static/audio/notif
# scene: single mid tone; library: two-tone up; bbs: low blip; rumor: high shimmer
ffmpeg -f lavfi -i "sine=frequency=660:duration=0.18" -af "afade=t=out:st=0.12:d=0.06,volume=0.5" -y priv/static/audio/notif/scene.mp3
ffmpeg -f lavfi -i "sine=frequency=520:duration=0.09" -f lavfi -i "sine=frequency=780:duration=0.09" -filter_complex "[0][1]concat=n=2:v=0:a=1,afade=t=out:st=0.14:d=0.04,volume=0.5" -y priv/static/audio/notif/library.mp3
ffmpeg -f lavfi -i "sine=frequency=300:duration=0.16" -af "afade=t=out:st=0.10:d=0.06,volume=0.5" -y priv/static/audio/notif/bbs.mp3
ffmpeg -f lavfi -i "sine=frequency=1200:duration=0.14" -af "tremolo=f=40:d=0.6,afade=t=out:st=0.09:d=0.05,volume=0.4" -y priv/static/audio/notif/rumor.mp3
```

Add `priv/static/audio/notif/CREDITS.txt` naming the source/licence (or "synthesised placeholder — replace in Phase 6").

**Verification:**

Run: `ls -la priv/static/audio/notif/` → four `.mp3` files present, each < 20 KB.

Run the dev server and open `https://localhost:4001/audio/notif/scene.mp3` → the file downloads/plays (confirms `Plug.Static` serves the `audio` prefix). Repeat for the other three.

**Commit:** `feat(notifications): four per-source notification sounds`
<!-- END_TASK_1 -->

<!-- START_TASK_2 -->
### Task 2: `Hooks.ActivityNotifier` in `app.js`

**Verifies:** activity-notifications.AC4.1–AC4.7, activity-notifications.AC7.3–AC7.6 (client logic; manual verification)

**Files:**
- Modify: `assets/js/app.js` — add the hook object anywhere in the `Hooks.*` section (e.g. after `Hooks.MusicPlayer`, before `let csrfToken = …`).

**Implementation:**

```javascript
Hooks.ActivityNotifier = {
  mounted() {
    // ---- config ----
    this.COALESCE_DEBOUNCE_MS = 1500;   // wait for a burst to settle
    this.COALESCE_MAX_MS = 12000;       // …but never hold a cue longer than this
    this.TOAST_TTL_MS = 6000;
    this.TOAST_CAP = 4;

    this.SOUNDS = {
      scene: "/audio/notif/scene.mp3",
      library: "/audio/notif/library.mp3",
      bbs: "/audio/notif/bbs.mp3",
      rumor: "/audio/notif/rumor.mp3",
    };
    this.NOUN = {
      scene: "post", library: "update", bbs: "post", rumor: "node",
    };

    this.audio = {};
    Object.keys(this.SOUNDS).forEach((s) => {
      const a = new Audio(this.SOUNDS[s]);
      a.preload = "auto";
      a.volume = 0.5;
      this.audio[s] = a;
    });

    this.pending = {};        // source -> { count, payload, timer, maxTimer }
    this.isPrimary = false;
    this._toastRoot = null;

    // ---- multi-tab primary election (AC7.3, AC7.4, AC7.6) ----
    // ONE request. Its callback runs only once this tab actually holds the lock;
    // inside it we mark ourselves primary and return a promise that resolves only
    // on destroyed() — holding the lock (and primary status) until the tab closes,
    // at which point a queued tab's callback runs and it becomes primary (AC7.4).
    this._releasePrimary = null;
    if (navigator.locks && typeof navigator.locks.request === "function") {
      navigator.locks
        .request("sp_notif_primary", { mode: "exclusive" }, () => {
          this.isPrimary = true;
          return new Promise((resolve) => { this._releasePrimary = resolve; });
        })
        .catch(() => { this.isPrimary = true; }); // lock machinery failed → act anyway
    } else {
      this.isPrimary = true; // ~4% of browsers, AC7.6 — every tab acts
    }

    // ---- receive server events ----
    this.handleEvent("activity", (payload) => this.onActivity(payload));
  },

  destroyed() {
    if (this._releasePrimary) this._releasePrimary(); // frees the Web Lock → next tab promoted
    Object.values(this.pending).forEach((p) => {
      clearTimeout(p.timer); clearTimeout(p.maxTimer);
    });
  },

  currentContext() {
    const el = document.querySelector("[data-notif-context]");
    return el ? el.getAttribute("data-notif-context") : null;
  },

  onActivity(payload) {
    if (!this.isPrimary) return;                       // AC7.3

    // AC4.4: viewing the event's own source with the tab focused -> nothing.
    if (payload.context_key && payload.context_key === this.currentContext() && document.hasFocus()) {
      return;
    }

    const source = payload.source;
    const st = this.pending[source] || { count: 0, payload: null, timer: null, maxTimer: null };
    st.count += 1;
    st.payload = payload;
    clearTimeout(st.timer);
    st.timer = setTimeout(() => this.fire(source), this.COALESCE_DEBOUNCE_MS);
    if (!st.maxTimer) {
      st.maxTimer = setTimeout(() => this.fire(source), this.COALESCE_MAX_MS);
    }
    this.pending[source] = st;
  },

  fire(source) {
    const st = this.pending[source];
    if (!st) return;
    clearTimeout(st.timer); clearTimeout(st.maxTimer);
    delete this.pending[source];

    const p = st.payload;
    const count = st.count;
    const cues = p.cues || {};
    const noun = this.NOUN[source] || "update";
    const headline =
      count > 1
        ? `${count} new ${noun}s in ${p.title}`
        : (p.title ? `${p.title}` : "New activity");
    const body = count > 1 ? "" : (p.excerpt || "");

    // AC4.1 / AC4.6: sound, with rejected play() swallowed.
    if (cues.sound && this.audio[source]) {
      try {
        this.audio[source].currentTime = 0;
        const pr = this.audio[source].play();
        if (pr && pr.catch) pr.catch(() => {});
      } catch (_e) { /* ignore */ }
    }

    const hidden = document.hidden;

    if (cues.web && hidden && typeof window.Notification !== "undefined" && Notification.permission === "granted") {
      // AC4.2
      try {
        const n = new Notification(headline, { body, tag: source, renotify: false, data: { url: p.url } });
        n.onclick = (ev) => {
          ev.preventDefault();
          window.focus();
          if (p.url) window.location = p.url;
          n.close();
        };
      } catch (_e) {
        this.toast(headline, body, p.url); // iOS Safari etc.
      }
    } else if (cues.web && !hidden) {
      // AC4.3
      this.toast(headline, body, p.url);
    } else if (cues.sound && !hidden) {
      // AC4.5 — sound-only pref, focused, elsewhere: also show a toast so the
      // viewer knows what the sound was.
      this.toast(headline, body, p.url);
    }
    // (cues.sound && hidden && !cues.web) -> sound only, no visual. Intentional.
  },

  ensureToastRoot() {
    if (this._toastRoot && document.body.contains(this._toastRoot)) return this._toastRoot;
    const root = document.createElement("div");
    root.className = "notif-toast-stack";
    root.id = "notif-toast-stack";
    document.body.appendChild(root);
    this._toastRoot = root;
    return root;
  },

  toast(title, body, url) {
    const root = this.ensureToastRoot();
    while (root.children.length >= this.TOAST_CAP) root.removeChild(root.firstChild);

    const el = document.createElement(url ? "a" : "div");
    el.className = "notif-toast";
    if (url) { el.href = url; }
    el.innerHTML =
      `<span class="notif-toast-title"></span>` +
      (body ? `<span class="notif-toast-body"></span>` : "");
    el.querySelector(".notif-toast-title").textContent = title;
    if (body) el.querySelector(".notif-toast-body").textContent = body;

    const kill = () => { if (el.parentNode) el.parentNode.removeChild(el); };
    el.addEventListener("click", (e) => { if (!url) e.preventDefault(); kill(); });
    setTimeout(kill, this.TOAST_TTL_MS);
    root.appendChild(el);
  },
};
```

> **Primary-election check (executor):** in a real browser with two tabs open, confirm exactly one has `isPrimary === true` and that closing it promotes the other within ~1 s (Task 6 rows 10). During bring-up you may temporarily mirror `this.isPrimary` to `window.__notifPrimary`; remove before commit.

**Verification:** manual only (Task 6). Build must succeed:

Run: `mix assets.build`
Expected: esbuild completes with no errors.

**Commit:** `feat(notifications): ActivityNotifier client hook`
<!-- END_TASK_2 -->

<!-- START_TASK_3 -->
### Task 3: Mount the hook in the LiveView layout

**Verifies:** activity-notifications.AC7.1 (no visible DOM when idle)

**Files:**
- Modify: `lib/strangepaths_web/templates/layout/live.html.heex` — add one line directly after the `MusicPlayerComponent` line (line 19).

**Implementation:**

```heex
<.live_component module={StrangepathsWeb.MusicPlayerComponent} id="music-player" current_user={assigns[:current_user]} />
<div id="activity-notifier" phx-hook="ActivityNotifier" phx-update="ignore" style="display:none"></div>
<%= @inner_content %>
```

`phx-update="ignore"` keeps LiveView DOM patching away from the element; `display:none` guarantees zero visual footprint.

**Verification:**

Run: `mix assets.build` then start the dev server; load any page; confirm in devtools that `#activity-notifier` exists, is `display:none`, and the browser console shows the hook mounted (no errors). With all 8 prefs off, confirm no `notif-toast-stack` element is ever created.

**Commit:** `feat(notifications): mount ActivityNotifier in live layout`
<!-- END_TASK_3 -->

<!-- START_TASK_4 -->
### Task 4: `.notif-toast*` styles

**Files:**
- Modify: `assets/css/app.scss` — append a dedicated block at the end of the file.

**Implementation:**

```scss
/* ============ Activity notification toasts ============ */
.notif-toast-stack {
  position: fixed;
  top: 1rem;
  right: 1rem;
  z-index: 10000;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  max-width: min(22rem, calc(100vw - 2rem));
  pointer-events: none;
}

.notif-toast {
  pointer-events: auto;
  display: block;
  text-decoration: none;
  background: rgba(13, 13, 26, 0.96);
  border: 1px solid #2a2a4a;
  border-left: 3px solid #5050c0;
  border-radius: 4px;
  padding: 0.6rem 0.75rem;
  color: #d8d8f0;
  font-size: 0.85rem;
  line-height: 1.35;
  box-shadow: 0 6px 20px rgba(0, 0, 0, 0.4);
  cursor: pointer;
  animation: notif-toast-in 160ms ease-out;
}

.notif-toast:hover { border-left-color: #7a7ad8; }

.notif-toast-title { display: block; font-weight: 600; color: #9090e0; }
.notif-toast-body {
  margin-top: 0.15rem;
  color: #9a9ac0;
  overflow: hidden;
  text-overflow: ellipsis;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
}

@keyframes notif-toast-in {
  from { opacity: 0; transform: translateX(12px); }
  to   { opacity: 1; transform: translateX(0); }
}
```

**Verification:**

Run: `mix assets.build`
Expected: Sass compiles with no errors; `priv/static/assets/app.css` contains `.notif-toast`.

**Commit:** `feat(notifications): toast styles`
<!-- END_TASK_4 -->

<!-- START_TASK_5 -->
### Task 5: `data-notif-context` on the four source pages

**Verifies:** activity-notifications.AC4.4 (context suppression needs the attribute)

**Files:**
- Modify: `lib/strangepaths_web/live/scenes.html.heex` (or the `~H""` template in `lib/strangepaths_web/live/scenes.ex`) — put `data-notif-context={@current_scene && "scene:#{@current_scene.id}"}` on the outermost element of the scene view.
- Modify: `lib/strangepaths_web/live/library/folio.html.heex` — put `data-notif-context={"folio:#{@folio.id}"}` on the outermost element.
- Modify: `lib/strangepaths_web/live/bbs/thread.html.heex` — put `data-notif-context={"bbs_thread:#{@thread.id}"}` on the outermost element.
- Modify: `lib/strangepaths_web/live/rumor_map_live/show.html.heex` — put `data-notif-context="rumor"` on the outermost element.

**Implementation notes:**
- Exactly one element on the page should carry the attribute (the hook uses `querySelector`, first match wins).
- On the scene list page with no scene selected, `@current_scene` is `nil` → `nil && …` renders no attribute → context is `null` → cues fire normally. Correct.
- Verify each named `.heex` file exists; if a page renders from an inline `~H` in the `.ex` module instead, edit there. (BBS/Library LiveViews are documented to use sibling `.html.heex`; Scenes may be inline.)

**Verification:**

Run the dev server; on `/scenes` with a scene open, devtools → the root element has `data-notif-context="scene:<id>"`. Same spot check for `/library/<slug>`, `/bbs/<board>/<thread>`, `/rumor`.

**Commit:** `feat(notifications): per-page data-notif-context markers`
<!-- END_TASK_5 -->

<!-- START_TASK_6 -->
### Task 6: Manual verification pass (client half)

**Verifies:** activity-notifications.AC4.1–AC4.7, activity-notifications.AC7.1–AC7.6 (executed by the human; the executor records the script and results in `test-requirements.md` / the PR description)

**Files:** none (verification only).

**Manual matrix (two browser profiles / two users, dev server on `https://localhost:4001`):**

1. **Permissions:** User A `/users/settings` → enable "audio for scene posts" + "desktop for library edits", grant permission when prompted. (Deny path already checked in Phase 1.)
2. **AC7.1 baseline:** User B with all 8 prefs off — while User A generates events, confirm B's tabs: no sound, no toast DOM (`#notif-toast-stack` never created), no OS notification, unread badges + `(N)` title counter behave exactly as before.
3. **AC4.1 sound:** User A on `/rumor`; User B posts in an open scene → A hears `scene.mp3` once.
4. **AC4.4 suppression:** User A on `/scenes` viewing scene X, tab focused; User B posts in scene X → A gets **nothing**. User B posts in scene Y → A gets the scene sound (different context).
5. **AC4.2 OS notification:** User A enables "desktop for scene posts", switches to another app (tab hidden); User B posts in a visible scene → OS notification with title + excerpt, `tag: "scene"`; clicking it focuses the tab and navigates to `/scenes`.
6. **AC4.3 toast:** User A back on `/rumor`, tab focused, "desktop for library edits" on; User B edits a folio body → in-app toast (not OS notification), linking to `/library/<slug>`.
7. **AC4.5 sound-only + toast:** User A "audio for bbs" on, "desktop for bbs" off, on `/cosmos` focused; User B posts a BBS reply → sound **and** a toast.
8. **AC4.7 distinct sounds:** trigger one event per source; confirm four audibly different cues.
9. **AC7.5 coalesce:** User B posts 3 scene messages within ~5 s → User A gets **one** cue reading "3 new posts in <scene>".
10. **AC7.3 / AC7.4 multi-tab:** User A opens `/rumor` and `/cosmos` in two tabs; User B posts → cue fires in exactly one tab. Close that tab; User B posts again → the other tab now fires.
11. **AC7.6 no-locks:** (optional) in a browser/flag without `navigator.locks`, confirm cues still fire (possibly in both tabs).
12. **AC4.6 autoplay-blocked:** load User A's page and trigger a cue before any user gesture (fresh tab) → no console error; if `cues.web` applies, the toast/notification still appears.
13. **AC1.1 end-to-end (only if Phase 4 Task 3 deferred it):** User A anywhere with "audio for scene posts" on; User B makes one real scene post → User A gets exactly one cue.
14. **AC1.7 out-of-scope rumor ops (only for ops Phase 4 Task 4 could not drive):** User A with all `notif_rumor_*` on; User B moves a node, deletes a node, adds a connection, renames a layer → User A gets **no** cue for any of them.

**Done when:** every row above passes or its deviation is a documented known-platform-limit. Rows 13–14 only apply if Phase 4 explicitly deferred that leg; otherwise mark N/A.

**Commit:** `docs(notifications): manual client verification results` (if any notes/fixtures are added)
<!-- END_TASK_6 -->

---

## Phase 5 Done When

- `mix assets.build` succeeds; `#activity-notifier` mounts with no console error and is invisible.
- The four `/audio/notif/*.mp3` files serve over HTTP and are audibly distinct.
- Each of the four source pages carries exactly one `data-notif-context`.
- The `navigator.locks` primary election is verified in two live tabs: exactly one has `isPrimary === true`; closing it promotes the other.
- The manual matrix (Task 6) passes: correct sound per source; OS notification only when hidden; toast when focused-and-elsewhere; silence when viewing the source with focus; two-tab dedupe to one cue; burst coalescing to one summarised cue; all-`false` prefs → no visible or behavioral difference from pre-feature.
- No automated JS tests (none possible in this repo) — coverage is the recorded manual pass.
