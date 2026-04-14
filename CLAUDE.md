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

### Not Implemented Yet (Phases 3+)

- Posting/reply forms (Phase 3)
- Quote functionality (Phase 3)
- Glyph toolbar for posts (Phase 3)
- Dragon moderation controls: pin/lock/delete threads (Phase 4)
- CSS/SCSS styling refinement (Phase 5)
