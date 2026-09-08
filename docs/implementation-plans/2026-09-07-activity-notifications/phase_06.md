# Activity Notifications Implementation Plan — Phase 6

**Goal:** Tune the delivered experience — coalesce/toast timing, the four audio files, and volume balance — and walk the full source × cue-type × focus-state matrix once more.

**Architecture:** No new architecture. Constant tweaks in `Hooks.ActivityNotifier`, replacement/normalisation of the four audio assets, minor SCSS adjustments if the toast reads poorly in practice.

**Tech Stack:** Same as Phase 5.

**Scope:** Phase 6 of 6 from `docs/design-plans/2026-09-07-activity-notifications.md`.

**Codebase verified:** 2026-09-08 (targets are the files created in Phase 5).

**Verifies:** None. This is a tuning/polish phase with no acceptance criteria of its own — every AC is already covered and verified by Phases 1–5. Do not invent tests here; the deliverable is a tuned experience and a completed manual matrix.

---

<!-- START_TASK_1 -->
### Task 1: Finalise the four audio cues

**Files:**
- Modify/replace: `priv/static/audio/notif/{scene,library,bbs,rumor}.mp3`
- Modify: `priv/static/audio/notif/CREDITS.txt`

**Implementation:**
- If Phase 5 shipped synthesised placeholders, replace them now with the final selection (CC0 only). Otherwise confirm the Phase 5 files are the ones to keep.
- Normalise all four to the same perceived loudness (e.g. `ffmpeg -i in.mp3 -af loudnorm=I=-20:TP=-2:LRA=11 out.mp3`), keep each < 20 KB and < 400 ms.
- Confirm the four are clearly distinguishable in pitch/timbre and none is harsh at `volume = 0.5`.
- Update `CREDITS.txt` with final provenance/licence for each file.

**Verification:**
- `ls -la priv/static/audio/notif/` → four `.mp3`, each < 20 KB.
- Play all four back-to-back at hook volume — distinct, not grating.
- `mix assets.deploy` (production build) succeeds and the files are fingerprinted into `priv/static/cache_manifest.json` if applicable, or served directly (they are referenced by absolute `/audio/notif/...` paths in the hook, so no manifest lookup is required — confirm they still 200 in a `MIX_ENV=prod` boot).

**Commit:** `chore(notifications): finalise notification audio cues`
<!-- END_TASK_1 -->

<!-- START_TASK_2 -->
### Task 2: Tune coalesce window, toast timing and cap

**Files:**
- Modify: `assets/js/app.js` — the constants at the top of `Hooks.ActivityNotifier.mounted()` (`COALESCE_DEBOUNCE_MS`, `COALESCE_MAX_MS`, `TOAST_TTL_MS`, `TOAST_CAP`).

**Implementation:**
- With two users, generate realistic bursts (a fast back-and-forth scene exchange; several marginalia in a row) and adjust:
  - `COALESCE_DEBOUNCE_MS` — long enough that a rapid exchange collapses to one cue, short enough that a single post still cues within ~1–2 s. Design reference: ~12 s window; start at 1500 ms debounce / 12000 ms max and adjust.
  - `TOAST_TTL_MS` — long enough to read title + excerpt (~6 s baseline).
  - `TOAST_CAP` — how many stack before the oldest is dropped (~4 baseline).
- If the "N new posts in <title>" wording reads awkwardly for any source, adjust `this.NOUN` / the `headline` template. Keep the count visible (AC7.5).

**Verification:**
- Re-run manual matrix rows 9 (coalesce) and 6–7 (toast) from `phase_05.md` Task 6; the cadence should feel right, not spammy, not laggy.
- `mix assets.build` succeeds.

**Commit:** `chore(notifications): tune coalesce and toast timing`
<!-- END_TASK_2 -->

<!-- START_TASK_3 -->
### Task 3: Full matrix walkthrough + sign-off

**Files:** none (verification); optionally `docs/implementation-plans/2026-09-07-activity-notifications/manual-verification.md` capturing results.

**Implementation:**
- Walk every combination once: 4 sources × {sound only, web only, both} × {tab focused on source, tab focused elsewhere, tab hidden} × {single event, burst}.
- Confirm the known-platform-limit rows behave as documented (iOS Safari: sound + toast only; Firefox notification-click; no-`navigator.locks` duplicate).
- Confirm AC7.1 once more on a clean all-`false` account: zero DOM/sound/notification, unread badges and `(N)` title counter unchanged.
- Record pass/fail per row; file follow-ups for anything not covered by a documented limitation.

**Verification:**
- Matrix complete with no unexplained failures.
- `PGPASSWORD=1zc3edg5 mix test` — the Phases 1–4 automated suites still green.

**Commit:** `docs(notifications): full manual verification matrix`
<!-- END_TASK_3 -->

---

## Phase 6 Done When

- The four cues are CC0, loudness-matched, distinguishable, and not grating at normal volume.
- Coalesce/toast timing feels right in realistic use; burst text still shows the count.
- The full source × cue-type × focus-state matrix has been walked with no unexplained failures.
- All Phase 1–4 automated tests still pass; AC7.1 (complete silence for all-`false` users) re-confirmed.
