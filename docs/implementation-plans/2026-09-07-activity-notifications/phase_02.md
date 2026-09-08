# Activity Notifications Implementation Plan — Phase 2

**Goal:** `Strangepaths.Notifications.publish/3` resolves recipients (honoring scene visibility and folio privacy), excludes the actor, gates on each recipient's saved preference columns, and broadcasts a per-user `activity` payload carrying that recipient's resolved cue flags. No caller wires into it yet — verified against synthetic events.

**Architecture:** One new context module `lib/strangepaths/notifications.ex`. `publish/3` takes `(source, event, meta)`. It resolves a candidate recipient list per source, drops `meta.actor_id`, then keeps only users with at least one enabled flag for `source` and, for each, computes `%{sound: bool, web: bool}` from that user's own struct fields. For each surviving recipient it calls `StrangepathsWeb.Endpoint.broadcast("user:#{id}:notifications", "activity", payload)`.

**Tech Stack:** Elixir/Phoenix, Ecto queries, Phoenix.PubSub via `StrangepathsWeb.Endpoint`.

**Scope:** Phase 2 of 6 from `docs/design-plans/2026-09-07-activity-notifications.md`.

**Codebase verified:** 2026-09-08.

**Test-suite baseline:** full suite `PGPASSWORD=1zc3edg5 mix test` = 345 tests / 212 pre-existing failures (out of scope), and `mix compile --warnings-as-errors` fails on the untouched tree — use plain `mix compile` and require no *new* warnings in touched files. All Phase 2 tests go in a **new** file `test/strangepaths/notifications_test.exs`, so its "Expected: green" gates are literal — the new file must be 100% green on its own.

**Verification findings incorporated:**
- ✓ Visibility check: the design's `Strangepaths.Scenes.can_view_scene?/2` **does exist** (`lib/strangepaths/scenes.ex:602`) as a one-line delegate to `Strangepaths.Scenes.Scene.can_view?/2` (`lib/strangepaths/scenes/scene.ex:103-113`, arity 2, pattern-matches `%Scene{}` + `%User{}` / `nil`). This plan calls the public `Scenes.can_view_scene?/2` (matches the design). Semantics: dragons see all; `locked_to_users == []` → any `%User{}`; otherwise `user_id in locked_to_users`; `nil` user → only open scenes.
- ✓ Scene locking is the integer-array column `locked_to_users` (not a join table); `is_elsewhere` boolean marks the special OOC scene (also visible to everyone).
- ✓ Folio privacy field is `is_private` (`lib/strangepaths/library/folio.ex:12`); author is `belongs_to(:user, ...)` → `folio.user_id`.
- ✓ `User.role` enum `:user | :dragon`.
- ✓ Candidate loading uses `Repo.all(from(u in User))` directly in this context (lean — only the plain `notif_*` / `role` / `id` columns are needed). `Strangepaths.Accounts.list_users/0` exists (`accounts.ex:75`) but is not used here.
- ✓ Tests subscribe with `StrangepathsWeb.Endpoint.subscribe(topic)` and `assert_receive %Phoenix.Socket.Broadcast{...}` (pattern already used in `test/strangepaths_web/controllers/user_auth_test.exs`). `Strangepaths.DataCase` provides the sandbox; PubSub broadcasts are delivered to the test process because `Endpoint.broadcast` is not sandbox-bound.
- ✓ Fixtures: `user_fixture/1` (`test/support/fixtures/accounts_fixtures.ex`). Scene/folio fixtures: check `test/support/fixtures/` for `scenes_fixtures.ex` / `library_fixtures.ex`; if absent, build structs directly via `Strangepaths.Repo.insert!` in the test (see Task 3).

**Design simplification (documented):** The design describes "one query" over the recipient set for preference gating. This plan loads candidate `User` structs (already needed for `Scene.can_view?/2`) and filters/derives `cues` in Elixir. At this app's user scale that is equivalent and removes dynamic column-name query construction. AC6.3 ("flag values at broadcast time") is still satisfied — the structs are read fresh inside `publish/3`.

---

## Acceptance Criteria Coverage

### activity-notifications.AC2: Recipient resolution respects visibility
- **activity-notifications.AC2.1 Success:** For an open scene, a `:scene` event is broadcast to every user (with a scene flag enabled) except the actor.
- **activity-notifications.AC2.2 Success:** For a locked/backchannel scene, a `:scene` event is broadcast only to dragons and whitelisted users (minus the actor).
- **activity-notifications.AC2.3 Success:** For a non-private folio, a `:library` event reaches all flagged users except the actor.
- **activity-notifications.AC2.4 Failure:** For a private folio, a `:library` event reaches only the folio author and dragons (never other users), minus the actor.
- **activity-notifications.AC2.5 Success:** `:bbs` and `:rumor` events reach all flagged users except the actor.
- **activity-notifications.AC2.6 Edge:** When the actor is the only eligible recipient, no broadcast is sent.

### activity-notifications.AC6: Server-side preference gating
- **activity-notifications.AC6.1 Success:** A recipient with `notif_<source>_sound` true (and `_web` false) receives a broadcast whose `cues` is `%{sound: true, web: false}`.
- **activity-notifications.AC6.2 Success:** A recipient with both `<source>` flags false receives no broadcast for that source.
- **activity-notifications.AC6.3 Success:** Gating uses the flag values at broadcast time (a stale client cannot receive a cue type it is not entitled to).
- **activity-notifications.AC6.4 Edge:** A recipient with a flag enabled for one source but not another receives broadcasts only for the enabled source.

### activity-notifications.AC1 (partial — payload shape only)
- **activity-notifications.AC1.9 Success:** Every published payload includes `title`, `excerpt`, `url`, `context_key`, and a `cues` map.

---

## The topic and payload contract (frozen here; Phases 3–5 depend on it)

- **Topic:** `"user:#{user_id}:notifications"` — one per user.
- **Event name:** `"activity"`.
- **Payload map:**

```elixir
%{
  source: source,            # :scene | :library | :bbs | :rumor  (atom)
  event: event,              # :new_post | :new_thread | :body_edit | :marginalia | :node_create | :node_update
  title: String.t(),         # scene name / folio title / thread title / node title
  excerpt: String.t(),       # short plain-text preview (<= ~140 chars); "" allowed except library body_edit
  url: String.t(),           # where the cue links
  context_key: String.t(),   # "scene:123" | "folio:45" | "bbs_thread:9" | "rumor"
  actor_name: String.t(),    # display name of who triggered it (for toast/notification body)
  cues: %{sound: boolean, web: boolean}   # THIS recipient's resolved flags for `source`
}
```

- **`meta` argument to `publish/3`** (map, atom-keyed only; callers in Phase 4 pass atom keys):

```
:actor_id     integer   (required; excluded from recipients)
:actor_name   String.t  (required)
:title        String.t  (required)
:excerpt      String.t  (optional, default "")
:url          String.t  (required)
:context_key  String.t  (required)
:scene        %Scenes.Scene{}   (required for source == :scene)
:folio        %Library.Folio{}  (required for source == :library)
```

---

<!-- START_SUBCOMPONENT_A (tasks 1-2) -->

<!-- START_TASK_1 -->
### Task 1: `Strangepaths.Notifications` — module skeleton, `@type`s, recipient resolution

**Verifies:** activity-notifications.AC2.1, activity-notifications.AC2.2, activity-notifications.AC2.3, activity-notifications.AC2.4, activity-notifications.AC2.5

**Files:**
- Create: `lib/strangepaths/notifications.ex`

**Implementation:**

```elixir
defmodule Strangepaths.Notifications do
  @moduledoc """
  Opt-in "louder" activity cues (sound / OS notification / toast) layered on top of
  the site's quiet unread signals. `publish/3` is the single entry point: the four
  write paths (scenes, library, bbs, rumor) call it after a successful save.

  It resolves who may see the event, drops the actor, gates each remaining recipient
  on their saved `notif_*` preference columns, and sends a per-user `"activity"`
  broadcast on `"user:#{id}:notifications"` carrying that recipient's resolved cue flags.
  Users with both flags off for the source receive nothing.
  """

  import Ecto.Query, warn: false

  require Logger

  alias Strangepaths.Repo
  alias Strangepaths.Accounts.User
  alias Strangepaths.Scenes
  alias Strangepaths.Scenes.Scene
  alias StrangepathsWeb.Endpoint

  @type source :: :scene | :library | :bbs | :rumor
  @type event ::
          :new_post | :new_thread | :body_edit | :marginalia | :node_create | :node_update

  # ---- recipient resolution -------------------------------------------------

  # Returns the list of candidate %User{} structs for a source, BEFORE actor
  # exclusion and preference gating. Each User struct carries its notif_* fields.
  defp candidates(:bbs, _meta), do: all_users()
  defp candidates(:rumor, _meta), do: all_users()

  defp candidates(:scene, %{scene: %Scene{} = scene}) do
    Enum.filter(all_users(), fn user -> Scenes.can_view_scene?(scene, user) end)
  end

  defp candidates(:library, %{folio: folio}) do
    if folio.is_private do
      author_and_dragons(folio.user_id)
    else
      all_users()
    end
  end

  defp all_users do
    Repo.all(from(u in User))
  end

  defp author_and_dragons(author_id) do
    Repo.all(
      from(u in User,
        where: u.id == ^author_id or u.role == :dragon
      )
    )
  end

  # ---- preference gating --------------------------------------------------

  @doc false
  # Given a source atom, returns {sound_field, web_field} atoms.
  def pref_fields(:scene), do: {:notif_scene_sound, :notif_scene_web}
  def pref_fields(:library), do: {:notif_library_sound, :notif_library_web}
  def pref_fields(:bbs), do: {:notif_bbs_sound, :notif_bbs_web}
  def pref_fields(:rumor), do: {:notif_rumor_sound, :notif_rumor_web}

  # %User{} -> %{sound: bool, web: bool} for the given source.
  defp cues_for(user, source) do
    {sound_field, web_field} = pref_fields(source)
    %{sound: Map.fetch!(user, sound_field), web: Map.fetch!(user, web_field)}
  end

  defp entitled?(%{sound: false, web: false}), do: false
  defp entitled?(_), do: true
end
```

**Testing:**

- Test file: `test/strangepaths/notifications_test.exs` (create; `use Strangepaths.DataCase, async: true`).
- These recipient-resolution ACs are verified end-to-end through `publish/3` in Task 3. Task 1's own check is a compile + a focused unit test on `pref_fields/1` mapping (all 4 sources → correct atom pairs).

**Verification:**

Run: `PGPASSWORD=1zc3edg5 mix compile` (plain — `--warnings-as-errors` fails on the untouched tree)
Expected: compiles; no *new* warnings for `lib/strangepaths/notifications.ex` (module has no public `publish/3` yet — that's Task 2; `pref_fields/1` is public for testing).

Run: `PGPASSWORD=1zc3edg5 mix test test/strangepaths/notifications_test.exs`
Expected: the `pref_fields/1` test passes.

**Commit:** `feat(notifications): Notifications context skeleton + recipient resolution`
<!-- END_TASK_1 -->

<!-- START_TASK_2 -->
### Task 2: `publish/3` — actor exclusion, gating, per-recipient broadcast

**Verifies:** activity-notifications.AC1.9, activity-notifications.AC6.1, activity-notifications.AC6.2, activity-notifications.AC6.3, activity-notifications.AC6.4, activity-notifications.AC2.6

**Files:**
- Modify: `lib/strangepaths/notifications.ex` (add the public `publish/3` + payload builder)

**Implementation:**

```elixir
  @doc """
  Resolve recipients for `{source, event}`, exclude the actor, gate on each
  recipient's saved preferences, and broadcast one `"activity"` payload per
  surviving recipient. Always returns `:ok` (fire-and-forget; never raises to
  the caller — a broadcast failure must not roll back the write that triggered it).
  """
  @spec publish(source, event, map) :: :ok
  def publish(source, event, meta) do
    actor_id = Map.fetch!(meta, :actor_id)

    recipients =
      source
      |> candidates(meta)
      |> Enum.reject(fn u -> u.id == actor_id end)
      |> Enum.map(fn u -> {u, cues_for(u, source)} end)
      |> Enum.filter(fn {_u, cues} -> entitled?(cues) end)

    for {user, cues} <- recipients do
      Endpoint.broadcast(
        "user:#{user.id}:notifications",
        "activity",
        payload(source, event, meta, cues)
      )
    end

    :ok
  rescue
    # Defensive: publishing is best-effort and must never break the caller's write path.
    e ->
      Logger.error("Notifications.publish/3 failed: #{inspect(e)}")
      :ok
  end

  defp payload(source, event, meta, cues) do
    %{
      source: source,
      event: event,
      title: Map.fetch!(meta, :title),
      excerpt: Map.get(meta, :excerpt, ""),
      url: Map.fetch!(meta, :url),
      context_key: Map.fetch!(meta, :context_key),
      actor_name: Map.fetch!(meta, :actor_name),
      cues: cues
    }
  end
```

**Testing:**

- Test file: `test/strangepaths/notifications_test.exs` (append; unit/integration).
- Each test subscribes the test process to specific user topics before calling `publish/3`, then asserts (or refutes) `%Phoenix.Socket.Broadcast{topic: "user:<id>:notifications", event: "activity", payload: p}`.
- Tests must verify:
  - **activity-notifications.AC1.9:** for a `:bbs` `publish`, the received `payload` has non-nil `:title`, `:excerpt` (string, `""` ok), `:url`, `:context_key`, and `:cues` is a map with `:sound` and `:web` boolean keys.
  - **activity-notifications.AC6.1:** recipient with `notif_bbs_sound: true, notif_bbs_web: false` receives `cues == %{sound: true, web: false}`.
  - **activity-notifications.AC6.2:** recipient with both `:bbs` flags false → `refute_receive` on their topic.
  - **activity-notifications.AC6.4:** recipient with `notif_bbs_sound: true` but both `:rumor` flags false → receives the `:bbs` publish, `refute_receive` for a `:rumor` publish.
  - **activity-notifications.AC6.3:** set a recipient's flag, `publish`, assert cue; update the flag to false via `Accounts.update_notification_prefs/2`, `publish` again, `refute_receive` — proves `publish/3` reads current values.
  - **activity-notifications.AC2.6:** actor is the only user with a flag enabled → `publish` sends zero broadcasts (`refute_receive` on the actor's own topic; the test also subscribes the actor topic).

**Verification:**

Run: `PGPASSWORD=1zc3edg5 mix test test/strangepaths/notifications_test.exs`
Expected: all tests pass.

**Commit:** `feat(notifications): publish/3 with actor exclusion and preference gating`
<!-- END_TASK_2 -->

<!-- END_SUBCOMPONENT_A -->

<!-- START_TASK_3 -->
### Task 3: Recipient-resolution integration tests (scene visibility + folio privacy)

**Verifies:** activity-notifications.AC2.1, activity-notifications.AC2.2, activity-notifications.AC2.3, activity-notifications.AC2.4, activity-notifications.AC2.5

**Files:**
- Modify: `test/strangepaths/notifications_test.exs` (append; integration)
- (Read-only reference: `test/support/fixtures/accounts_fixtures.ex`; check for `scenes_fixtures.ex` / `library_fixtures.ex`.)

**Implementation notes for the test author:**
- Build a small cast: `actor`, `viewer_on` (flag enabled), `viewer_off` (no flags), `dragon` (role `:dragon`, flag enabled), `outsider` (flag enabled, not whitelisted).
- Set the relevant `notif_*` flags with `Accounts.update_notification_prefs/2` (or insert the users with the fields set).
- **Scene fixtures:** if no `scenes_fixtures.ex`, insert directly:
  `Repo.insert!(%Strangepaths.Scenes.Scene{name: "S", slug: "s", locked_to_users: [], status: :active})` for open; `locked_to_users: [viewer_on.id]` for locked.
- **Folio fixtures:** if no `library_fixtures.ex`, insert directly:
  `Repo.insert!(%Strangepaths.Library.Folio{title: "F", slug: "f", body: "b", is_private: false, user_id: actor.id})`; set `is_private: true` for the private case.
- Each test subscribes every cast member's `"user:#{id}:notifications"` topic, then calls `publish/3` with the appropriate `:scene` / `:folio` meta, then asserts/refutes per member.

**Tests must verify:**
- **activity-notifications.AC2.1:** open scene, `:scene` publish → `viewer_on` and `dragon` receive; `actor` does not; `viewer_off` does not.
- **activity-notifications.AC2.2:** locked scene (`locked_to_users: [viewer_on.id]`), `:scene` publish → only `viewer_on` and `dragon` receive; `outsider` (flag on, not whitelisted) does **not**; `actor` does not.
- **activity-notifications.AC2.3:** non-private folio, `:library` publish → all flagged non-actor users receive (incl. `outsider`).
- **activity-notifications.AC2.4:** private folio (`is_private: true`, `user_id: someAuthor.id`), `:library` publish by a third party → only the author and `dragon` receive; a flagged non-author non-dragon does **not**.
- **activity-notifications.AC2.5:** `:bbs` and `:rumor` publish → every flagged non-actor user receives, regardless of scene/folio.

**Verification:**

Run: `PGPASSWORD=1zc3edg5 mix test test/strangepaths/notifications_test.exs`
Expected: all tests pass.

**Commit:** `test(notifications): scene-visibility and folio-privacy recipient resolution`
<!-- END_TASK_3 -->

---

## Phase 2 Done When

- `PGPASSWORD=1zc3edg5 mix test test/strangepaths/notifications_test.exs` is green.
- `publish/3` exists, takes `(source, event, meta)`, returns `:ok`, never raises to the caller.
- Open-scene event reaches all non-actor flagged users; locked-scene event reaches only dragons + whitelisted; private-folio event reaches only author + dragons; actor never receives; all-`false` users never receive.
- Each recipient's `cues` map equals that user's two `notif_<source>_*` columns, read at publish time.
- No caller wired in yet.
