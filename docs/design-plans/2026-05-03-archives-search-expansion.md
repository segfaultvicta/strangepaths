# Design Plan: Archives Search Expansion

**Date:** 2026-05-03  
**Status:** Validated  
**Scope:** Expand the `/scenes/archives` search to cover Liminal Library folios (body, inline notes, marginalia) and Aethernet BBS (threads, posts).

---

## Background

The Archives search at `/scenes/archives` currently searches three content types:

1. **Archived scenes** — by name and tags (`Scenes.search_archived_scenes/6`)
2. **Posts within archived scenes** — IC/OOC content with ILIKE + pg_trgm fuzzy matching (`Scenes.search_archived_posts/6`)
3. **Codex pages** — title and body with ILIKE + pg_trgm fuzzy matching (`Site.search_codex_pages/2`)

Results are grouped by parent entity (scenes with nested post snippets; codex pages listed individually). The existing Library FolioList search (`Library.search_folios/1`) and scene browser search are **not changed**.

---

## New Context Functions

### `Library.search_folios_for_archives(query, user_id)`

A new function in `lib/strangepaths/library.ex` — distinct from the existing `search_folios/1` used by FolioList.

**Searches:**
- `library_folios.body`
- `library_entries.content` (kind = `:note` only — post_ref entries have no text)
- `library_marginalia.content`

**Matching strategy:** ILIKE substring + pg_trgm similarity (threshold ~0.15), matching the pattern used by `search_archived_posts/6`.

**Grouping:** All matches (body, note, or marginalia) bubble up to a single folio result card. Up to 3 snippets per folio, 150 chars each with ellipsis truncation.

**Return shape:**
```elixir
[
  %{
    folio_id: id,
    folio_slug: slug,
    folio_title: title,
    snippets: [
      %{snippet: "…text…", source: :body | :note | :marginalia}
    ]
  }
]
```

**Access filtering:** None — folios are read-public.

---

### `BBS.search_threads_for_archives(query, user_id)`

A new function in `lib/strangepaths/bbs.ex`.

**Searches:**
- `bbs_threads.title`
- `bbs_posts.content`

**Matching strategy:** Same ILIKE + pg_trgm pattern.

**Grouping:** Matching posts grouped under their thread. Up to 3 snippets per thread, 150 chars each.

**Return shape:**
```elixir
[
  %{
    thread_id: id,
    board_slug: slug,
    thread_title: title,
    snippets: [
      %{post_id: id, snippet: "…text…", author: name, posted_at: datetime}
    ]
  }
]
```

**Access filtering:** None — BBS posts are read-public.

---

## Archives LiveView Changes (`archives.ex`)

### Socket assigns

Add two new initial assigns alongside existing empty lists:

```elixir
|> assign(:library_results, [])
|> assign(:bbs_results, [])
```

### `"search"` event handler

Two new calls appended at the end of the existing search block:

```elixir
library_results = Library.search_folios_for_archives(query, user_id)
bbs_results     = BBS.search_threads_for_archives(query, user_id)
```

Assigned to socket alongside existing results. The existing filters (`my_scenes_filter`, `hide_elsewhere_filter`, `author_filter`) are **not applied** to Library or BBS results — they're scene-specific.

---

## Template Changes (`archives.html.heex`)

Two new result sections appended after the existing Scenes section, following the identical visual pattern.

### "Liminal Library" section

- Conditional on `length(@library_results) > 0`
- Heading: "Liminal Library" with result count
- Each result: folio title as link to `/library/:slug`
- Snippet rows labeled by source: "body", "note", or "marginalia"
- Snippet text highlighted with search query (same yellow highlight already used)

### "Aethernet BBS" section

- Conditional on `length(@bbs_results) > 0`
- Heading: "Aethernet BBS" with result count
- Each result: thread title as link to `/bbs/:board_slug/:thread_id`, with board name as breadcrumb
- Snippet rows: excerpt text, author name, date, anchor link to `#post-{post_id}`

---

## What Is Not Changed

- `Library.search_folios/1` — FolioList search is untouched
- Scene browser search — untouched
- Existing Archives filters (my scenes, hide elsewhere, hide system, author filter) — unchanged, still apply only to scene/post results
- Routes — no new routes needed
