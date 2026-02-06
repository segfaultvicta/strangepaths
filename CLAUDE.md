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
