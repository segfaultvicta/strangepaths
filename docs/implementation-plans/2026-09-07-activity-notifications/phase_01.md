# Activity Notifications Implementation Plan — Phase 1

**Goal:** Users can set 8 activity-notification preferences on the settings page; nothing consumes them yet (the feature ships inert).

**Architecture:** Add 8 non-null boolean columns to `users` (default `false`), a single-purpose `notification_prefs_changeset/2` on the `User` schema that casts exactly those 8 fields, an `Accounts.update_notification_prefs/2` context function, a new `update_notification_prefs` clause in `UserSettingsController.update/2`, a 4×2 checkbox grid in the settings template, and a small inline `<script>` that requests browser Notification permission the first time a `_web` box is enabled.

**Tech Stack:** Elixir/Phoenix 1.6, Ecto migration, Phoenix HTML `.form` component, plain inline JS (no build-step hook needed on this non-LiveView page).

**Scope:** Phase 1 of 6 from `docs/design-plans/2026-09-07-activity-notifications.md`.

**Codebase verified:** 2026-09-08 (three `codebase-investigator` passes).

**Test-suite baseline (measured 2026-09-08, `PGPASSWORD=1zc3edg5 mix test`):** the full suite is **345 tests / 212 failures** — pre-existing and out of scope per the design ("suite health is unverified"). Per-file baselines this phase touches: `test/strangepaths/accounts_test.exs` → 59 tests / **4 pre-existing failures**; `test/strangepaths_web/controllers/user_settings_controller_test.exs` → 9 tests / **3 pre-existing failures**. Every "Expected" gate below is a **delta** gate: the *new* tests added by the task pass, and the pre-existing failure count for the file is unchanged. Do **not** repair unrelated failures. `mix compile --warnings-as-errors` also fails on the untouched tree — use plain `mix compile` and require no *new* warnings in touched files.

**Verification findings incorporated:**
- ✓ `smart_unread` field at `lib/strangepaths/accounts/user.ex:32`; `smart_unread_changeset/2` at `user.ex:161-164` — casts one field, no validation. This is the exact pattern to mirror.
- ✓ `Accounts.update_user_smart_unread/2` at `lib/strangepaths/accounts.ex:223-227` — mirror for `update_notification_prefs/2`.
- ✓ `User.role` is `Ecto.Enum, values: [:user, :dragon], default: :user` (`user.ex:11`).
- ✓ `timestamps()` on `users` is `:naive_datetime` (Ecto default).
- ✓ `UserSettingsController.update/2` already dispatches on `%{"action" => "update_smart_unread"}` at `user_settings_controller.ex:83-96`; changesets are pre-assigned in the `assign_email_and_password_changesets/2` plug (around `user_settings_controller.ex:159`).
- ✓ Route `put("/users/settings", UserSettingsController, :update)` at `router.ex:120`, under `[:browser, :require_authenticated_user]`. No new route needed — the existing `:update` action handles all settings forms via the hidden `action` field.
- ✓ Settings template `smart_unread` section at `lib/strangepaths_web/templates/user_settings/edit.html.heex:88-109`, uses `<.form let={f} for={@..._changeset} action={Routes.user_settings_path(@conn, :update)}>` + `hidden_input f, :action, name: "action", value: "..."`.
- ✓ Newest migration `priv/repo/migrations/20260906120001_add_public_to_decks.exs` — pattern `alter table(:x) do add :col, :boolean, default: false, null: false end`.
- ✓ Tests: `test/support/data_case.ex` (`Strangepaths.DataCase`, sandbox, `errors_on/1`), fixtures in `test/support/fixtures/accounts_fixtures.ex` (`user_fixture/1`, `Accounts.register_user/1`). Run tests with the `PGPASSWORD=1zc3edg5` prefix.
- ✓ No JS test infrastructure — the permission `<script>` is verified manually in Phase 6 / by the human.

---

## Acceptance Criteria Coverage

This phase implements and tests:

### activity-notifications.AC5: Preferences persistence and permission UX
- **activity-notifications.AC5.1 Success:** All 8 `notif_*` columns exist on `users`, non-null, default `false`.
- **activity-notifications.AC5.2 Success:** Toggling any of the 8 checkboxes on the settings page persists the new value.
- **activity-notifications.AC5.3 Failure:** `notification_prefs_changeset/2` ignores/rejects any key outside the 8 notification fields.
- **activity-notifications.AC5.4 Success:** Enabling a `_web` checkbox calls `Notification.requestPermission()`.
- **activity-notifications.AC5.5 Failure:** If the user denies the browser permission, the just-enabled `_web` checkbox reverts to unchecked and an inline note is shown.
- **activity-notifications.AC5.6 Edge:** When `Notification.permission === "denied"` at page load, `_web` checkboxes render disabled with the note; `_sound` checkboxes remain enabled.

**Note on AC5.4/AC5.5/AC5.6:** These are browser-JS behaviors with no JS test infra in the repo. Tasks 5–6 build them; verification is the human test plan (`test-requirements.md`, generated at the end of planning and living in this plan directory), not an automated test.

---

## The 8 columns / fields (canonical list — use verbatim everywhere)

```
notif_scene_sound    notif_scene_web
notif_library_sound  notif_library_web
notif_bbs_sound      notif_bbs_web
notif_rumor_sound    notif_rumor_web
```

Sources in fixed order: `scene`, `library`, `bbs`, `rumor`. Cue types: `sound`, `web`.

---

<!-- START_SUBCOMPONENT_A (tasks 1-3) -->

<!-- START_TASK_1 -->
### Task 1: Migration — add 8 notification-preference columns to `users`

**Files:**
- Create: `priv/repo/migrations/20260908120001_add_notification_prefs_to_users.exs`

**Implementation:**

```elixir
defmodule Strangepaths.Repo.Migrations.AddNotificationPrefsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :notif_scene_sound, :boolean, null: false, default: false
      add :notif_scene_web, :boolean, null: false, default: false
      add :notif_library_sound, :boolean, null: false, default: false
      add :notif_library_web, :boolean, null: false, default: false
      add :notif_bbs_sound, :boolean, null: false, default: false
      add :notif_bbs_web, :boolean, null: false, default: false
      add :notif_rumor_sound, :boolean, null: false, default: false
      add :notif_rumor_web, :boolean, null: false, default: false
    end
  end
end
```

**Verification:**

Run: `PGPASSWORD=1zc3edg5 mix ecto.migrate`
Expected: Migration applies without error; output shows `alter table users`.

Run: `PGPASSWORD=1zc3edg5 mix ecto.rollback` then `PGPASSWORD=1zc3edg5 mix ecto.migrate`
Expected: Rolls back and re-applies cleanly (confirms `change/0` is reversible).

**Commit:** `feat(notifications): add notification-preference columns to users`
<!-- END_TASK_1 -->

<!-- START_TASK_2 -->
### Task 2: `User` schema — 8 fields + `notification_prefs_changeset/2`

**Verifies:** activity-notifications.AC5.1, activity-notifications.AC5.3

**Files:**
- Modify: `lib/strangepaths/accounts/user.ex` (add fields near the `smart_unread` field ~line 32; add the changeset function near `smart_unread_changeset/2` ~line 161)

**Implementation:**

1. In the `schema "users" do` block, directly after `field(:smart_unread, :boolean, default: true)`, add:

```elixir
field(:notif_scene_sound, :boolean, default: false)
field(:notif_scene_web, :boolean, default: false)
field(:notif_library_sound, :boolean, default: false)
field(:notif_library_web, :boolean, default: false)
field(:notif_bbs_sound, :boolean, default: false)
field(:notif_bbs_web, :boolean, default: false)
field(:notif_rumor_sound, :boolean, default: false)
field(:notif_rumor_web, :boolean, default: false)
```

2. Directly after `smart_unread_changeset/2`, add:

```elixir
@notification_pref_fields [
  :notif_scene_sound,
  :notif_scene_web,
  :notif_library_sound,
  :notif_library_web,
  :notif_bbs_sound,
  :notif_bbs_web,
  :notif_rumor_sound,
  :notif_rumor_web
]

@doc """
Single-purpose changeset for the 8 activity-notification preference booleans.
Casts exactly those fields — any other key in `attrs` is ignored by `cast/3`.
"""
def notification_prefs_changeset(user, attrs) do
  user
  |> cast(attrs, @notification_pref_fields)
end
```

**Testing:**

- Test file: `test/strangepaths/accounts_test.exs` (exists; append). It already `use`s `Strangepaths.DataCase` and aliases `Strangepaths.Accounts` — match the existing header.
- Tests must verify:
  - **activity-notifications.AC5.3:** `User.notification_prefs_changeset(%User{}, %{"notif_scene_sound" => true, "role" => "dragon", "email" => "x@y.z"})` produces a changeset whose `changes` contain `:notif_scene_sound` and do **not** contain `:role` or `:email`.
  - **activity-notifications.AC5.3:** an unknown key like `"notif_bogus_sound" => true` does not appear in `changes`.
  - **activity-notifications.AC5.1 (schema side):** a freshly `user_fixture()` user has all 8 `notif_*` fields equal to `false` (confirms migration default + schema default agree).

**Verification:**

Run: `PGPASSWORD=1zc3edg5 mix test test/strangepaths/accounts_test.exs`
Expected: the new tests pass; failure count stays at the 4 pre-existing failures (delta gate).

**Commit:** `feat(notifications): notification_prefs_changeset and schema fields`
<!-- END_TASK_2 -->

<!-- START_TASK_3 -->
### Task 3: `Accounts.update_notification_prefs/2`

**Verifies:** activity-notifications.AC5.2

**Files:**
- Modify: `lib/strangepaths/accounts.ex` (add directly after `update_user_smart_unread/2` ~line 227)

**Implementation:**

```elixir
@doc """
Persists a user's activity-notification preferences (the 8 `notif_*` booleans).
"""
def update_notification_prefs(user, attrs \\ %{}) do
  user
  |> User.notification_prefs_changeset(attrs)
  |> Repo.update()
end
```

**Testing:**

- Test file: `test/strangepaths/accounts_test.exs` (append; unit)
- Tests must verify:
  - **activity-notifications.AC5.2:** `update_notification_prefs(user, %{"notif_bbs_web" => true})` returns `{:ok, user}` and a reloaded `Accounts.get_user!(user.id)` has `notif_bbs_web == true` and the other 7 still `false`.
  - Toggling back: `update_notification_prefs(user, %{"notif_bbs_web" => false})` persists `false`.

**Verification:**

Run: `PGPASSWORD=1zc3edg5 mix test test/strangepaths/accounts_test.exs`
Expected: the new tests pass; failure count stays at the 4 pre-existing failures (delta gate).

**Commit:** `feat(notifications): Accounts.update_notification_prefs/2`
<!-- END_TASK_3 -->

<!-- END_SUBCOMPONENT_A -->

<!-- START_SUBCOMPONENT_B (tasks 4-6) -->

<!-- START_TASK_4 -->
### Task 4: Pre-assign the changeset in the settings controller plug

**Verifies:** activity-notifications.AC5.2 (form render path)

**Files:**
- Modify: `lib/strangepaths_web/controllers/user_settings_controller.ex` — the `assign_email_and_password_changesets/2` private plug (~line 150–160), add one `assign` line alongside the existing `:smart_unread_changeset` assign.

**Implementation:**

Add to the pipe in `assign_email_and_password_changesets/2`, right after the `:smart_unread_changeset` line:

```elixir
|> assign(:notification_prefs_changeset, Accounts.User.notification_prefs_changeset(user, %{}))
```

**Verification:**

Run: `PGPASSWORD=1zc3edg5 mix compile`
Expected: compiles; no *new* warnings for `user_settings_controller.ex` (the untouched tree already emits unrelated warnings — ignore those).

(Full render is verified in Task 5's test.)

**Commit:** `feat(notifications): assign notification_prefs_changeset in settings plug`
<!-- END_TASK_4 -->

<!-- START_TASK_5 -->
### Task 5: `update_notification_prefs` controller action + settings-page section

**Verifies:** activity-notifications.AC5.2

**Files:**
- Modify: `lib/strangepaths_web/controllers/user_settings_controller.ex` — add a new `update/2` clause directly after the `"update_smart_unread"` clause (~line 96).
- Modify: `lib/strangepaths_web/templates/user_settings/edit.html.heex` — add an "Activity notifications" `<div class="section p-6">` block directly after the `smart_unread` section (after ~line 109).

**Implementation:**

1. Controller — new clause (mirrors the `update_smart_unread` clause exactly):

```elixir
def update(conn, %{"action" => "update_notification_prefs"} = params) do
  %{"user" => user_params} = params
  user = conn.assigns.current_user

  case Accounts.update_notification_prefs(user, user_params) do
    {:ok, _} ->
      conn
      |> put_flash(:info, "Activity notification preferences updated.")
      |> redirect(to: Routes.user_settings_path(conn, :edit))

    {:error, changeset} ->
      render(conn, "edit.html", notification_prefs_changeset: changeset)
  end
end
```

2. Template section. Checkboxes are rendered so an unchecked box still POSTs `false` (Phoenix `checkbox/3` emits a hidden `_false` companion input by default, so this is automatic). Grid: one row per source, columns Sound / Desktop notification.

```heex
<!-- Activity notifications -->
<div class="section p-6">
  <h2 class="mb-2">Activity notifications</h2>
  <p class="text-sm text-gray-400 mb-4">
    Optional louder cues — a sound, or an OS desktop notification — layered on top of the
    quiet unread badges the site already shows. Everything here is off unless you turn it on,
    and cues only ever fire while you have a tab open. You are never alerted about your own
    activity or about the page you are already looking at.
  </p>

  <.form let={f} for={@notification_prefs_changeset} action={Routes.user_settings_path(@conn, :update)} id="update_notification_prefs" class="formstyle">
    <%= hidden_input f, :action, name: "action", value: "update_notification_prefs" %>

    <table class="text-sm" id="notif-prefs-grid">
      <thead>
        <tr>
          <th class="text-left pr-6 pb-2">Source</th>
          <th class="pr-6 pb-2">Sound</th>
          <th class="pb-2">Desktop notification</th>
        </tr>
      </thead>
      <tbody>
        <%= for {field_key, label} <- [
              {"scene", "Scene posts"},
              {"library", "Library edits & marginalia"},
              {"bbs", "Linkpearl threads & replies"},
              {"rumor", "Rumor map nodes"}
            ] do %>
          <tr>
            <td class="text-left pr-6 py-1"><%= label %></td>
            <td class="text-center pr-6 py-1">
              <%= checkbox f, String.to_atom("notif_#{field_key}_sound"), class: "notif-sound-box" %>
            </td>
            <td class="text-center py-1">
              <%= checkbox f, String.to_atom("notif_#{field_key}_web"), class: "notif-web-box" %>
            </td>
          </tr>
        <% end %>
      </tbody>
    </table>

    <p id="notif-perm-note" class="text-xs text-amber-400 mt-2" hidden>
      Desktop notifications are blocked in your browser settings for this site. Re-enable them
      in your browser to use the desktop-notification cues. The sound cues still work.
    </p>

    <div class="pt-3">
      <%= submit "Save", class: "submit" %>
    </div>
  </.form>
</div>
```

**Testing:**

- Test file: `test/strangepaths_web/controllers/user_settings_controller_test.exs` (append; integration). Use the ConnCase login helper (`register_and_log_in_user/1` or the project's equivalent — confirm the name in `test/support/conn_case.ex` during the RED step).
- Tests must verify:
  - **activity-notifications.AC5.2:** `GET /users/settings` renders and the response body contains `"Activity notifications"` and `name="user[notif_scene_sound]"` (and the other 7 field names).
  - **activity-notifications.AC5.2:** `PUT /users/settings` with `%{"action" => "update_notification_prefs", "user" => %{"notif_scene_sound" => "true", "notif_library_web" => "true"}}` redirects to `/users/settings`, sets the info flash, and a reloaded user has `notif_scene_sound == true`, `notif_library_web == true`, others `false`.
  - **activity-notifications.AC5.3 (end-to-end):** `PUT` with `"user" => %{"notif_scene_sound" => "true", "role" => "dragon"}` persists `notif_scene_sound` but leaves `role` unchanged.

**Verification:**

Run: `PGPASSWORD=1zc3edg5 mix test test/strangepaths_web/controllers/user_settings_controller_test.exs`
Expected: the new tests pass; failure count stays at the 3 pre-existing failures (delta gate).

**Commit:** `feat(notifications): settings action and Activity notifications section`
<!-- END_TASK_5 -->

<!-- START_TASK_6 -->
### Task 6: Permission-request inline script on the settings form

**Verifies:** activity-notifications.AC5.4, activity-notifications.AC5.5, activity-notifications.AC5.6 (manual verification — no JS test infra)

**Files:**
- Modify: `lib/strangepaths_web/templates/user_settings/edit.html.heex` — add a `<script>` block at the very end of the file (after the last closing `</div>` of the page content).

**Implementation:**

Plain inline script (this template is server-rendered, not a LiveView, so no `phx-hook`):

```heex
<script>
  (function () {
    var form = document.getElementById("update_notification_prefs");
    if (!form) return;

    var note = document.getElementById("notif-perm-note");
    var webBoxes = form.querySelectorAll(".notif-web-box");

    function notifySupported() {
      return typeof window.Notification !== "undefined";
    }

    // AC5.6: permission already denied at page load -> disable web boxes, show note.
    if (!notifySupported() || Notification.permission === "denied") {
      webBoxes.forEach(function (b) {
        b.checked = false;
        b.disabled = true;
      });
      if (note) note.hidden = false;
    }

    // AC5.4 / AC5.5: first time a web box is enabled, request permission; revert on denial.
    webBoxes.forEach(function (box) {
      box.addEventListener("change", function () {
        if (!box.checked) return;
        if (!notifySupported()) {
          box.checked = false;
          if (note) note.hidden = false;
          return;
        }
        if (Notification.permission === "granted") return;

        Notification.requestPermission().then(function (result) {
          if (result !== "granted") {
            box.checked = false;
            if (note) note.hidden = false;
            if (result === "denied") {
              webBoxes.forEach(function (b) { b.disabled = true; });
            }
          }
        });
      });
    });
  })();
</script>
```

**Verification (manual — record in the human test plan):**
- Load `/users/settings` with notification permission at "default": check a Desktop-notification box → browser prompts (`Notification.requestPermission()`), grant → box stays checked.
- Repeat, deny → box reverts to unchecked, amber note appears, other web boxes become disabled.
- Set site notification permission to "Block" in browser, reload → all Desktop-notification boxes render disabled + note visible; Sound boxes remain enabled and toggle/save normally.

**Verification (automated — regression guard only):**

Run: `PGPASSWORD=1zc3edg5 mix test test/strangepaths_web/controllers/user_settings_controller_test.exs`
Expected: new tests still pass, pre-existing failure count unchanged (delta gate). The `<script>` must not break server render — add an assertion that the `GET /users/settings` body contains `id="notif-perm-note"`.

**Commit:** `feat(notifications): browser permission handling on settings form`
<!-- END_TASK_6 -->

<!-- END_SUBCOMPONENT_B -->

---

## Phase 1 Done When

- `PGPASSWORD=1zc3edg5 mix ecto.migrate` applies the 8 columns (`null: false, default: false`).
- `PGPASSWORD=1zc3edg5 mix test test/strangepaths/accounts_test.exs test/strangepaths_web/controllers/user_settings_controller_test.exs`: all newly added tests pass; the 4 + 3 pre-existing failures are unchanged (no new failures).
- Toggling any of the 8 checkboxes on `/users/settings` persists to `users`.
- `notification_prefs_changeset/2` drops any key outside the 8 fields.
- Manual: denying the browser permission reverts the just-checked `_web` box; a pre-denied permission renders `_web` boxes disabled.
- No consumer of these columns exists yet — the rest of the app is byte-for-byte unchanged.
