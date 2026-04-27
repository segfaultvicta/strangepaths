# Liminal Library Design

## Summary

The Liminal Library is a new feature that gives designated users a space to assemble curated documents — called **folios** — from the application's collaborative scene posts, freestanding diegetic prose, or a combination of both. Access is gated by a typeface identity system: a dragon (admin) assigns named typefaces to users, and having at least one typeface assigned makes someone a folio editor. This double function — access credential and visual identity — means every piece of writing in the library (marginalia, inline notes, body text) carries the distinct font and color of the person who wrote it, reinforcing the in-world fiction that contributors are leaving handwritten annotations in a shared archive.

The implementation adds a self-contained `Strangepaths.Library` Phoenix context with five new database tables, a code-side typeface registry (no database table — typefaces are a module attribute that requires a code push to change), and a rendering pipeline that extends the existing glyph+Markdown processor with a typeface-tag pass before handing off to the established `render_post_content/2` function. The most complex surface is the split-panel post collection composer, which lets editors browse and filter scenes, pick individual posts or contiguous ranges, drag entries into order via Sortable.js, and insert inline notes — all in a single LiveView. Concurrent body editing is governed by a database-level mutex (locked_by/locked_at fields with a server-side timeout) following the same pattern already used by the rumor map. Real-time marginalia delivery reuses the PubSub broadcast pattern established by scenes and the BBS forum.

## Definition of Done

1. Dragon can manage folio access by assigning named typeface identities (name, font-family, color) to users via `/library/admin`; users with at least one assigned typeface can create folios and add marginalia
2. Folio editors can create folios with a unique title (slug-generated), optional subtitle, and optional body text (glyph+markdown with `[name]text[/name]` typeface tags)
3. Folio body editing is available to any folio editor with a mutex preventing concurrent edits; body editor includes a live server-rendered preview pane
4. Post collection composer (split-panel at `/library/new` and `/library/:slug/compose`) allows selecting posts from a scene browser with title/tag filtering, "scenes I was in" toggle, range selection, insertion caret, drag-to-reorder via Sortable.js, inline note insertion, and entry grouping
5. Only the folio's original author (and dragon) can reorder, delete, or edit entries; any folio editor can add post entries or inline notes to any folio
6. Any folio editor can add threaded viewer marginalia to any entry; marginalia render in the poster's named typeface; marginalia threads are collapsed by default on the view page
7. Folios are publicly viewable at `/library/:slug`; library search indexes only folios (title, subtitle, body, tags); the existing Scenes/Archive search is not modified
8. Dragon can delete any folio; any folio editor can add or remove tags on any folio

## Acceptance Criteria

### liminal-library.AC1: Dragon manages typeface assignment (folio access)
- **liminal-library.AC1.1 Success:** Dragon can view all users and their current typeface assignments at `/library/admin`
- **liminal-library.AC1.2 Success:** Dragon can assign one or more typefaces to any user, including themselves
- **liminal-library.AC1.3 Success:** Dragon can revoke a typeface assignment
- **liminal-library.AC1.4 Success:** User with ≥1 assigned typeface can create folios and add marginalia
- **liminal-library.AC1.5 Failure:** User with no assigned typefaces cannot access folio creation
- **liminal-library.AC1.6 Failure:** User with no assigned typefaces cannot add marginalia

### liminal-library.AC2: Folio creation
- **liminal-library.AC2.1 Success:** Folio editor can create a folio with a unique title and optional subtitle
- **liminal-library.AC2.2 Success:** Slug is auto-generated from title (lowercased, hyphenated)
- **liminal-library.AC2.3 Failure:** Duplicate title returns a validation error
- **liminal-library.AC2.4 Success:** Folio with body only (no entries) is valid and viewable
- **liminal-library.AC2.5 Success:** Folio with entries only (no body) is valid and viewable
- **liminal-library.AC2.6 Failure:** Non-folio-editor cannot access folio creation

### liminal-library.AC3: Body editor with mutex and live preview
- **liminal-library.AC3.1 Success:** Any folio editor can open the body editor and save changes to any folio
- **liminal-library.AC3.2 Failure:** When editor A holds the mutex, editor B sees a locked state and cannot open the editor
- **liminal-library.AC3.3 Success:** Mutex releases on save, on cancel, and on inactivity timeout
- **liminal-library.AC3.4 Success:** `[name]text[/name]` with a known typeface name renders as a styled span
- **liminal-library.AC3.5 Success:** `[name]text[/name]` with an unknown name renders as literal text (brackets visible)
- **liminal-library.AC3.6 Success:** Glyph pairs in body render correctly in preview and on the view page
- **liminal-library.AC3.7 Success:** Live preview pane updates on body text change

### liminal-library.AC4: Post collection composer
- **liminal-library.AC4.1 Success:** Scene browser shows all scenes with archive tag badges
- **liminal-library.AC4.2 Success:** Title/tag filter narrows scene list; `#full cast session` scenes always appear regardless
- **liminal-library.AC4.3 Success:** Full-cast-session scenes have a distinct background color in the scene list
- **liminal-library.AC4.4 Success:** "Scenes I was in" toggle filters to only scenes the current user has posts in
- **liminal-library.AC4.5 Success:** Clicking a post adds it at the current insertion caret position
- **liminal-library.AC4.6 Success:** Shift-click range and From/To caret buttons both select contiguous post ranges
- **liminal-library.AC4.7 Success:** Entries can be reordered by dragging; grouped entries (shared group_id) move as a unit
- **liminal-library.AC4.8 Success:** Inline note can be inserted between any two entries
- **liminal-library.AC4.9 Success:** Insertion caret is placeable between any two entries and persists between additions

### liminal-library.AC5: Entry permissions
- **liminal-library.AC5.1 Success:** Any folio editor can add post entries and inline notes to any folio
- **liminal-library.AC5.2 Success:** Folio author (and dragon) can reorder, delete, and edit entries in their folio
- **liminal-library.AC5.3 Failure:** Non-author folio editor cannot reorder, delete, or edit existing entries

### liminal-library.AC6: Marginalia
- **liminal-library.AC6.1 Success:** Any folio editor can add marginalia to any entry on any folio
- **liminal-library.AC6.2 Success:** User with multiple typefaces sees a dropdown when adding marginalia
- **liminal-library.AC6.3 Success:** Marginalia render in the poster's stored typeface (name/font/color)
- **liminal-library.AC6.4 Success:** Marginalia threads are collapsed by default with count badge visible
- **liminal-library.AC6.5 Success:** Expanding a thread shows marginalia inline below the entry, with replies indented
- **liminal-library.AC6.6 Success:** New marginalia appear in real-time for all active viewers
- **liminal-library.AC6.7 Failure:** Non-folio-editor cannot add marginalia

### liminal-library.AC7: Browse and search
- **liminal-library.AC7.1 Success:** Library search returns folios matching title, subtitle, body, or tags
- **liminal-library.AC7.2 Success:** Library search results never include scenes or codex pages
- **liminal-library.AC7.3 Success:** Results can be filtered by author and by tag, and sorted by date/title/author
- **liminal-library.AC7.4 Success:** Existing Scenes/Archive search returns unchanged results after this feature ships

### liminal-library.AC8: Tags and deletion
- **liminal-library.AC8.1 Success:** Any folio editor can add and remove tags on any folio; tags are stored lowercased and trimmed; duplicate adds are no-ops
- **liminal-library.AC8.2 Failure:** Non-folio-editor cannot add or remove tags
- **liminal-library.AC8.3 Success:** Dragon can delete any folio
- **liminal-library.AC8.4 Failure:** Non-dragon user cannot delete a folio

## Glossary

- **Folio**: A curated document in the Liminal Library. Can contain scene post excerpts, freestanding prose (the "body"), inline notes, and threaded marginalia from other editors.
- **Folio editor**: A user who has been assigned at least one typeface by a dragon. Grants permission to create folios, add entries, add marginalia, and manage tags.
- **Typeface identity**: A named visual persona (`name`, `font-family`, `color`) assigned to a user by a dragon. Serves as both an access credential and a rendering identity — all a user's contributions render in their assigned typeface.
- **Typeface master list**: A code-side Elixir module (`typefaces.ex`) holding all valid typefaces as a module attribute. No database table; adding a typeface requires a deploy.
- **Entry**: A single item in a folio's ordered list. Either a `:post_ref` (live reference to a scene post) or a `:note` (freestanding inline text).
- **Marginalia**: Threaded comments attached to individual folio entries, visible to all viewers, addable by any folio editor, rendered in the commenter's stored typeface.
- **Body**: The freestanding prose field of a folio (distinct from entries). Supports glyph+markdown and `[name]text[/name]` typeface tags. Edited via the inline body editor.
- **Body mutex**: A concurrency lock on folio body editing. Stored as `body_locked_by_id` / `body_locked_at` on the folio row; released on save, cancel, or inactivity timeout via `Process.send_after`.
- **Insertion caret**: A highlighted divider in the composer's right panel indicating where the next added post or note will land. Persists between additions and auto-advances.
- **Group ID**: A UUID shared by entries that belong together; entries sharing a `group_id` move as a unit during drag-to-reorder in the composer.
- **`#full cast session`**: An archive tag that marks scenes as always visible in the composer scene browser, immune to all title/tag filters, and rendered with a distinct background color.
- **`[name]text[/name]` tag**: A custom markup tag (e.g. `[jorule]text[/jorule]`) processed by `render_library_content/2`. Known names render as a styled `<span>`; unknown names render as literal text with brackets visible.
- **`render_library_content/2`**: New helper in `library_helpers.ex` that prepends a typeface-tag pass to the existing `render_post_content/2` glyph+Earmark pipeline.
- **`render_post_content/2`**: The established rendering pipeline in `scene_helpers.ex` that handles escaped glyphs, glyph pairs, and Earmark markdown. Used throughout scenes and BBS; reused here by delegation.
- **Grimoire**: An existing JavaScript hook that provides the glyph symbol toolbar in text editors (scenes, BBS reply forms). Reused on the body editor and marginalia forms.
- **LibraryComposer**: A new JavaScript hook (`assets/js/app.js`) handling Sortable.js drag-to-reorder, shift-click range selection, and insertion caret management in the composer.
- **`assign_defaults/2`**: A LiveView helper in `LiveHelpers` that loads the current user into socket assigns. Called by every LiveView in the application, including all new Library LiveViews.
- **Dragon**: The admin role in Strangepaths. Dragons can assign typefaces, delete any folio, pin/lock BBS threads, and perform other privileged operations. Checked via `current_user.role == :dragon`.
- **PubSub**: Phoenix's publish/subscribe system. Used here to broadcast new marginalia on `"library_folio:#{folio_id}"` so all active viewers receive them in real-time without polling.
- **Sortable.js**: A JavaScript drag-and-drop library already in the asset stack. Used in the composer's right panel for entry reordering.
- **Earmark**: An Elixir library that converts Markdown to HTML. Part of the existing rendering pipeline that `render_library_content/2` delegates to.
- **Adjacency list**: A self-referencing database pattern where `parent_id` points to another row in the same table. Used here for marginalia threading.
- **Slug**: A URL-safe identifier derived from a title (lowercased, spaces to hyphens, punctuation stripped). Folios are routed by slug at `/library/:slug`.
- **Phoenix context**: An Elixir module that encapsulates a bounded domain — schemas, queries, and business logic for one area of the application. The new `Strangepaths.Library` context follows the same structure as `Strangepaths.BBS` and `Strangepaths.Scenes`.
- **LiveView**: Phoenix's server-side rendering framework for interactive UI. The page HTML is rendered on the server and updated over a persistent WebSocket; no separate client-side framework needed for most interactions.

---

## Architecture

The Liminal Library is an in-world archival system ("the Aethernet's institutional memory") where designated folio editors can compose curated documents — **folios** — from scene post excerpts, freestanding diegetic text, or both. Viewer marginalia allow threaded commentary on individual entries, styled in the commenter's named typeface identity.

### Domain Context

A new `Strangepaths.Library` context lives at `lib/strangepaths/library/`. It exposes the public API for folios, entries, marginalia, tags, and user typeface assignments. Schemas live in `lib/strangepaths/library/` subdirectory.

The typeface master list is a code-side module (`lib/strangepaths/library/typefaces.ex`) — a module attribute list of `%{id, name, font, color}` maps. No database table; adding a new typeface requires a code push.

### Data Model

**`library_user_typefaces`** — grants folio access. `user_id` (FK users), `typeface_id` (string, references master list). A user with ≥1 row here is a folio editor. Dragon manages this via `/library/admin`.

**`library_folios`** — `id`, `slug` (unique, generated from title), `title` (unique), `subtitle` (nullable), `body` (text, nullable — stores raw glyph+markdown+typeface-tag content), `user_id` (original creator), `body_locked_by_id` (nullable FK users), `body_locked_at` (nullable UTC datetime), `inserted_at`, `updated_at`.

**`library_folio_tags`** — `folio_id`, `tag` (string). Any folio editor can add or remove.

**`library_entries`** — `id`, `folio_id`, `position` (integer), `kind` (enum: `:post_ref` | `:note`), `scene_post_id` (nullable FK scene posts — live reference, not snapshot), `content` (nullable text), `name` (nullable string), `font` (nullable string), `color` (nullable string), `group_id` (nullable UUID — entries sharing a group_id move as a unit in the composer), `user_id` (who added this entry), `inserted_at`.

**`library_marginalia`** — `id`, `entry_id` (FK library_entries), `parent_id` (nullable self-FK for threading), `content`, `name`, `font`, `color` (typeface identity of poster at time of posting), `user_id`, `inserted_at`.

### Rendering Pipeline

A new helper `render_library_content/2` in `lib/strangepaths_web/library_helpers.ex` processes body text and inline note content. It extends the existing `render_post_content/2` pipeline (in `lib/strangepaths_web/scene_helpers.ex`) by prepending a typeface-tag pass:

1. Process `[name]text[/name]` tags — replace known names (from typeface master list) with `<span style="font-family: ...; color: ...">text</span>`; render unknown names as literal text (tag visible)
2. Pass result through existing glyph pipeline (protect escaped glyphs, extract glyph pairs, Earmark markdown, restore styled spans)

Marginalia and inline notes are rendered in their stored typeface directly (name/font/color stored at post time, no lookup needed at render time).

### Scene Post References

Entries of kind `:post_ref` hold a live FK to `scene_posts`. Scene posts are treated as effectively immutable once archived (scenes are locked before archival, and re-canonicalization would precede any library work). No snapshotting is needed.

### Permissions

| Action | Anyone | Folio editor | Author | Dragon |
|---|---|---|---|---|
| View folios & marginalia | ✓ | ✓ | ✓ | ✓ |
| Add / remove tags | | ✓ | ✓ | ✓ |
| Add marginalia | | ✓ | ✓ | ✓ |
| Edit body (with mutex) | | ✓ | ✓ | ✓ |
| Add post entries & inline notes | | ✓ | ✓ | ✓ |
| Delete entries / edit inline notes / reorder | | | ✓ | ✓ |
| Edit title / subtitle | | | ✓ | ✓ |
| Delete folio | | | | ✓ |
| Assign typefaces to users | | | | ✓ |

### Routes

| Path | LiveView | Purpose |
|---|---|---|
| `/library` | `LibraryLive.FolioList` | Landing page + browse/search |
| `/library/new` | `LibraryLive.Composer` | Create new folio |
| `/library/admin` | `LibraryLive.Admin` | Dragon typeface assignment |
| `/library/:slug` | `LibraryLive.Folio` | View folio |
| `/library/:slug/compose` | `LibraryLive.Composer` | Add entries to existing folio |

### Composer UX (Split Panel)

The composer is a split-panel LiveView. Left panel: scene browser with search/filter (title or archive tag), "scenes I was in" toggle (filters by current user's post presence in scene), collapsible scene rows showing posts. Scenes tagged `#full cast session` are immune to all filters and render with a distinct background color. Each post row has hover-revealed `[↑ From]` / `[↓ To]` buttons for explicit range selection; shift-click also works. Clicking a post adds it at the current insertion caret.

Right panel: the live entry list. An insertion caret (highlighted divider, set by clicking between entries) indicates where the next addition lands; defaults to end-of-list and auto-advances after each add. Entries are draggable via Sortable.js (a new `LibraryComposer` JS hook in `assets/js/app.js`). Entries sharing a `group_id` move as a unit. An `+ Add note` affordance between any two entries opens an inline form for inline notes (rendered in the composer's current user typeface).

### Body Editor

The body editor lives on the folio view page (inline, not a separate route). Clicking "Edit body" claims the mutex (sets `body_locked_by_id`/`body_locked_at`); a `Process.send_after` timer releases stale locks after inactivity. If another folio editor is already editing, the button shows a locked state. Below the textarea, a live preview pane renders the current content via `render_library_content/2` on every change (debounced push from server on `phx-change`).

### Marginalia

Each entry on the folio view page has a collapsed indicator (count badge or toggle) that expands an inline thread below the entry. Threading is via `parent_id` adjacency list; depth is enforced at the context layer. New marginalia are broadcast via PubSub on `"library_folio:#{folio_id}"` and appended in real-time to all live viewers. Each marginalia item is rendered in the stored `name`/`font`/`color` typeface.

---

## Existing Patterns

This design follows established patterns throughout the codebase:

**Phoenix context structure:** Mirrors `lib/strangepaths/bbs/`, `lib/strangepaths/scenes/`, and `lib/strangepaths/cards/` — a public context module (`library.ex`) plus schema modules in a `library/` subdirectory.

**Slug-based URLs:** Scenes use slug-based routing; folios follow the same convention with a uniqueness constraint on `title`.

**Role-based access:** Dragon/user role checks via `@current_user.role == :dragon` follow the pattern established across all LiveViews.

**`assign_defaults/2`:** All new LiveViews call `assign_defaults(session, socket)` from `StrangepathsWeb.LiveHelpers` to load the current user, matching every existing LiveView.

**Rendering pipeline:** `render_post_content/2` in `lib/strangepaths_web/scene_helpers.ex` is the established glyph+Earmark pipeline. The new `render_library_content/2` prepends a typeface-tag pass before delegating to this function.

**Editing mutex:** The rumor map uses a node-level lock via locked_by/locked_at fields and `Process.send_after` for timeout. The folio body mutex follows the same pattern.

**Sortable.js reordering:** Already in the asset stack. The new `LibraryComposer` hook follows the pattern established in existing Sortable.js usage.

**PubSub real-time updates:** Scene posts broadcast on `"scene:#{scene.id}"`; BBS posts on `"bbs_thread:#{id}"`. Marginalia follow the same pattern on `"library_folio:#{folio_id}"`.

**Selection UI:** The avatar picker modal (in `lib/strangepaths_web/live/rumor_map_live/show.html.heex`) establishes the pattern for `phx-value-*` click handlers and selection state in assigns. The scene browser left panel adapts this pattern for posts.

**Code-side config:** No precedent in CLAUDE.md, but the approach (module attribute list, no DB table) is idiomatic Elixir for reference data that requires a code push to change.

---

## Implementation Phases

<!-- START_PHASE_1 -->
### Phase 1: Data Layer

**Goal:** All database tables, schemas, context module, and typeface config in place.

**Components:**
- `lib/strangepaths/library/typefaces.ex` — typeface master list module (`@typefaces` module attribute)
- `lib/strangepaths/library/folio.ex` — Folio schema with slug, body mutex fields
- `lib/strangepaths/library/entry.ex` — Entry schema with kind enum, group_id UUID, position
- `lib/strangepaths/library/marginalia.ex` — Marginalia schema with parent_id self-FK
- `lib/strangepaths/library/user_typeface.ex` — UserTypeface schema
- `lib/strangepaths/library.ex` — Context module: CRUD for folios, entries, marginalia, tags, user typefaces; `is_folio_editor?/1`, `folio_editor_typefaces/1`
- Migrations in `priv/repo/migrations/` — five migrations (library_user_typefaces, library_folios, library_folio_tags, library_entries, library_marginalia)

**Dependencies:** None (first phase)

**Done when:** `mix ecto.migrate` succeeds; context module compiles and tests pass for CRUD operations and `is_folio_editor?/1`
<!-- END_PHASE_1 -->

<!-- START_PHASE_2 -->
### Phase 2: Typeface System & Dragon Admin

**Goal:** Rendering pipeline for typeface tags and the admin UI for typeface assignment.

**Components:**
- `lib/strangepaths_web/library_helpers.ex` — `render_library_content/2`: typeface tag pass (`[name]...[/name]` → styled span or literal text) followed by `render_post_content/2`
- `lib/strangepaths_web/live/library/admin_live.ex` + `admin_live.html.heex` — Dragon-only LiveView at `/library/admin`; table of all users, checklist of available typefaces per row, save per user
- Route added to `lib/strangepaths_web/router.ex`

**Dependencies:** Phase 1

**Done when:** Dragon can assign and revoke typefaces; `[jorule]text[/jorule]` renders as styled span; unknown tags render as literal text; tests cover rendering pipeline edge cases
<!-- END_PHASE_2 -->

<!-- START_PHASE_3 -->
### Phase 3: Folio View & Basic CRUD

**Goal:** Folios can be created, viewed, and deleted; title/subtitle editing works; permission enforcement is in place.

**Components:**
- `lib/strangepaths_web/live/library/folio_live.ex` + `folio_live.html.heex` — View page at `/library/:slug`; renders title, subtitle, author, date, tags, body (via `render_library_content/2`), entry stream (post_ref entries rendered via existing scene post rendering, note entries rendered in stored typeface)
- `lib/strangepaths_web/live/library/folio_list_live.ex` + `folio_list_live.html.heex` — Landing page at `/library`; 10 most recent folios, "New Folio" and "Browse the Stacks" CTAs
- Folio creation form (title + subtitle fields) at `/library/new` (initial step before composer)
- Title/subtitle inline editing on view page (author + dragon only)
- Delete button on view page (dragon only)
- Routes added to `lib/strangepaths_web/router.ex`

**Dependencies:** Phase 1, Phase 2 (rendering)

**Done when:** Folios can be created with unique titles, viewed at correct slugs, deleted by dragon; title uniqueness constraint produces a validation error; permission enforcement tested for all actions in the table
<!-- END_PHASE_3 -->

<!-- START_PHASE_4 -->
### Phase 4: Body Editor

**Goal:** Collaborative body editing with live preview and edit mutex.

**Components:**
- Inline body editor on the folio view page (`folio_live.ex` extended) — "Edit body" button, textarea with Grimoire glyph toolbar and typeface tag buttons (one button per assigned typeface, inserts `[name][/name]` pair)
- Live preview pane: server renders `render_library_content/2` on `phx-change` (debounced), pushes rendered HTML to client
- Mutex: `claim_body_lock/2` and `release_body_lock/1` in `Library` context; `Process.send_after` in LiveView for stale-lock timeout; locked state shown to other editors

**Dependencies:** Phase 3

**Done when:** Any folio editor can open and save the body editor; concurrent edit attempt shows locked state; lock releases on save, cancel, or timeout; live preview renders typeface tags and glyphs correctly; tests cover mutex contention and timeout
<!-- END_PHASE_4 -->

<!-- START_PHASE_5 -->
### Phase 5: Post Collection Composer

**Goal:** Split-panel composer for building and editing post collections.

**Components:**
- `lib/strangepaths_web/live/library/composer_live.ex` + `composer_live.html.heex` — split-panel LiveView at `/library/new` (post-title-step) and `/library/:slug/compose`
- Left panel: scene list (all scenes with archive tag badges), title/tag filter input, "scenes I was in" toggle, `#full cast session` immunity logic and distinct background, collapsible scene rows, post rows with click-to-add, `[↑ From]` / `[↓ To]` range-caret buttons, shift-click range selection
- Right panel: live entry list, insertion caret (click-to-place between entries), Sortable.js drag-to-reorder, entry grouping (group_id UUID assigned on group creation), `+ Add note` inline form between entries, `✕` remove button (author/dragon only)
- `LibraryComposer` JS hook in `assets/js/app.js` — Sortable.js integration, shift-click range tracking, insertion caret management

**Dependencies:** Phase 3

**Done when:** Posts from multiple scenes can be added to an entry list; range selection (shift-click and From/To carets) works; entries reorder via drag; inline notes insert correctly; grouping moves entries as a unit; filter and "scenes I was in" toggle work; full-cast-session scenes immune to all filters; permission checks for add/reorder/delete enforced
<!-- END_PHASE_5 -->

<!-- START_PHASE_6 -->
### Phase 6: Marginalia System

**Goal:** Threaded viewer commentary on individual entries, real-time delivery.

**Components:**
- Marginalia section per entry in `folio_live.html.heex` — collapsed by default, count badge/toggle, expands inline below entry
- Marginalia reply form — inline, opens on "Reply" click; typeface auto-selected (or dropdown if user has multiple); content textarea with glyph toolbar
- Threading: indented rendering of `parent_id` chains; max depth enforced in `Library.create_marginalia/3`
- PubSub: subscribe to `"library_folio:#{folio_id}"` on mount; broadcast new marginalia on create; `handle_info` appends to correct entry's thread
- Marginalia rendered via stored `font`/`color` directly (no render_library_content pass needed for marginalia — plain text + glyphs only)

**Dependencies:** Phase 3

**Done when:** Any folio editor can add marginalia and replies; marginalia render in correct typeface; threads expand/collapse; new marginalia appear in real-time; non-editors see marginalia but cannot add; tests cover permission enforcement and real-time broadcast
<!-- END_PHASE_6 -->

<!-- START_PHASE_7 -->
### Phase 7: Browse, Search & Aesthetic Polish

**Goal:** Full browse/search experience and visual polish consistent with the site's aesthetic.

**Components:**
- Browse/search on landing page (`folio_list_live.ex` extended) — filter by author (dropdown), filter by tag (text input or tag cloud), sort by date/title/author; PostgreSQL full-text search on title + subtitle + body + tags; results paginated
- Tag management on folio view page — inline tag add (text input, folio editor only) and remove (× on each tag badge)
- Library-specific styles in `assets/css/app.scss` — `.library-*` CSS classes: folio layout, body rendering, entry stream, marginalia visual treatment (distinct left-border, indentation for replies), typeface tag span classes if CSS-class-based rendering is preferred over inline styles, full-cast-session scene background in composer left panel

**Dependencies:** Phases 3–6

**Done when:** Search returns correct folio results and excludes scenes/codex; filters and sort work; tags can be added and removed by folio editors; existing Scenes/Archive search untouched; visual polish complete and consistent with site aesthetic
<!-- END_PHASE_7 -->

---

## Additional Considerations

**Future scope (out of this design):** The existing Scenes/Archive search should eventually index BBS posts and possibly Library marginalia. This was explicitly deferred.

**Body mutex timeout:** The timeout duration (suggested: 5 minutes of inactivity) should match the rumor map node lock timeout for consistency.

**Scene post rendering in entry stream:** `:post_ref` entries render scene posts using the existing scene post rendering (avatar, author nickname, color_category, post_type styling). The full `render_post_content/2` pipeline applies. This reuses existing template partials where possible.

**Slug generation:** Slugs are generated from the title (downcased, spaces → hyphens, non-alphanumeric stripped). If a collision occurs (two titles that differ only in punctuation), a numeric suffix is appended. The uniqueness constraint is on `title` not `slug`, but both should be enforced.

**Tag normalization:** Tags are stored lowercased and stripped of leading/trailing whitespace at the context layer to avoid near-duplicate tags.
