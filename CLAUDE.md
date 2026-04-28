# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Strangepaths is a Phoenix 1.6 LiveView web application — a collaborative storytelling/campaign management platform with card game mechanics, a music player, and a rumor map (node graph). It serves as a tabletop RPG companion with real-time collaborative scenes, a 5-color card system, and character management.

## Tech Stack

- **Backend:** Elixir ~1.15, Phoenix 1.6.12, Phoenix LiveView 0.17.5
- **Database:** PostgreSQL with Ecto
- **Frontend:** esbuild (JS bundling), Tailwind CSS 3.1 + Dart Sass (styling), Alpine.js
- **UI Components:** Petal Components, wheelnav (radial menus), LeaderLine (connections), Sortable.js, Tippy.js
- **Deployment:** Fly.io (Dockerfile + fly.toml)

## Common Commands

```bash
# Setup
mix setup                     # Install deps + create/migrate/seed database
npm install --prefix assets   # Install JS dependencies

# Development
mix phx.server                # Start dev server (HTTPS on port 4001)
iex -S mix phx.server         # Start with IEx REPL attached

# Database
mix ecto.migrate              # Run pending migrations
mix ecto.reset                # Drop + recreate + seed database
mix ecto.rollback             # Rollback last migration

# Tests
mix test                      # Run all tests (auto-creates/migrates test DB)
mix test test/path/file.exs   # Run a single test file

# Assets
mix assets.build              # Dev build (esbuild + sass + tailwind)
mix assets.deploy             # Production build with minification
```

## Architecture

### Domain Contexts (`lib/strangepaths/`)

Business logic is organized into Phoenix contexts:

- **Accounts** — Users, authentication (bcrypt), character data (dice pools, arete, techne), avatars, character presets. Two roles: `user` and `dragon` (admin).
- **BBS** — Forum system with boards, threads, posts. Supports pinning/locking (dragon only), personal thread stickies, and smart unread tracking via read marks.
- **Cards** — Three card types (Rite/Grace/Status) organized by Aspects. Decks use a 5-color mana balance (15-point total). Cards have art, rules text, flavor text.
- **Scenes** — Collaborative roleplay scenes with IC/OOC posts, slug-based URLs, locking, and archiving. A special "Elsewhere" scene (only one allowed).
- **Site** — Static content pages (markdown via Earmark) and music/song management.
- **Rumor** — Node graph system with draggable nodes, connections, and an infinite canvas viewport.
- **Library** — Liminal Library: collaborative folios with body essays, ordered post-collections (post refs and inline notes), threaded marginalia, and tag taxonomy. Uses a typeface system (`[name]...[/name]` tags) gated by per-user typeface assignments granted by dragons.

Each context has a public API module (e.g., `accounts.ex`) plus schema modules in a subdirectory.

### GenServer Services (`application.ex`)

Four GenServers run under the application supervisor:

- `Strangepaths.Cards.Ceremony` — Ceremony state management
- `Strangepaths.Presence` — Real-time user presence tracking
- `Strangepaths.Site.MusicQueue` — Song queue with auto-advance, broadcasting via PubSub
- `Strangepaths.Scenes.SceneServer` — Scene state management

### Web Layer (`lib/strangepaths_web/`)

- **LiveViews** dominate the UI — scenes, cards, decks, ceremonies, OST player, rumor map, content pages, admin panels
- **Controllers** handle authentication flows and music file serving (GUID-based secure access)
- **JavaScript Hooks** (`assets/js/app.js`) handle complex client-side interactions:
  - `MusicPlayer` — Audio playback with BroadcastChannel for cross-tab sync
  - `Temenos` — Canvas-based avatar/card placement with wheelnav radial menus
  - `RumorMap*` — Interactive node graph with LeaderLine, pan/zoom, drag, touch support
  - `SceneFocusManager`, `ChatScrollManager`, `PostContentInput` — Scene UX (focus, auto-scroll, draft auto-save to localStorage)

### Key Routes

| Path | Purpose |
|------|---------|
| `/bbs` | Forum boards and threads (Phase 2) |
| `/scenes` | Active collaborative scenes |
| `/ost` | Music player (two discs) |
| `/cosmos` | Card browser/admin |
| `/codex` | Deck browser/admin |
| `/ceremony` | Ceremony browser/admin |
| `/rumor` | Rumor map (node graph) |
| `/content` | Static content pages |
| `/content/admin` | Content page management |
| `/avatars/admin` | Avatar management |
| `/lab/cardgen` | Card generation tool |
| `/library` | Liminal Library folio browser (search, filter, sort) |
| `/library/admin` | Typeface assignment (dragon only) |
| `/library/:slug` | Folio view (body essay, post collection, marginalia) |
| `/library/:slug/compose` | Post collection composer (folio editors only) |

### Frontend Patterns

- State lives in LiveView assigns — no separate client-side state management
- Dark mode via Tailwind class-based toggling
- Tailwind config safelists rumor map node colors (dynamic classes)
- Post drafts auto-saved to browser localStorage
- Music player volume persisted in localStorage

## BBS Forum System (Phase 1: Data Layer)

### Schema Overview

The BBS context manages a forum with five tables:

- **bbs_boards** — Forum boards (name, slug, description). Slugs auto-generated from board names.
- **bbs_threads** — Discussion threads within boards. Track `is_pinned` (dragon only), `is_locked` (dragon only), `last_post_at`, and `post_count`.
- **bbs_posts** — Individual posts within threads. Support edit tracking (`edited_at`, `edited_by_id`). Store `display_name` and `character_name` separately (allow character aliases in posts).
- **bbs_user_thread_stickies** — Per-user thread favorites. Unique constraint on (user_id, thread_id).
- **bbs_thread_read_marks** — Smart unread tracking. Store `last_read_post_id` (nullable, post may be deleted) and `last_read_at` (wall-clock time). Unique constraint on (user_id, thread_id).

### API Functions (Strangepaths.BBS)

**Boards**
- `list_boards()` — All boards with thread counts and last post times
- `get_board!(id)`, `get_board_by_slug!(slug)` — Board by id or slug
- `create_board(attrs)`, `change_board(board, attrs)` — Create and changeset

**Threads**
- `list_threads(board, user)` — Threads ordered: pinned, stickied (if user), then by last_post_at
- `list_threads_with_unread_counts(board, user)` — Same, with unread post counts per thread
- `get_thread!(id)` — Thread by id (preloaded with board)
- `create_thread(board, user, attrs)` — Create thread and first post (atomically)
- `change_thread(thread, attrs)` — Changeset for thread creation

**Posts**
- `list_posts(thread_id)` — Posts ordered by posted_at ascending
- `get_post!(id)` — Post by id
- `create_post(thread, user, attrs)` — Create post and update thread (atomically). Broadcasts "new_post" on `bbs_thread:{id}`.
- `update_post(post, editor, attrs)` — Edit post and mark edited_at/edited_by
- `delete_post(post)` — Delete post and decrement thread post_count
- `get_post_for_quote(post_id)` — Post with quote context (board slug, thread id, content)

**Stickies**
- `toggle_sticky(user_id, thread_id)` — Create or delete sticky
- `user_sticky_thread_ids(user_id)` — MapSet of thread ids stickied by user

**Dragon Moderation**
- `pin_thread(thread)`, `unpin_thread(thread)` — Toggle is_pinned
- `lock_thread(thread)`, `unlock_thread(thread)` — Toggle is_locked
- `delete_thread(thread)` — Delete thread (cascades to posts)

**Read Marks**
- `upsert_read_mark(user_id, thread_id)` — Mark all posts in thread as read (sets last_read_post_id to max)
- `advance_read_mark(user_id, thread_id, post_id, posted_at)` — Mark posts up to specific post as read (preserves unread count for newer posts)
- `get_read_mark(user_id, thread_id)` — Retrieve read mark or nil

### Design Notes

- Threads are created with the user's first post atomically (no empty threads).
- Posts include `display_name` and `character_name` to support IC character aliases without breaking post history if a user later changes their character.
- Read marks use `last_read_post_id` (nullable) for smart unread: unread = posts where `id > last_read_post_id`. If no read mark exists, all posts are unread.
- Unread counts calculated server-side via subquery; frontend receives precalculated counts.
- Dragon-only operations (pin, lock, delete) have no permission checks in the data layer — LiveView/Controller must enforce.
- Future LiveViews will use PubSub for real-time "new post" notifications (broadcast happens on `create_post`).

### Migrations

Five numbered migrations (20260413120001–20260413120005) in `priv/repo/migrations/`:

1. `20260413120001_create_bbs_boards.exs` — bbs_boards table
2. `20260413120002_create_bbs_threads.exs` — bbs_threads table with board_id FK
3. `20260413120003_create_bbs_posts.exs` — bbs_posts table with thread_id FK
4. `20260413120004_create_bbs_user_thread_stickies.exs` — bbs_user_thread_stickies table
5. `20260413120005_create_bbs_thread_read_marks.exs` — bbs_thread_read_marks table

All migrations use `:delete_all` for cascade deletes. Indexes created for query performance (board/pinned/last_post_at on threads; thread/posted_at on posts).

## BBS Forum System (Phase 2: Read-Only LiveViews)

### LiveView Modules

Three LiveViews in `lib/strangepaths_web/live/bbs/`:

1. **BBSLive.BoardList** (`board_list_live.ex` + `board_list.html.heex`)
   - Route: `/bbs` (`:index` action)
   - Displays all boards with thread counts and last activity time
   - **Dragon-only features:** "New Board" button toggles inline form
   - Form validation on `phx-change="validate_board"`, submit via `phx-create="create_board"`
   - Helper function `format_relative_time/1` for timestamps (displays "just now", "5m ago", "2h ago", etc.)

2. **BBSLive.ThreadList** (`thread_list_live.ex` + `thread_list.html.heex`)
   - Routes: `/bbs/:board_slug` (`:index`) and `/bbs/:board_slug/new` (`:new`)
   - Displays threads in a board with unread counts, pinned/stickied indicators
   - **Logged-in features:** "New Thread" button (Phase 3 form placeholder), sticky indicators
   - Thread rows show: pin icon (📌), sticky indicator (⭐), title, post count, author, last activity, unread badge (red if count > 0)
   - Handles `Ecto.NoResultsError` from missing board with redirect + flash

3. **BBSLive.Thread** (`thread_live.ex` + `thread.html.heex`)
   - Route: `/bbs/:board_slug/:thread_id` (`:show` action)
   - Displays single thread with all posts, one per container
   - **Authenticated features:** Marks thread as read on mount, subscribes to `bbs_thread:{id}` for real-time new posts
   - Posts include: display name (bold), character name (muted, if not dragon), timestamp, content (rendered via `render_post_content/1`)
   - **Unread divider:** Renders "── new replies ──" before first post newer than `last_read_post_id`
   - Post actions: "Copy link" button (JS copies anchor URL), "Quote" button (Phase 3 placeholder)
   - **handle_info** listens for `new_post` events, advances read mark, appends post to list, pushes JS scroll event
   - Handles `Ecto.NoResultsError` from missing thread with redirect + flash
   - Reply form placeholder for Phase 3 (shows "Reply form coming soon" if thread not locked)

### Key Patterns

- All LiveViews call `assign_defaults(session, socket)` from `StrangepathsWeb.LiveHelpers` to load current user
- Error handling uses `try/rescue` for `Ecto.NoResultsError`, redirects to previous page with flash
- Breadcrumbs use `live_redirect` helper for navigation
- Time formatting: `format_relative_time/1` in modules, or `Calendar.strftime/2` for detailed timestamps
- Post content rendered with `render_post_content/1` from `StrangepathsWeb.SceneHelpers` (handles glyphs + markdown)
- Dragon detection: check `@current_user && @current_user.role == :dragon`
- Locked threads show 🔒 icon; reply form hidden if locked or not logged in

## BBS Forum System (Phase 3: Posting, Quoting, Stickies)

### New Thread Form (ThreadList LiveView)

- **Location:** `/bbs/:board_slug/new` (`:new` action in `BBSLive.ThreadList`)
- **Fields:** `display_name` (text input, defaults to current_user.nickname), `title` (text input, required), `content` (textarea with glyph toolbar)
- **Glyph Toolbar:** Integrated via `Grimoire` hook (already in app.js), copied from scenes implementation
- **Event Handlers:**
  - `validate_thread` (phx-change) — Updates changeset assign for live validation
  - `create_thread` (phx-submit) — Calls `BBS.create_thread(board, user, attrs)`, redirects to thread view on success, shows flash on error
- **Form Logic:** Only shown if user logged in; clicking Cancel redirects back to thread list

### Reply Form (Thread LiveView)

- **Location:** `/bbs/:board_slug/:thread_id` (`:show` action in `BBSLive.Thread`)
- **Fields:** `display_name` (defaults to current_user.nickname), `content` (textarea with glyph toolbar)
- **Only shown if:** Thread not locked AND user logged in
- **Event Handlers:**
  - `validate_reply` (phx-change) — Updates changeset for live validation
  - `create_reply` (phx-submit) — Calls `BBS.create_post(thread, user, attrs)`, clears form on success, shows error on failure
- **Form Hook:** `BBSReplyForm` (in app.js) listens for `bbs-insert-quote` event to inject quote tags into textarea

### Quote Feature

#### Server-Side (thread_live.ex)

- **Event Handler:** `quote_post` (phx-click on Quote button)
  - Validates user is logged in
  - Calls `BBS.get_post_for_quote(post_id)` to retrieve post with context (board slug, thread id, content)
  - Truncates excerpt to 200 chars
  - Pushes `bbs-insert-quote` event to client with: post_id, author, thread_id, board, excerpt, same_thread flag

#### Client-Side (assets/js/app.js)

- **Hook:** `BBSReplyForm` (mounted on reply form)
  - Listens for `bbs-insert-quote` event
  - Inserts quote tag into textarea: `[quote id=N author="..." thread_id=M board="slug"]\nexcerpt\n[/quote]\n\n`
  - Positions cursor after quote, scrolls form into view
  - Also handles `bbs-reply-form-clear` event to reset textarea after successful post

#### Quote Rendering (bbs_helpers.ex)

- **Function:** `render_bbs_post_content(content, current_thread_id \\ nil)` in `StrangepathsWeb.BBSHelpers`
  - Processes `[quote ...]...[/quote]` blocks BEFORE markdown pass (via regex replacement)
  - HTML-escapes all user-provided values (author, board, excerpt) to prevent XSS
  - **Same-thread quotes:** Rendered as anchor links (`<a href="#post-N">`) with class `bbs-quote-same-thread`
  - **Cross-thread quotes:** Rendered as divs with popover data attributes, class `bbs-quote-cross-thread`
  - Passes processed content to `render_post_content/2` for markdown + glyph handling
  - Returns HTML safe for raw interpolation in templates

#### Quote Popovers (assets/js/app.js)

- **Hook:** `BBSQuotePopover` (mounted on posts container)
  - Finds all elements with `data-bbs-popover="true"` attribute
  - Initializes Tippy.js instances with content from data attributes
  - Supports click-triggered popovers with author, excerpt, and link to quoted post
  - Re-initializes on updates (mounted + updated hooks)

### Sticky Toggle Feature

- **Button:** Star icon (⭐ filled or ☆ empty) in thread rows, only visible if user logged in
- **Event Handler:** `toggle_sticky` in `BBSLive.ThreadList` (phx-click on star button)
  - Calls `BBS.toggle_sticky(user_id, thread_id)` to create or delete sticky record
  - Reloads thread rows via `BBS.list_threads_with_unread_counts/2` to reflect new state
  - If sticky exists, star shows filled (⭐); otherwise empty (☆)

### Helper Functions

**In Strangepaths.BBS context:**
- `change_post(post \\ %Post{}, attrs \\ %{})` — Returns changeset for post validation (used in reply form)

**In StrangepathsWeb.BBSHelpers module:**
- `render_bbs_post_content(content, current_thread_id)` — Renders post content with quote block processing and XSS protection
- `render_quote_block/6` (private) — Generates HTML for individual quote blocks

## BBS Forum System (Phase 4: Dragon Moderation)

### Moderation Features

- **Thread moderation:** Pin (dragon only), Lock (dragon only), Delete (dragon only)
- **Post moderation:** Edit (by author or dragon), Delete (by author or dragon)
- **Moderation buttons** appear in post/thread headers with reduced opacity (hover reveals)
- **Edit tracking:** Posts show "[edited by dragon]" timestamp marker if edited

## BBS Forum System (Phase 5: Aesthetic Polish)

### Styling Overview

The BBS uses a retro terminal aesthetic with monospace fonts and a dark purple/blue color scheme. All BBS-specific styles are in a dedicated SCSS block at the end of `assets/css/app.scss`.

### CSS Classes and Components

**Root & Layout:**
- `.bbs-root` — Applied to outermost wrapper. Sets monospace font, dark background (#0a0a0f), subtle scanline texture. All BBS pages get this class.

**Panels & Headers:**
- `.bbs-panel` — Dark panel with border (#0d0d1a background, #2a2a4a border)
- `.bbs-panel-header` — Panel header with uppercase text, purple color, letter-spacing
- `.bbs-npc-header` — Special style for ASCII art NPC header (preserves whitespace with `white-space: pre`)

**Thread Rows (ThreadList):**
- `.bbs-thread-row` — Base thread row with hover effect
- `.bbs-thread-row--pinned` — Left border in purple (#5050c0) for pinned threads
- `.bbs-thread-row--sticky` — Left border in green (#308030) for user-stickied threads
- `.bbs-pin-indicator` — Colored indicator text for pins (purple)
- `.bbs-sticky-indicator` — Colored indicator text for stickies (green)
- `.bbs-badge-new` — Badge for unread post count (blue background, outlined)

**Posts (Thread):**
- `.bbs-post` — Individual post container with bottom border
- `.bbs-byline` — Post header area (smaller font)
- `.bbs-display-name` — Poster's display name (bold, light purple #9090e0)
- `.bbs-character-name` — Character name (italic, muted purple #4a4a7a)
- `.bbs-timestamp` — Post timestamp (very dark purple #3a3a6a)
- `.bbs-edited-marker` — "[edited by dragon]" text marker
- `.bbs-post-content` — Post body with proper line-height and text color. Nested styles for `<p>`, `<code>`, and `<pre>` elements.
- `.bbs-unread-divider` — "── new replies ──" divider with subtle coloring

**Forms:**
- `.bbs-form` — Form container for creating threads or posting replies. Dark background, styled inputs/buttons with monospace font.

**Dragon Controls:**
- `.bbs-dragon-controls` — Container for moderation buttons. Set to low opacity (0.4) by default, visible on post hover or focus-within.

**Quote Blocks:**
- `.bbs-quote-block` — Container for quoted post excerpts. Dark background with left border, nested styles for header/excerpt.
- `.bbs-quote-cross-thread` — Variant for cross-thread quotes with hover effects and popover link.

**Breadcrumb:**
- `.bbs-breadcrumb` — Navigation breadcrumb styling with muted color and hover effects on links.

### CSS Variables

- `--bbs-font` — Single point of control for monospace font. Currently `"Courier New", "Lucida Console", monospace`. Update this variable to change BBS typography globally without touching individual classes.

### Tippy Theme

- `.tippy-box[data-theme~="bbs"]` — Custom Tippy popover theme for quote popovers, matching BBS colors and font.

### Design Rationale

- **Monospace throughout:** Reinforces retro/terminal aesthetic
- **Purple/blue color palette:** Mystical, tech-like feel matching Strangepaths lore (aethernet as magical network)
- **Scanlines:** Subtle background texture adds visual depth without distraction
- **Hover states:** Dragon controls hidden by default (non-intrusive), revealed on interaction
- **Indicator colors:** Pinned (purple) vs. sticky (green) creates clear visual distinction

### Notes for Future Work

- The `--bbs-font` CSS variable makes it trivial to swap fonts (e.g., to "IBM Plex Mono" or custom font) by editing a single line
- All classes use `.bbs-` prefix to avoid conflicts with Tailwind utilities
- Styling is self-contained in SCSS block; no Tailwind classes in BBS templates (except utility layout like `p-6`, `gap-2`)
- Dragon control opacity handled via CSS `:hover` pseudo-selector on parent post, not JavaScript

## Liminal Library

_Last updated: 2026-04-28_

A collaborative essay-and-curation system. Folios contain a long-form `body` (markdown + typeface tags) and an ordered `entries` collection mixing references to scene posts (`:post_ref`) with inline `:note` entries. Editors granted typefaces by a dragon can author. Readers can attach threaded `marginalia` to any entry.

### Schema Overview (lib/strangepaths/library/)

Five tables (migrations `20260427120001`–`20260427120006`):

- **library_user_typefaces** — `(user_id, typeface_id)` grants a user the right to write in a typeface. `typeface_id` is a string id from the hardcoded `Typefaces` master list, not an FK. Unique on `(user_id, typeface_id)`.
- **library_folios** — `title`, `slug` (auto from title), `subtitle`, `body` (markdown), and a body-edit mutex: `body_locked_by_id` (FK to user) and `body_locked_at` (utc_datetime). Unique on `title` and `slug`. `belongs_to :user` (author).
- **library_folio_tags** — `(folio_id, tag)` with unique constraint. Tags are lowercased and trimmed by the context (`add_tag/2`).
- **library_entries** — Polymorphic via `kind` enum (`:post_ref | :note`). Holds `position` (sortable, with unique index on `(folio_id, position)`), `group_id` (string, free-form group label), and for notes: `content`, `name`, `font`, `color`. `:post_ref` rows reference `library_entries.scene_post_id` → `scenes_posts.id`.
- **library_marginalia** — Threaded comments on entries. Self-referencing `parent_id` (`:id`, no FK constraint), with `content`, `name`, `font`, `color`. Depth is enforced in the context, not the schema.

### Typefaces (Strangepaths.Library.Typefaces)

The hardcoded master list of typefaces. Each typeface is `%{id, name, font, color}`. Current typefaces: `jorule`, `seraph`, `inkwell`, `lacuna`. Functions: `all/0`, `find/1`, `valid_id?/1`. New typefaces are added by editing this module — there is no dragon UI for creating typefaces, only assigning existing ones.

### Library Context API (Strangepaths.Library)

**User typefaces (dragon admin)**
- `assign_user_typeface(user_id, typeface_id)` — Idempotent insert via `on_conflict: :nothing`.
- `remove_user_typeface(user_id, typeface_id)` — Returns `{:error, :not_found}` if not assigned (intentionally non-idempotent to surface admin UI errors).
- `list_user_typefaces(user_id)` — Returns list of typeface ids granted to the user.
- `folio_editor?(user_id)` — True if the user has any typeface assigned.
- `folio_editor_typefaces(user_id)` — Returns typeface structs (with name/font/color) the user is allowed to write in.

**Folios**
- `list_folios/0`, `list_folio_authors/0` — Folio list and the distinct list of users who have authored at least one folio.
- `search_folios(opts)` — Search/filter/sort. Options: `:query` (ILIKE on title/subtitle/body), `:author_id`, `:tag` (subquery against `library_folio_tags`), `:sort_by` (`:date | :title | :author`). Subquery used for tag filter so sort ordering survives.
- `get_folio!/1`, `get_folio_by_slug!/1`, `get_folio_by_slug/1` (nil-safe, preloads `:user`).
- `create_folio(user, attrs)`, `update_folio_title(folio, attrs)`, `delete_folio/1`, `change_folio/2`.

**Body mutex (single-writer locking)**
- `lock_timeout_seconds/0` — Returns 300 (5 minutes). Used by both context and the LiveView's `Process.send_after`.
- `claim_body_lock(folio_id, user_id)` — Atomic `update_all` claims the lock if unclaimed, stale (older than `lock_timeout_seconds`), or already held by the same user (allows re-entrant claim). Returns `:ok` or `{:error, :locked}`.
- `release_body_lock(folio_id)` — Unconditional release.
- `save_body(folio, user_id, content)` — Atomic save+release. Verifies caller holds the lock; returns `:ok` or `{:error, :lock_lost}`. Uses `NaiveDateTime` for `updated_at` to match `timestamps()` schema type.
- `get_folio_lock_info(folio_id)` — Returns `%{locked_by_id, locked_at}` for inspection.

**Tags**
- `list_tags(folio_id)`, `list_folio_tags(folio_id)` — Tag strings ordered alphabetically.
- `add_tag(folio, tag)` — Lowercases/trims, idempotent via `on_conflict: :nothing`.
- `remove_tag(folio, tag)` — Idempotent: returns `{:ok, nil}` if tag absent (suitable for click-toggle UI).

**Entries**
- `list_entries(folio_id)` — Ordered by `position`, preloads `[scene_post: [:user]]`.
- `create_post_entry(folio, user, scene_post_id, position \\ nil)` — Inserts a `:post_ref` entry. If `position` falls inside the existing range, all entries `>= position` are shifted using a two-step transactional update via temporary negative positions (avoids violating the unique `(folio_id, position)` index).
- `create_note_entry(folio, user, attrs, position \\ nil)` — Same shift behavior. Note attrs require `content`, `name`, `font`, `color`. `font` must be in the Typefaces master list; `color` must match `~r/\A#[0-9a-fA-F]{3,8}\z/` (CSS-injection guard).
- `delete_entry(entry)`, `update_note_entry(entry, attrs)`, `update_entry_group(entry, group_id)`.
- `reorder_entries(folio_id, ordered_ids)` — Transactional rewrite of positions using temporary negative positions then final positive positions. Returns `:ok` on success.
- Known limitation: `next_entry_position/1` (private) has a documented race for concurrent inserts; acceptable while editing is effectively single-user via the body mutex (entries are not gated by the mutex but contention is low).

**Marginalia**
- `list_marginalia(entry_id)`, `list_all_marginalia_for_folio(folio_id)` — Both preload `:user` and order by `inserted_at`.
- `create_marginalia(entry, user, attrs)` — Validates parent (if any) belongs to the same entry, enforces `@max_marginalia_depth = 3` by walking up `parent_id`, and broadcasts `"new_marginalia"` on `library_folio:{folio_id}` PubSub topic with the preloaded marginalia and `entry_id`. Returns `{:error, :max_depth_exceeded}` when depth limit is hit. The depth walk does up to 3 `Repo.get/1` calls per insert (bounded N+1).

### Web Layer

**LiveViews** (`lib/strangepaths_web/live/library/`):

- `LibraryLive.FolioList` — Routes `/library` (`:index`) and `/library/new` (`:new`). Browse, search, author filter, tag filter, sort. Inline new-folio form (folio editors only). Author list filters to active authors via `list_folio_authors/0`.
- `LibraryLive.Folio` — Route `/library/:slug` (`:show`). Renders the body essay, the ordered entry list (with marginalia threads), tag UI, and inline title/body editors. Mounts subscribe to `library_folio:{folio.id}` PubSub for real-time `new_marginalia` events. `terminate/2` releases the body lock if still held. The body editor is gated on `folio_editor?(user_id)`; title/delete are gated on `is_author || is_dragon` (delete is dragon-only).
- `LibraryLive.Composer` — Route `/library/:slug/compose` (`:compose`). Folio-editor-only. Browses scenes (active + archived), drag-to-reorder via `Sortable.js`, shift-click range select on scene posts, caret-positioned insertion, group labels, and inline note creation. Fetches scenes via `Scenes.list_scenes_for_composer/0` and `Scenes.list_scenes_with_user_posts/1`.
- `LibraryLive.Admin` — Route `/library/admin`. Dragon-only. Toggles user-typeface assignments via `assign_user_typeface/2` and `remove_user_typeface/2`.

**Templates** are in `*.html.heex` siblings to the LiveView modules.

**Helpers:**

- `StrangepathsWeb.LibraryHelpers.render_library_content(content, opts \\ [])` — Renders typeface-tagged content. Two-pass strategy: (1) `extract_typeface_tokens/1` replaces `[name]text[/name]` matches with private-use-area sentinel tokens (`U+E000 LLITOK{n} LLITOK`) so Earmark cannot interfere; (2) `render_post_content/2` (from `SceneHelpers`) handles markdown + glyphs; (3) `restore_typeface_tokens/2` swaps tokens back, HTML-escaping the inner text and emitting `<span style="font-family: …; color: …">…</span>`. The trailing `LLITOK` sentinel prevents prefix collisions when there are 11+ tags (otherwise `LLITOK1` is a prefix of `LLITOK10`). Unknown typeface names render as literal `[name]…[/name]`. Imported globally via `StrangepathsWeb.view_helpers/0` to match BBS/Scene helper convention.

**JavaScript hooks** (`assets/js/app.js`):

- `LibraryBodyEditor` — Auto-grow textarea + push `update_preview` events for live markdown preview.
- `LibraryComposer` — Sortable.js drag-to-reorder (with destroy-on-update to avoid memory leaks), shift-click range selection on scene posts (handler attached to the hook's element scope to avoid document-level leaks), and emits reorder events to the server.

### Routing

```
live("/library", LibraryLive.FolioList, :index)
live("/library/new", LibraryLive.FolioList, :new)
live("/library/admin", LibraryLive.Admin)
live("/library/:slug/compose", LibraryLive.Composer, :compose)
live("/library/:slug", LibraryLive.Folio, :show)
```

### Cross-Context Additions

- **Scenes context** gained `list_scenes_for_composer/0` and `list_scenes_with_user_posts/1` to support the composer's scene browser.
- **Web layer** (`strangepaths_web.ex`) added a global `import StrangepathsWeb.LibraryHelpers` so templates can call `render_library_content/1` directly.
- **LiveHelpers.format_relative_time/1** now accepts `NaiveDateTime` (converted to UTC `DateTime` for diffing).

### Invariants and Security

- **CSS injection guard:** Both `Entry.note_changeset` and `Marginalia.create_changeset` validate `color` against a hex regex and `font` against the Typefaces master list before allowing the value into a `style="…"` attribute.
- **XSS guard in typefaces:** `render_library_content/1` HTML-escapes the inner text of each typeface tag; `font` and `color` come from the trusted `Typefaces` module, never from user input.
- **Body editing is single-writer:** The mutex is enforced at the DB level via `update_all` with conditional `WHERE`, not at the LiveView level. The 5-minute timeout is enforced both server-side (`Process.send_after`) and DB-side (stale-lock claim).
- **Dragon-only ops** (delete folio, assign/revoke typefaces): permission checks live in the LiveView. The data layer has no permission checks.
- **Marginalia depth limit:** `@max_marginalia_depth = 3`. Returns `{:error, :max_depth_exceeded}` rather than raising.
- **Tag normalization:** Tags are always lowercased and trimmed before insert and before lookup.
- **Real-time delivery:** `create_marginalia/3` broadcasts on `library_folio:{folio_id}`; `LibraryLive.Folio` deduplicates by id when receiving broadcasts.

### Library SCSS

Library styles live in a dedicated block at the end of `assets/css/app.scss`. Class prefix is `.library-`. Key components include `.library-folio`, `.library-entry`, `.library-marginalia`, `.library-typeface-tag`, and search/filter form classes. Templates use these semantic classes (no Tailwind utilities mixed into the library templates beyond layout).
