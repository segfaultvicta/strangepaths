# Liminal Library Implementation Plan

**Goal:** Establish the complete data layer — five migrations, five schemas, typefaces config module, Library context module with CRUD, test fixtures, and context tests.

**Architecture:** Phoenix context pattern. `Strangepaths.Library` at `lib/strangepaths/library.ex`, schemas in `lib/strangepaths/library/`. Typefaces are a code-side module attribute (no DB table). `Ecto.Enum` for entry `kind` field. Self-referential FK on marginalia for threading.

**Tech Stack:** Elixir ~1.15, Ecto ~3.6, PostgreSQL, `:slugify ~1.3` (already in `mix.exs`)

**Scope:** Phase 1 of 7 from design plan at `docs/design-plans/2026-04-27-liminal-library.md`

**Codebase verified:** 2026-04-27

---

## Acceptance Criteria Coverage

This phase implements and tests:

### liminal-library.AC1: Dragon manages typeface assignment (folio access)
- **liminal-library.AC1.2 Success:** Dragon can assign one or more typefaces to any user, including themselves
- **liminal-library.AC1.3 Success:** Dragon can revoke a typeface assignment
- **liminal-library.AC1.4 Success:** User with ≥1 assigned typeface can create folios and add marginalia
- **liminal-library.AC1.5 Failure:** User with no assigned typefaces cannot access folio creation

### liminal-library.AC2: Folio creation
- **liminal-library.AC2.1 Success:** Folio editor can create a folio with a unique title and optional subtitle
- **liminal-library.AC2.2 Success:** Slug is auto-generated from title (lowercased, hyphenated)
- **liminal-library.AC2.3 Failure:** Duplicate title returns a validation error
- **liminal-library.AC2.4 Success:** Folio with body only (no entries) is valid and viewable
- **liminal-library.AC2.5 Success:** Folio with entries only (no body) is valid and viewable

### liminal-library.AC8: Tags and deletion
- **liminal-library.AC8.1 Success:** Any folio editor can add and remove tags on any folio; tags are stored lowercased and trimmed; duplicate adds are no-ops

---

<!-- START_SUBCOMPONENT_A (tasks 1-3) -->

<!-- START_TASK_1 -->
### Task 1: Five migration files

Create these files in `priv/repo/migrations/` in order. Run them one at a time with `mix ecto.migrate` after creating all five, and verify the full migrate succeeds.

**`priv/repo/migrations/20260427120001_create_library_user_typefaces.exs`**

```elixir
defmodule Strangepaths.Repo.Migrations.CreateLibraryUserTypefaces do
  use Ecto.Migration

  def change do
    create table(:library_user_typefaces) do
      add(:user_id, references(:users, on_delete: :delete_all), null: false)
      add(:typeface_id, :string, null: false)

      timestamps()
    end

    create(index(:library_user_typefaces, [:user_id]))
    create(unique_index(:library_user_typefaces, [:user_id, :typeface_id]))
  end
end
```

**`priv/repo/migrations/20260427120002_create_library_folios.exs`**

```elixir
defmodule Strangepaths.Repo.Migrations.CreateLibraryFolios do
  use Ecto.Migration

  def change do
    create table(:library_folios) do
      add(:user_id, references(:users), null: false)
      add(:title, :string, null: false)
      add(:slug, :string, null: false)
      add(:subtitle, :string)
      add(:body, :text)
      add(:body_locked_by_id, references(:users))
      add(:body_locked_at, :utc_datetime)

      timestamps()
    end

    create(unique_index(:library_folios, [:title]))
    create(unique_index(:library_folios, [:slug]))
    create(index(:library_folios, [:user_id]))
    create(index(:library_folios, [:inserted_at]))
  end
end
```

**`priv/repo/migrations/20260427120003_create_library_folio_tags.exs`**

```elixir
defmodule Strangepaths.Repo.Migrations.CreateLibraryFolioTags do
  use Ecto.Migration

  def change do
    create table(:library_folio_tags) do
      add(:folio_id, references(:library_folios, on_delete: :delete_all), null: false)
      add(:tag, :string, null: false)

      timestamps()
    end

    create(unique_index(:library_folio_tags, [:folio_id, :tag]))
    create(index(:library_folio_tags, [:tag]))
  end
end
```

**`priv/repo/migrations/20260427120004_create_library_entries.exs`**

`kind` is stored as a plain string (Ecto.Enum maps to string values automatically — no PostgreSQL enum type needed).

```elixir
defmodule Strangepaths.Repo.Migrations.CreateLibraryEntries do
  use Ecto.Migration

  def change do
    create table(:library_entries) do
      add(:folio_id, references(:library_folios, on_delete: :delete_all), null: false)
      add(:user_id, references(:users), null: false)
      add(:position, :integer, null: false, default: 0)
      add(:kind, :string, null: false)
      add(:scene_post_id, references(:scene_posts, on_delete: :nilify_all))
      add(:content, :text)
      add(:name, :string)
      add(:font, :string)
      add(:color, :string)
      add(:group_id, :string)

      timestamps(updated_at: false)
    end

    create(index(:library_entries, [:folio_id, :position]))
    create(index(:library_entries, [:group_id]))
  end
end
```

**Note on `scene_post_id`:** The foreign key reference includes `on_delete: :nilify_all` to gracefully handle deletion of scene posts. When a scene post is deleted, its entry's reference is nilified rather than raising a constraint violation. Templates that display entries already have nil-guards on `entry.scene_post`, making this choice safe and user-friendly.

Note: `timestamps(updated_at: false)` — entries are immutable records; only `inserted_at` is needed.

**`priv/repo/migrations/20260427120005_create_library_marginalia.exs`**

Self-referential FK: `parent_id` references the same table. PostgreSQL supports this in a single `CREATE TABLE` statement.

```elixir
defmodule Strangepaths.Repo.Migrations.CreateLibraryMarginalia do
  use Ecto.Migration

  def change do
    create table(:library_marginalia) do
      add(:entry_id, references(:library_entries, on_delete: :delete_all), null: false)
      add(:parent_id, references(:library_marginalia, on_delete: :delete_all))
      add(:user_id, references(:users), null: false)
      add(:content, :text, null: false)
      add(:name, :string, null: false)
      add(:font, :string, null: false)
      add(:color, :string, null: false)

      timestamps(updated_at: false)
    end

    create(index(:library_marginalia, [:entry_id]))
    create(index(:library_marginalia, [:parent_id]))
  end
end
```

**Verification:**

```bash
mix ecto.migrate
```

Should complete with no errors and show all five `library_*` tables created.

If needed for a clean slate: `mix ecto.rollback` five times, then re-run `mix ecto.migrate`.
<!-- END_TASK_1 -->

<!-- START_TASK_2 -->
### Task 2: Typefaces config module

Create `lib/strangepaths/library/typefaces.ex`. This is the code-side master list — adding a typeface requires a code push, not a DB change.

```elixir
defmodule Strangepaths.Library.Typefaces do
  @typefaces [
    %{id: "jorule", name: "Jorule", font: "'IM Fell English', serif", color: "#8b5cf6"},
    %{id: "seraph", name: "Seraph", font: "'Crimson Text', serif", color: "#dc2626"},
    %{id: "inkwell", name: "Inkwell", font: "'Patrick Hand', cursive", color: "#0369a1"},
    %{id: "lacuna", name: "Lacuna", font: "'Courier Prime', monospace", color: "#065f46"}
  ]

  def all, do: @typefaces

  def find(id), do: Enum.find(@typefaces, &(&1.id == id))

  def valid_id?(id), do: Enum.any?(@typefaces, &(&1.id == id))
end
```

The `@typefaces` list is the source of truth. These are example entries — the actual typefaces for the project will be decided separately. The IDs are lowercase strings matching the `[name]text[/name]` tag syntax.

**Verification:**

```bash
mix compile --no-deps-check
```

No warnings or errors for this module.
<!-- END_TASK_2 -->

<!-- START_TASK_3 -->
### Task 3: Schema modules (five files)

Create all five schema files in `lib/strangepaths/library/`.

---

**`lib/strangepaths/library/user_typeface.ex`**

```elixir
defmodule Strangepaths.Library.UserTypeface do
  use Ecto.Schema
  import Ecto.Changeset

  schema "library_user_typefaces" do
    field(:typeface_id, :string)
    belongs_to(:user, Strangepaths.Accounts.User)

    timestamps()
  end

  def changeset(user_typeface, attrs) do
    user_typeface
    |> cast(attrs, [:user_id, :typeface_id])
    |> validate_required([:user_id, :typeface_id])
    |> validate_typeface_id()
    |> unique_constraint([:user_id, :typeface_id])
  end

  defp validate_typeface_id(changeset) do
    validate_change(changeset, :typeface_id, fn :typeface_id, id ->
      if Strangepaths.Library.Typefaces.valid_id?(id) do
        []
      else
        [typeface_id: "is not a valid typeface"]
      end
    end)
  end
end
```

---

**`lib/strangepaths/library/folio.ex`**

```elixir
defmodule Strangepaths.Library.Folio do
  use Ecto.Schema
  import Ecto.Changeset

  schema "library_folios" do
    field(:title, :string)
    field(:slug, :string)
    field(:subtitle, :string)
    field(:body, :string)
    field(:body_locked_at, :utc_datetime)

    belongs_to(:user, Strangepaths.Accounts.User)
    belongs_to(:body_locked_by, Strangepaths.Accounts.User, foreign_key: :body_locked_by_id)
    has_many(:entries, Strangepaths.Library.Entry)
    has_many(:tags, Strangepaths.Library.FolioTag)

    timestamps()
  end

  def create_changeset(folio, attrs) do
    folio
    |> cast(attrs, [:user_id, :title, :subtitle, :body])
    |> validate_required([:user_id, :title])
    |> validate_length(:title, min: 1, max: 200)
    |> validate_length(:subtitle, max: 400)
    |> put_slug()
    |> unique_constraint(:title)
    |> unique_constraint(:slug)
  end

  def title_changeset(folio, attrs) do
    folio
    |> cast(attrs, [:title, :subtitle])
    |> validate_required([:title])
    |> validate_length(:title, min: 1, max: 200)
    |> validate_length(:subtitle, max: 400)
    |> put_slug()
    |> unique_constraint(:title)
    |> unique_constraint(:slug)
  end

  defp put_slug(changeset) do
    case get_change(changeset, :title) do
      nil -> changeset
      title -> put_change(changeset, :slug, Slug.slugify(title))
    end
  end
end
```

---

**`lib/strangepaths/library/folio_tag.ex`**

```elixir
defmodule Strangepaths.Library.FolioTag do
  use Ecto.Schema
  import Ecto.Changeset

  schema "library_folio_tags" do
    field(:tag, :string)
    belongs_to(:folio, Strangepaths.Library.Folio)

    timestamps()
  end

  def changeset(folio_tag, attrs) do
    folio_tag
    |> cast(attrs, [:folio_id, :tag])
    |> validate_required([:folio_id, :tag])
    |> validate_length(:tag, min: 1, max: 100)
    |> unique_constraint([:folio_id, :tag])
  end
end
```

---

**`lib/strangepaths/library/entry.ex`**

```elixir
defmodule Strangepaths.Library.Entry do
  use Ecto.Schema
  import Ecto.Changeset

  schema "library_entries" do
    field(:position, :integer, default: 0)
    field(:kind, Ecto.Enum, values: [:post_ref, :note])
    field(:content, :string)
    field(:name, :string)
    field(:font, :string)
    field(:color, :string)
    field(:group_id, :string)

    belongs_to(:folio, Strangepaths.Library.Folio)
    belongs_to(:user, Strangepaths.Accounts.User)
    belongs_to(:scene_post, Strangepaths.Scenes.Post, foreign_key: :scene_post_id)
    has_many(:marginalia, Strangepaths.Library.Marginalia)

    timestamps(updated_at: false)
  end

  def post_ref_changeset(entry, attrs) do
    entry
    |> cast(attrs, [:folio_id, :user_id, :position, :scene_post_id, :group_id])
    |> validate_required([:folio_id, :user_id, :scene_post_id])
    |> put_change(:kind, :post_ref)
  end

  def note_changeset(entry, attrs) do
    entry
    |> cast(attrs, [:folio_id, :user_id, :position, :content, :name, :font, :color, :group_id])
    |> validate_required([:folio_id, :user_id, :content, :name, :font, :color])
    |> put_change(:kind, :note)
    |> validate_length(:content, min: 1, max: 10_000)
  end
end
```

---

**`lib/strangepaths/library/marginalia.ex`**

```elixir
defmodule Strangepaths.Library.Marginalia do
  use Ecto.Schema
  import Ecto.Changeset

  schema "library_marginalia" do
    field(:content, :string)
    field(:name, :string)
    field(:font, :string)
    field(:color, :string)
    field(:parent_id, :id)

    belongs_to(:entry, Strangepaths.Library.Entry)
    belongs_to(:user, Strangepaths.Accounts.User)

    timestamps(updated_at: false)
  end

  def create_changeset(marginalia, attrs) do
    marginalia
    |> cast(attrs, [:entry_id, :user_id, :parent_id, :content, :name, :font, :color])
    |> validate_required([:entry_id, :user_id, :content, :name, :font, :color])
    |> validate_length(:content, min: 1, max: 10_000)
    |> validate_parent_entry(attrs)
  end

  defp validate_parent_entry(changeset, attrs) do
    parent_id = Map.get(attrs, "parent_id") || Map.get(attrs, :parent_id)
    entry_id = get_field(changeset, :entry_id)

    if parent_id && entry_id do
      case Strangepaths.Repo.get(Strangepaths.Library.Marginalia, parent_id) do
        nil ->
          add_error(changeset, :parent_id, "does not exist")
        parent ->
          if parent.entry_id == entry_id,
            do: changeset,
            else: add_error(changeset, :parent_id, "must belong to the same entry")
      end
    else
      changeset
    end
  end
end
```

Note: `parent_id` uses `field(:parent_id, :id)` rather than `belongs_to` — this is intentional. A full `belongs_to(:parent, ...)` association on a self-referential table requires extra care to avoid circular preloads; the raw `:id` field is sufficient for adjacency-list queries.

**Verification:**

```bash
mix compile --no-deps-check
```

No errors. The five modules are compiled. If you see "undefined function" errors for `Strangepaths.Scenes.Post` or `Strangepaths.Accounts.User`, verify those module paths with:

```bash
grep -rn "defmodule Strangepaths.Scenes.Post\|defmodule Strangepaths.Accounts.User" lib/
```
<!-- END_TASK_3 -->

<!-- END_SUBCOMPONENT_A -->

<!-- START_SUBCOMPONENT_B (tasks 4-6) -->

<!-- START_TASK_4 -->
### Task 4: Library context module

Create `lib/strangepaths/library.ex`. This is the public API for the Library domain. Follow the pattern of `lib/strangepaths/bbs.ex` — imports, aliases at the top, functions grouped by entity.

```elixir
defmodule Strangepaths.Library do
  import Ecto.Query
  alias Strangepaths.Repo
  alias Strangepaths.Library.{Folio, FolioTag, Entry, Marginalia, UserTypeface}

  # === USER TYPEFACES ===

  def assign_user_typeface(user_id, typeface_id) do
    %UserTypeface{}
    |> UserTypeface.changeset(%{user_id: user_id, typeface_id: typeface_id})
    |> Repo.insert(on_conflict: :nothing, conflict_target: [:user_id, :typeface_id])
  end

  def remove_user_typeface(user_id, typeface_id) do
    case Repo.get_by(UserTypeface, user_id: user_id, typeface_id: typeface_id) do
      nil -> {:error, :not_found}
      ut -> Repo.delete(ut)
    end
  end

  def list_user_typefaces(user_id) do
    from(ut in UserTypeface, where: ut.user_id == ^user_id, select: ut.typeface_id)
    |> Repo.all()
  end

  def is_folio_editor?(user_id) do
    Repo.exists?(from ut in UserTypeface, where: ut.user_id == ^user_id)
  end

  def folio_editor_typefaces(user_id) do
    typeface_ids = list_user_typefaces(user_id)
    Strangepaths.Library.Typefaces.all()
    |> Enum.filter(&(&1.id in typeface_ids))
  end

  # === FOLIOS ===

  def list_folios do
    from(f in Folio, order_by: [desc: f.inserted_at])
    |> Repo.all()
  end

  def get_folio!(id), do: Repo.get!(Folio, id)

  def get_folio_by_slug!(slug), do: Repo.get_by!(Folio, slug: slug)

  def create_folio(user, attrs) do
    %Folio{}
    |> Folio.create_changeset(Map.put(attrs, "user_id", user.id))
    |> Repo.insert()
  end

  def update_folio_title(folio, attrs) do
    folio
    |> Folio.title_changeset(attrs)
    |> Repo.update()
  end

  def delete_folio(folio), do: Repo.delete(folio)

  def change_folio(folio \\ %Folio{}, attrs \\ %{}) do
    Folio.create_changeset(folio, attrs)
  end

  # === TAGS ===

  def list_tags(folio_id) do
    from(t in FolioTag, where: t.folio_id == ^folio_id, select: t.tag, order_by: t.tag)
    |> Repo.all()
  end

  def add_tag(folio, tag) do
    normalized = tag |> String.downcase() |> String.trim()

    %FolioTag{}
    |> FolioTag.changeset(%{folio_id: folio.id, tag: normalized})
    |> Repo.insert(on_conflict: :nothing, conflict_target: [:folio_id, :tag])
  end

  def remove_tag(folio, tag) do
    normalized = tag |> String.downcase() |> String.trim()

    case Repo.get_by(FolioTag, folio_id: folio.id, tag: normalized) do
      nil -> {:ok, nil}
      ft -> Repo.delete(ft)
    end
  end

  # === ENTRIES ===

  def list_entries(folio_id) do
    from(e in Entry,
      where: e.folio_id == ^folio_id,
      order_by: e.position,
      preload: [:scene_post]
    )
    |> Repo.all()
  end

  def create_post_entry(folio, user, scene_post_id, position \\ nil) do
    pos = position || next_entry_position(folio.id)

    %Entry{}
    |> Entry.post_ref_changeset(%{
      folio_id: folio.id,
      user_id: user.id,
      scene_post_id: scene_post_id,
      position: pos
    })
    |> Repo.insert()
  end

  def create_note_entry(folio, user, attrs, position \\ nil) do
    pos = position || next_entry_position(folio.id)

    %Entry{}
    |> Entry.note_changeset(
      attrs
      |> Map.put("folio_id", folio.id)
      |> Map.put("user_id", user.id)
      |> Map.put("position", pos)
    )
    |> Repo.insert()
  end

  def delete_entry(entry), do: Repo.delete(entry)

  def update_note_entry(entry, attrs) do
    entry
    |> Entry.note_changeset(attrs)
    |> Repo.update()
  end

  def reorder_entries(folio_id, ordered_ids) do
    ordered_ids
    |> Enum.with_index(1)
    |> Enum.each(fn {id, position} ->
      from(e in Entry, where: e.id == ^id and e.folio_id == ^folio_id)
      |> Repo.update_all(set: [position: position])
    end)

    :ok
  end

  defp next_entry_position(folio_id) do
    from(e in Entry, where: e.folio_id == ^folio_id, select: count(e.id))
    |> Repo.one()
    |> Kernel.+(1)
  end

  # === MARGINALIA ===

  def list_marginalia(entry_id) do
    from(m in Marginalia,
      where: m.entry_id == ^entry_id,
      order_by: m.inserted_at,
      preload: [:user]
    )
    |> Repo.all()
  end

  def create_marginalia(entry, user, attrs) do
    %Marginalia{}
    |> Marginalia.create_changeset(
      attrs
      |> Map.put("entry_id", entry.id)
      |> Map.put("user_id", user.id)
    )
    |> Repo.insert()
  end
end
```

**Run the failing tests before adding fixtures:**

```bash
mix test test/strangepaths/library_test.exs
```

There is no test file yet, so this will error with "no files found" — that's expected. Create the test file in Tasks 5–6 next.

**Verify compilation passes:**

```bash
mix compile --no-deps-check
```
<!-- END_TASK_4 -->

<!-- START_TASK_5 -->
### Task 5: Test fixtures

Create `test/support/fixtures/library_fixtures.ex`. The pattern here matches `test/support/fixtures/bbs_fixtures.ex` and `test/support/fixtures/accounts_fixtures.ex`.

```elixir
defmodule Strangepaths.LibraryFixtures do
  alias Strangepaths.Library
  import Strangepaths.AccountsFixtures

  def user_typeface_fixture(user \\ nil, typeface_id \\ "jorule") do
    user = user || user_fixture()
    {:ok, _} = Library.assign_user_typeface(user.id, typeface_id)
    user
  end

  def folio_fixture(user \\ nil, attrs \\ %{}) do
    user = user || user_typeface_fixture()

    merged =
      attrs
      |> Enum.into(%{
        "title" => "Test Folio #{System.unique_integer([:positive])}",
        "subtitle" => nil,
        "body" => nil
      })

    {:ok, folio} = Library.create_folio(user, merged)
    folio
  end

  def post_entry_fixture(folio \\ nil, user \\ nil, scene_post_id \\ nil) do
    folio = folio || folio_fixture()
    user = user || user_typeface_fixture()

    post_id =
      scene_post_id ||
        raise "post_entry_fixture requires a scene_post_id — " <>
                "get one from a scene fixture or create a scene post first"

    {:ok, entry} = Library.create_post_entry(folio, user, post_id)
    entry
  end

  def note_entry_fixture(folio \\ nil, user \\ nil, attrs \\ %{}) do
    folio = folio || folio_fixture()
    user = user || user_typeface_fixture()

    typefaces = Library.folio_editor_typefaces(user.id)
    tf = List.first(typefaces) || raise "user has no typeface — use user_typeface_fixture first"

    merged =
      attrs
      |> Enum.into(%{
        "content" => "A test inline note",
        "name" => tf.name,
        "font" => tf.font,
        "color" => tf.color
      })

    {:ok, entry} = Library.create_note_entry(folio, user, merged)
    entry
  end

  def marginalia_fixture(entry \\ nil, user \\ nil, attrs \\ %{}) do
    folio = folio_fixture()
    entry = entry || note_entry_fixture(folio)
    user = user || user_typeface_fixture()

    typefaces = Library.folio_editor_typefaces(user.id)
    tf = List.first(typefaces) || raise "user has no typeface — use user_typeface_fixture first"

    merged =
      attrs
      |> Enum.into(%{
        "content" => "A test comment",
        "name" => tf.name,
        "font" => tf.font,
        "color" => tf.color
      })

    {:ok, marginalia} = Library.create_marginalia(entry, user, merged)
    marginalia
  end
end
```

**Note on `post_entry_fixture`:** It raises rather than silently creating a dummy post because `scene_post_id` must reference a real row in `scene_posts`. Tests that need post entries should create a scene and scene post first using existing scene fixtures. Check `test/support/fixtures/` for a scenes fixture — if one doesn't exist, use the Scenes context directly in the test.

**Verify it compiles:**

```bash
mix compile --no-deps-check
```
<!-- END_TASK_5 -->

<!-- START_TASK_6 -->
### Task 6: Library context tests

Create `test/strangepaths/library_test.exs`. Structure follows `test/strangepaths/bbs_test.exs`.

```elixir
defmodule Strangepaths.LibraryTest do
  use Strangepaths.DataCase

  alias Strangepaths.Library

  import Strangepaths.LibraryFixtures
  import Strangepaths.AccountsFixtures

  # ---- Verifies: liminal-library.AC1.4, AC1.5 ----
  describe "is_folio_editor?/1" do
    test "returns false for user with no typefaces" do
      user = user_fixture()
      refute Library.is_folio_editor?(user.id)
    end

    test "returns true after assigning a typeface" do
      user = user_typeface_fixture()
      assert Library.is_folio_editor?(user.id)
    end
  end

  # ---- Verifies: liminal-library.AC1.2, AC1.3 ----
  describe "assign_user_typeface/2 and remove_user_typeface/2" do
    test "assigns a valid typeface to a user" do
      user = user_fixture()
      assert {:ok, _} = Library.assign_user_typeface(user.id, "jorule")
      assert Library.is_folio_editor?(user.id)
    end

    test "assigning the same typeface twice is a no-op" do
      user = user_fixture()
      {:ok, _} = Library.assign_user_typeface(user.id, "jorule")
      assert {:ok, _} = Library.assign_user_typeface(user.id, "jorule")
      assert length(Library.list_user_typefaces(user.id)) == 1
    end

    test "assigning an invalid typeface id returns an error" do
      user = user_fixture()
      assert {:error, changeset} = Library.assign_user_typeface(user.id, "nonexistent")
      assert %{typeface_id: ["is not a valid typeface"]} = errors_on(changeset)
    end

    test "revokes an assigned typeface" do
      user = user_typeface_fixture()
      assert {:ok, _} = Library.remove_user_typeface(user.id, "jorule")
      refute Library.is_folio_editor?(user.id)
    end

    test "revoking a typeface not assigned returns error tuple" do
      user = user_fixture()
      assert {:error, :not_found} = Library.remove_user_typeface(user.id, "jorule")
    end
  end

  # ---- Verifies: liminal-library.AC2.1, AC2.2, AC2.3, AC2.4, AC2.5 ----
  describe "create_folio/2" do
    test "creates folio with title only" do
      user = user_typeface_fixture()
      assert {:ok, folio} = Library.create_folio(user, %{"title" => "The Broken Seal"})
      assert folio.title == "The Broken Seal"
      assert folio.slug == "the-broken-seal"
      assert folio.user_id == user.id
      assert is_nil(folio.subtitle)
      assert is_nil(folio.body)
    end

    test "slug is auto-generated from title (AC2.2)" do
      user = user_typeface_fixture()
      {:ok, folio} = Library.create_folio(user, %{"title" => "Letters from Elsewhere"})
      assert folio.slug == "letters-from-elsewhere"
    end

    test "creates folio with subtitle" do
      user = user_typeface_fixture()
      {:ok, folio} =
        Library.create_folio(user, %{
          "title" => "Night Court Transcript",
          "subtitle" => "Session 7, Unredacted"
        })

      assert folio.subtitle == "Session 7, Unredacted"
    end

    test "creates folio with body only and no entries (AC2.4)" do
      user = user_typeface_fixture()
      {:ok, folio} =
        Library.create_folio(user, %{
          "title" => "Body-Only Folio",
          "body" => "Some diegetic prose here."
        })

      assert folio.body == "Some diegetic prose here."
      assert Library.list_entries(folio.id) == []
    end

    test "creates folio without body (entries-only valid) (AC2.5)" do
      user = user_typeface_fixture()
      {:ok, folio} = Library.create_folio(user, %{"title" => "Entries Only Folio"})
      assert is_nil(folio.body)
    end

    test "duplicate title returns error changeset (AC2.3)" do
      user = user_typeface_fixture()
      {:ok, _} = Library.create_folio(user, %{"title" => "Unique Title"})
      assert {:error, changeset} = Library.create_folio(user, %{"title" => "Unique Title"})
      assert %{title: ["has already been taken"]} = errors_on(changeset)
    end

    test "blank title returns error changeset" do
      user = user_typeface_fixture()
      assert {:error, changeset} = Library.create_folio(user, %{"title" => ""})
      assert %{title: _} = errors_on(changeset)
    end
  end

  # ---- Verifies: liminal-library.AC8.1 ----
  describe "tags" do
    test "adds a tag to a folio" do
      folio = folio_fixture()
      {:ok, _} = Library.add_tag(folio, "history")
      assert Library.list_tags(folio.id) == ["history"]
    end

    test "tags are stored lowercased and trimmed (AC8.1)" do
      folio = folio_fixture()
      {:ok, _} = Library.add_tag(folio, "  RITUAL  ")
      assert Library.list_tags(folio.id) == ["ritual"]
    end

    test "duplicate adds are no-ops (AC8.1)" do
      folio = folio_fixture()
      {:ok, _} = Library.add_tag(folio, "lore")
      {:ok, _} = Library.add_tag(folio, "lore")
      assert Library.list_tags(folio.id) == ["lore"]
    end

    test "removes a tag" do
      folio = folio_fixture()
      {:ok, _} = Library.add_tag(folio, "lore")
      {:ok, _} = Library.remove_tag(folio, "lore")
      assert Library.list_tags(folio.id) == []
    end

    test "removing a tag that does not exist is a no-op" do
      folio = folio_fixture()
      assert {:ok, _} = Library.remove_tag(folio, "nonexistent")
    end
  end

  describe "entries" do
    test "creates an inline note entry" do
      user = user_typeface_fixture()
      folio = folio_fixture(user)
      [tf | _] = Library.folio_editor_typefaces(user.id)

      {:ok, entry} =
        Library.create_note_entry(folio, user, %{
          "content" => "This is a note.",
          "name" => tf.name,
          "font" => tf.font,
          "color" => tf.color
        })

      assert entry.kind == :note
      assert entry.content == "This is a note."
      assert entry.folio_id == folio.id
    end

    test "creates entries with sequential positions" do
      user = user_typeface_fixture()
      folio = folio_fixture(user)
      [tf | _] = Library.folio_editor_typefaces(user.id)
      note_attrs = %{"content" => "x", "name" => tf.name, "font" => tf.font, "color" => tf.color}

      {:ok, e1} = Library.create_note_entry(folio, user, note_attrs)
      {:ok, e2} = Library.create_note_entry(folio, user, note_attrs)

      assert e2.position > e1.position
    end

    test "reorders entries" do
      user = user_typeface_fixture()
      folio = folio_fixture(user)
      [tf | _] = Library.folio_editor_typefaces(user.id)
      note_attrs = %{"content" => "x", "name" => tf.name, "font" => tf.font, "color" => tf.color}

      {:ok, e1} = Library.create_note_entry(folio, user, note_attrs)
      {:ok, e2} = Library.create_note_entry(folio, user, note_attrs)

      :ok = Library.reorder_entries(folio.id, [e2.id, e1.id])

      [first, second] = Library.list_entries(folio.id)
      assert first.id == e2.id
      assert second.id == e1.id
    end

    test "deletes an entry" do
      user = user_typeface_fixture()
      folio = folio_fixture(user)
      entry = note_entry_fixture(folio, user)

      {:ok, _} = Library.delete_entry(entry)
      assert Library.list_entries(folio.id) == []
    end
  end

  describe "marginalia" do
    test "creates marginalia on an entry" do
      user = user_typeface_fixture()
      folio = folio_fixture(user)
      entry = note_entry_fixture(folio, user)
      [tf | _] = Library.folio_editor_typefaces(user.id)

      {:ok, m} =
        Library.create_marginalia(entry, user, %{
          "content" => "Interesting.",
          "name" => tf.name,
          "font" => tf.font,
          "color" => tf.color
        })

      assert m.entry_id == entry.id
      assert m.content == "Interesting."
      assert m.name == tf.name
    end

    test "creates a reply to marginalia" do
      user = user_typeface_fixture()
      folio = folio_fixture(user)
      entry = note_entry_fixture(folio, user)
      [tf | _] = Library.folio_editor_typefaces(user.id)

      {:ok, parent} =
        Library.create_marginalia(entry, user, %{
          "content" => "First comment.",
          "name" => tf.name,
          "font" => tf.font,
          "color" => tf.color
        })

      {:ok, reply} =
        Library.create_marginalia(entry, user, %{
          "content" => "Reply to that.",
          "name" => tf.name,
          "font" => tf.font,
          "color" => tf.color,
          "parent_id" => parent.id
        })

      assert reply.parent_id == parent.id
    end
  end
end
```

**Run the tests:**

```bash
mix test test/strangepaths/library_test.exs
```

All tests should pass. If any fail, fix the context or schema before moving on.

**Run the full test suite to check for regressions:**

```bash
mix test
```

**Commit when all tests pass:**

```
git add priv/repo/migrations/20260427120001_create_library_user_typefaces.exs \
        priv/repo/migrations/20260427120002_create_library_folios.exs \
        priv/repo/migrations/20260427120003_create_library_folio_tags.exs \
        priv/repo/migrations/20260427120004_create_library_entries.exs \
        priv/repo/migrations/20260427120005_create_library_marginalia.exs \
        lib/strangepaths/library/typefaces.ex \
        lib/strangepaths/library/user_typeface.ex \
        lib/strangepaths/library/folio.ex \
        lib/strangepaths/library/folio_tag.ex \
        lib/strangepaths/library/entry.ex \
        lib/strangepaths/library/marginalia.ex \
        lib/strangepaths/library.ex \
        test/support/fixtures/library_fixtures.ex \
        test/strangepaths/library_test.exs
git commit -m "liminal library phase 1: data layer"
```
<!-- END_TASK_6 -->

<!-- END_SUBCOMPONENT_B -->
