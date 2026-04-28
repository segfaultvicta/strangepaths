# Liminal Library — Test Requirements

**Feature:** Liminal Library  
**Design plan:** `docs/design-plans/2026-04-27-liminal-library.md`  
**Implementation plan:** `docs/implementation-plans/2026-04-27-liminal-library/`

This document maps every Acceptance Criterion to the automated tests that verify it and provides manual verification steps for criteria that are partially or fully UI-driven.

---

## Automated Test Coverage

### AC1: Dragon manages typeface assignment

| Criterion | Test file | Test name / description |
|-----------|-----------|------------------------|
| AC1.1 Dragon views admin page | `test/strangepaths_web/live/library/admin_live_test.exs` | "dragon can view the admin page" |
| AC1.2 Dragon assigns typefaces | `test/strangepaths_web/live/library/admin_live_test.exs` | "dragon can assign a typeface to a user", "dragon can assign typeface to themselves" |
| AC1.3 Dragon revokes typeface | `test/strangepaths_web/live/library/admin_live_test.exs` | "dragon can revoke a typeface from a user" |
| AC1.4 User with typeface can create folios | `test/strangepaths/library_test.exs` | "folio editor can create a folio" |
| AC1.5 User without typeface cannot create | `test/strangepaths/library_test.exs` | "non-folio-editor cannot create folio" |
| AC1.6 User without typeface cannot add marginalia | `test/strangepaths/library_test.exs` | "non-folio-editor cannot create marginalia" |

### AC2: Folio creation

| Criterion | Test file | Test name / description |
|-----------|-----------|------------------------|
| AC2.1 Editor creates folio | `test/strangepaths/library_test.exs` | "folio editor can create a folio with title and subtitle" |
| AC2.2 Slug auto-generated | `test/strangepaths/library_test.exs` | "slug is generated from title" |
| AC2.3 Duplicate title fails | `test/strangepaths/library_test.exs` | "duplicate title returns changeset error" |
| AC2.4 Body-only folio valid | `test/strangepaths/library_test.exs` | "folio with body only is valid" |
| AC2.5 Entries-only folio valid | `test/strangepaths/library_test.exs` | "folio with entries only is valid" |
| AC2.6 Non-editor cannot create | `test/strangepaths_web/live/library/folio_list_live_test.exs` | "non-folio-editor is redirected from folio creation" |

### AC3: Body editor with mutex and live preview

| Criterion | Test file | Test name / description |
|-----------|-----------|------------------------|
| AC3.1 Any editor can open body editor | `test/strangepaths_web/live/library/folio_live_test.exs` | "folio editor can open body editor and save" |
| AC3.2 Mutex blocks second editor | `test/strangepaths/library_test.exs` | "claim_body_lock returns :ok for first claimant, :error for second" |
| AC3.3 Mutex releases on save/cancel/timeout | `test/strangepaths/library_test.exs` | "release_body_lock clears lock fields", "save_body clears lock on success" |
| AC3.4 Known typeface tag renders as span | `test/strangepaths_web/library_helpers_test.exs` | "renders known typeface tag as styled span" |
| AC3.5 Unknown typeface tag renders literal | `test/strangepaths_web/library_helpers_test.exs` | "renders unknown typeface name as literal text with brackets" |
| AC3.6 Glyph pairs render correctly | `test/strangepaths_web/library_helpers_test.exs` | "glyph pairs in content still render correctly" |
| AC3.7 Live preview updates on change | `test/strangepaths_web/live/library/folio_live_test.exs` | "preview updates when body textarea changes" |

### AC4: Post collection composer

| Criterion | Test file | Test name / description |
|-----------|-----------|------------------------|
| AC4.1 Scene browser shows all scenes | `test/strangepaths_web/live/library/composer_live_test.exs` | "scene browser lists all non-elsewhere scenes" |
| AC4.2 Filter narrows scenes; full-cast always shows | `test/strangepaths_web/live/library/composer_live_test.exs` | "filter hides non-matching scenes", "full cast session scene always appears" |
| AC4.3 Full-cast scene has distinct background | `test/strangepaths_web/live/library/composer_live_test.exs` | "full cast session scene renders with distinct background class" |
| AC4.4 "Scenes I was in" toggle | `test/strangepaths_web/live/library/composer_live_test.exs` | "my_scenes_only toggle filters to user's scenes" |
| AC4.5 Click post adds at caret | `test/strangepaths_web/live/library/composer_live_test.exs` | "clicking a post adds entry at caret position" |
| AC4.6 Shift-click range selection | `test/strangepaths_web/live/library/composer_live_test.exs` | "shift_select_post adds contiguous range of posts" |
| AC4.7 Drag-to-reorder (server side) | `test/strangepaths_web/live/library/composer_live_test.exs` | "reorder_entries event updates entry positions" |
| AC4.8 Inline note insertion | `test/strangepaths_web/live/library/composer_live_test.exs` | "add_note inserts a note entry at caret" |
| AC4.9 Caret persists between additions | `test/strangepaths_web/live/library/composer_live_test.exs` | "caret position advances after adding entry and persists" |

### AC5: Entry permissions

| Criterion | Test file | Test name / description |
|-----------|-----------|------------------------|
| AC5.1 Any editor can add entries | `test/strangepaths_web/live/library/composer_live_test.exs` | "non-author folio editor can add a post entry" |
| AC5.2 Author/dragon can reorder and delete | `test/strangepaths_web/live/library/composer_live_test.exs` | "author can delete an entry", "dragon can delete an entry they did not create" |
| AC5.3 Non-author editor cannot modify | `test/strangepaths_web/live/library/composer_live_test.exs` | "non-author editor receives error on delete attempt" |

### AC6: Marginalia

| Criterion | Test file | Test name / description |
|-----------|-----------|------------------------|
| AC6.1 Any editor can add marginalia | `test/strangepaths_web/live/library/folio_live_test.exs` | "folio editor can submit marginalia on any entry" |
| AC6.2 Multi-typeface dropdown | `test/strangepaths_web/live/library/folio_live_test.exs` | "user with two typefaces sees typeface dropdown on marginalia form" |
| AC6.3 Marginalia render in stored typeface | `test/strangepaths_web/live/library/folio_live_test.exs` | "marginalia rendered with stored font and color" |
| AC6.4 Threads collapsed by default | `test/strangepaths_web/live/library/folio_live_test.exs` | "marginalia thread is collapsed on page load, count badge shows N" |
| AC6.5 Expanding thread shows indented replies | `test/strangepaths_web/live/library/folio_live_test.exs` | "toggle_marginalia_thread expands thread with replies indented" |
| AC6.6 Real-time delivery | `test/strangepaths_web/live/library/folio_live_test.exs` | "new marginalia appear without page reload (PubSub broadcast)" |
| AC6.7 Non-editor cannot add marginalia | `test/strangepaths_web/live/library/folio_live_test.exs` | "non-folio-editor sees no marginalia form" |

### AC7: Browse and search

| Criterion | Test file | Test name / description |
|-----------|-----------|------------------------|
| AC7.1 Search matches title/subtitle/body/tags | `test/strangepaths/library_test.exs` | "filters by title match", "filters by subtitle match", "filters by body match", "filters by tag" |
| AC7.2 Results never include scenes | `test/strangepaths/library_test.exs` | "results contain only Folio structs, not scenes or other types" |
| AC7.3 Filter by author and tag, sort options | `test/strangepaths/library_test.exs` | "filters by author_id", "sort_by :title returns alphabetically", "sort_by :author" |
| AC7.4 Scenes archive search unchanged | `test/strangepaths/library_test.exs` | "Scenes archive search returns same results after library feature exists" |

### AC8: Tags and deletion

| Criterion | Test file | Test name / description |
|-----------|-----------|------------------------|
| AC8.1 Editor can add/remove tags; lowercase; dedup | `test/strangepaths_web/live/library/folio_live_test.exs` | "folio editor can add a tag", "tag is stored lowercased", "duplicate add is a no-op", "folio editor can remove a tag" |
| AC8.2 Non-editor cannot add/remove | `test/strangepaths_web/live/library/folio_live_test.exs` | "non-folio-editor sees no add/remove tag UI" |
| AC8.3 Dragon can delete any folio | `test/strangepaths_web/live/library/folio_live_test.exs` | "dragon can delete a folio they did not create" |
| AC8.4 Non-dragon cannot delete | `test/strangepaths_web/live/library/folio_live_test.exs` | "non-dragon user cannot delete folio" |

---

## Manual Verification Checklist

These items require a running development server. Run `mix phx.server` and verify in a browser at `https://localhost:4001`.

### Setup
- [ ] Run `mix ecto.migrate` to apply all 5 library migrations
- [ ] Seed at least 2 users (one dragon, one regular) with the dev seed data or via IEx

### AC1: Typeface assignment
- [ ] Log in as dragon, visit `/library/admin`
- [ ] Confirm user list appears with typeface columns as checkboxes (or toggle buttons)
- [ ] Assign a typeface to a non-dragon user — confirm the checkbox/button reflects the assignment
- [ ] Revoke the assignment — confirm it clears
- [ ] Log in as the non-dragon user, confirm `/library` shows the "New Folio" button
- [ ] Log in as a user with no typeface, confirm `/library` hides the "New Folio" button

### AC2: Folio creation
- [ ] As a folio editor, click "New Folio" on `/library`
- [ ] Enter a title and submit — confirm redirect to `/library/:slug`
- [ ] Confirm the slug in the URL matches the title (lowercased, hyphenated)
- [ ] Submit again with the same title — confirm validation error appears inline
- [ ] Create a folio with only a body (no entries via composer) — confirm it's viewable
- [ ] Create a folio with only entries (empty body) — confirm it's viewable

### AC3: Body editor
- [ ] On a folio view page, click "Edit body" — confirm the editor appears
- [ ] In a second browser window (different user, both folio editors), try to open the same body editor — confirm a "locked by [name]" message and no edit form
- [ ] In the first window, type in the textarea — confirm the preview pane updates after ~300ms
- [ ] Insert a `[typeface_name]styled text[/typeface_name]` tag — confirm preview shows styled span
- [ ] Insert an unknown tag like `[fakeface]text[/fakeface]` — confirm preview shows `[fakeface]text[/fakeface]` literally
- [ ] Insert a glyph pair (e.g., `{⚗}content{⚗}`) — confirm preview renders glyph span
- [ ] Save the body — confirm the editor closes and the body renders on the folio view
- [ ] Cancel the edit — confirm lock releases and the second window can now claim it
- [ ] Open the editor and leave it idle for 5+ minutes — confirm inactivity timeout releases the lock

### AC4: Post collection composer
- [ ] Visit `/library/:slug/compose` as a folio editor
- [ ] Confirm left panel shows all scenes with tag badges
- [ ] Type in the filter field — confirm non-matching scenes disappear
- [ ] If a scene tagged `#full cast session` exists, confirm it stays visible regardless of filter
- [ ] Toggle "Scenes I was in" — confirm only scenes you have posts in appear
- [ ] Click a post in a scene — confirm it appears in the right panel at the caret position
- [ ] Shift-click another post in the same scene — confirm all posts between the two selections are added
- [ ] Drag an entry in the right panel — confirm it reorders
- [ ] If multiple entries share a `group_id` (created together), confirm they move as a unit when dragged
- [ ] Click the "+" between two entries to place the insertion caret there, then click another post — confirm it inserts at that position
- [ ] Click "Add note" — confirm a note entry appears and its content is editable

### AC5: Entry permissions
- [ ] Log in as a folio editor who is NOT the folio author
- [ ] Confirm you can add entries via the composer (the add-post button works)
- [ ] Confirm the delete/reorder/edit controls on existing entries are either hidden or disabled
- [ ] Log in as the folio author — confirm delete/reorder/edit controls are visible and functional

### AC6: Marginalia
- [ ] On a folio view page, expand a marginalia thread (click the toggle)
- [ ] Confirm the thread is collapsed by default and shows a count badge
- [ ] As a folio editor, click "Reply" and submit a marginalia comment
- [ ] Confirm it appears immediately without page reload
- [ ] In a second browser tab, confirm the new marginalia appears in real-time
- [ ] Confirm the marginalia text renders in the correct typeface font and color
- [ ] Reply to an existing marginalia — confirm the reply is indented below its parent
- [ ] Log in as a user with no typeface — confirm no "Reply" button appears

### AC7: Browse and search
- [ ] Visit `/library` and type a word from a folio title in the search box
- [ ] Confirm matching folios appear and non-matching folios disappear after ~300ms debounce
- [ ] Type a word that only appears in a folio's body text — confirm it still matches
- [ ] Filter by a tag — confirm only folios with that tag appear
- [ ] Filter by author — confirm only that author's folios appear
- [ ] Change sort to "Title" — confirm alphabetical ordering
- [ ] Visit `/scenes/archive` and confirm scene search still works correctly

### AC8: Tags and deletion
- [ ] On a folio view page (as folio editor), type a tag in the add-tag input and submit
- [ ] Confirm tag appears as a badge
- [ ] Type the same tag again — confirm no duplicate appears
- [ ] Type a tag with uppercase — confirm it's stored and displayed in lowercase
- [ ] Click "×" on a tag — confirm it disappears
- [ ] Log out and view the folio — confirm tags are visible but no add/remove controls appear
- [ ] Log in as dragon, visit any folio, confirm "Delete Folio" button is visible and works
- [ ] Log in as non-dragon folio editor — confirm no "Delete Folio" button appears

---

## XSS / Security Verification

These are manual spot-checks for security-sensitive paths:

- [ ] **Body XSS**: Submit a body containing `<script>alert('xss')</script>` inside a typeface tag: `[jorule]<script>alert('xss')</script>[/jorule]`. Confirm no alert fires; confirm `&lt;script&gt;` appears in the rendered span.
- [ ] **Tag XSS**: Submit a tag value of `"><script>alert(1)</script>`. Confirm it is displayed safely (HTML-escaped) in the tag badge.
- [ ] **Marginalia XSS**: Submit marginalia content containing `<img src=x onerror=alert(1)>`. Confirm no alert fires.
- [ ] **Admin authorization**: Attempt to access `/library/admin` while logged in as a non-dragon user. Confirm redirect to `/` with error flash.

---

## Regression Verification

After all phases are complete, verify these existing features are unaffected:

- [ ] Scene posting, quoting, and content rendering work as before
- [ ] BBS threads and posts render and function correctly
- [ ] `/scenes/archive` search returns correct results (AC7.4)
- [ ] Music player and rumor map are unaffected
- [ ] Dragon admin panels at `/avatars/admin` and `/content/admin` still work
