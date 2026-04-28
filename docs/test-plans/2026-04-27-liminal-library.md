# Human Test Plan: Liminal Library

Generated from implementation plan `docs/implementation-plans/2026-04-27-liminal-library/`.
All 36 acceptance criteria (AC1–AC8) pass automated tests as of `a05b285`.

## Prerequisites

- Database accessible: `PGPASSWORD=1zc3edg5 mix ecto.migrate` (or environment-set)
- Seed at least: 1 dragon user, 1 typeface-granted user, 1 typeface-less user
- Confirm at least 2 active scenes with posts from each user, and 1 archived scene
- `PGPASSWORD=1zc3edg5 mix test` exits with 0 failures
- Start: `mix phx.server`; open `https://localhost:4001`

---

## Phase 1: Typeface Admin (`/library/admin`)

| Step | Action | Expected |
|------|--------|----------|
| 1 | Log in as the dragon user; navigate to `/library/admin` | Page renders with title "Library Admin" and "Typeface Assignments"; users listed with toggle buttons per typeface |
| 2 | Click the `jorule` toggle for a typeface-less user | Button visually flips on; in IEx confirm `Strangepaths.Library.folio_editor?(user.id) == true` |
| 3 | Click the same `jorule` toggle again | Button flips off; `folio_editor?` is false |
| 4 | Log out, attempt to GET `/library/admin` | Redirected to `/` with flash |
| 5 | Log in as a non-dragon user; GET `/library/admin` | Redirected to `/` with flash |

---

## Phase 2: Folio Creation (`/library`, `/library/new`)

| Step | Action | Expected |
|------|--------|----------|
| 1 | As editor user, visit `/library` | "New Folio" button appears in header |
| 2 | As typeface-less user, visit `/library` | "New Folio" button absent |
| 3 | As editor, click "New Folio"; submit `Title: "Test Folio Alpha"`, `Subtitle: "Phase 1"` | Redirect to `/library/test-folio-alpha`; folio renders with title and subtitle |
| 4 | Visit `/library/new` again; submit duplicate title `"Test Folio Alpha"` | Inline error "has already been taken" |
| 5 | Create folio `"Body Only Folio"`, edit body to "Some prose"; save | Visiting `/library/body-only-folio` shows the prose |
| 6 | Create folio `"Empty Title Test"`, leave subtitle/body empty | Folio renders without crashes |

---

## Phase 3: Body Editor & Live Preview (`/library/:slug`)

| Step | Action | Expected |
|------|--------|----------|
| 1 | As editor (author), open the folio; click "Edit body" button | Editor textarea + preview pane appear; "Save Body" and "Cancel" visible |
| 2 | Type `**hello**` in the textarea | Preview pane shows bolded "hello" within ~300ms |
| 3 | Type `[jorule]styled[/jorule]` | Preview shows a span with the jorule font and color (styled visually distinct) |
| 4 | Type `[fakeface]text[/fakeface]` | Preview renders the literal text including brackets, with no styling |
| 5 | Type `{⚗}burning{⚗}` | Preview renders "burning" with the burning-gnosis glyph styling |
| 6 | Type `[jorule]<script>alert(1)</script>[/jorule]` | No alert fires; rendered text shows `&lt;script&gt;` (escaped) |
| 7 | In a second browser/profile (logged in as a different editor), open same folio; click "Edit body" | Sees "Another editor is editing the body" message; no edit form |
| 8 | In window 1, click "Save Body" | Editor closes; folio body shows new content; window 2 can now claim the lock |
| 9 | Reopen body editor in window 1; click "Cancel" | Editor closes; lock released (verify in IEx: `Library.get_folio_lock_info(folio_id).locked_by_id == nil`) |
| 10 | Open body editor; leave idle 5+ minutes (do not type) | Lock auto-releases after timeout; second user can claim |

---

## Phase 4: Composer (`/library/:slug/compose`)

| Step | Action | Expected |
|------|--------|----------|
| 1 | As editor (author), visit `/library/test-folio-alpha/compose` | Two-pane layout: scene browser left, entry list right; "Caret at position 1" |
| 2 | Tag a scene as `full cast session` via IEx: `Strangepaths.Scenes.add_tag_to_scene(scene, "full cast session")` | Reload composer; that scene row has emerald background |
| 3 | In filter input, type `zzznomatch` | All scenes hidden EXCEPT the full-cast-session scene (which stays) |
| 4 | Clear filter; toggle "Scenes I was in" checkbox | Only scenes with at least one post by you visible (full-cast still appears even if you didn't post) |
| 5 | Click an unexpanded scene row | Scene expands inline showing its posts |
| 6 | Click a single post in the expanded scene | Post entry inserted at caret; caret advances to next slot |
| 7 | Click "↑ From" on a post; shift-click another post 2-3 down in same scene | All posts in the range inserted as `:post_ref` entries in order |
| 8 | Drag an entry up or down in the right panel | Entry order updates server-side (refresh confirms) |
| 9 | Click between two existing entries (caret slot) → click "Add inline note" → submit `"This is my note"` | New `:note` entry inserted at that position; caret advances |
| 10 | Click ✕ on an entry you authored | Entry deleted |
| 11 | Log out; log in as a different folio editor (not the author); reopen composer | No ✕ buttons visible on existing entries; you CAN still add new entries |
| 12 | Try to navigate to `/library/test-folio-alpha/compose` as a non-folio-editor | Redirected to `/library/test-folio-alpha` |

---

## Phase 5: Marginalia (`/library/:slug`)

| Step | Action | Expected |
|------|--------|----------|
| 1 | View a folio with at least one entry; observe marginalia threads | Threads collapsed by default with "N marginalia" badge |
| 2 | Click the toggle button to expand a thread | Marginalia content appears |
| 3 | As folio editor, click "Annotate" → submit content "First annotation" | Annotation appears immediately at depth 0 (no indentation) |
| 4 | Click "Reply" on that annotation; submit "Nested reply" | Reply appears indented (16px margin-left) |
| 5 | Reply to that reply (depth 2); submit | New reply at 32px margin-left |
| 6 | Try to reply to a depth-3 reply | Form rejects with "Maximum reply depth reached" or similar |
| 7 | If user has 2+ typefaces, observe marginalia form | Typeface dropdown appears with both options |
| 8 | Submit marginalia using the second typeface | Comment renders in the chosen typeface's font and color |
| 9 | Open the same folio in a second browser tab; in tab 1, submit a new marginalia | Tab 2 shows the new comment in real-time without reload |
| 10 | Log in as typeface-less user; view folio | No "Annotate" buttons visible |

---

## Phase 6: Tags & Deletion

| Step | Action | Expected |
|------|--------|----------|
| 1 | As editor (author), open folio; in tag input type `mythology` and submit | Tag badge appears; input clears |
| 2 | Type `MYTHOLOGY` (uppercase) and submit | No new badge added; tag list unchanged |
| 3 | Type `  RITES  ` (whitespace-padded) and submit | New "rites" badge (lowercase, trimmed) |
| 4 | Click the "×" on the "rites" badge | Tag disappears |
| 5 | Log out; view the same folio | Tag badges visible but no input or "×" buttons |
| 6 | Log in as a non-author folio editor; view this folio | Tag input and remove buttons absent |
| 7 | Log in as dragon; view the folio | "Delete Folio" button appears |
| 8 | Click "Delete Folio" | Redirect to `/library`; folio no longer in list |
| 9 | Log in as non-dragon folio editor (author); view a folio they wrote | "Delete Folio" button absent |

---

## Phase 7: Browse, Search & Sorting (`/library`)

| Step | Action | Expected |
|------|--------|----------|
| 1 | Visit `/library` with multiple folios seeded | Folios listed; filter inputs visible |
| 2 | In the search box, type a unique word from a folio title | After ~300ms debounce, only matching folios remain |
| 3 | Search for a unique word found only in a folio body | That folio appears in results |
| 4 | Select an author from the author dropdown | Only that author's folios remain |
| 5 | Click a tag badge under "Tags" | Only folios with that tag remain |
| 6 | Change sort to "Title" | Folios reorder alphabetically by title |
| 7 | Change sort to "Author" | Folios reorder by author name |
| 8 | Visit `/scenes/archive`; verify archive search still functions | Scene archive search returns expected results |

---

## End-to-End: Editor authors a folio with body, entries, and marginalia

Purpose: Validates the full editor + reader loop across all phases.

1. As dragon, assign `jorule` to user A and `seraph` to user B.
2. As user A, create folio "End to End Story".
3. Edit body: paste `[jorule]This is the prologue.[/jorule]\n\n**Bold note.**`. Save.
4. Open `/library/end-to-end-story/compose`. Insert two posts from a scene, then an inline note "between the posts" in the seraph typeface.
5. Drag the note up to position 1; verify reorder.
6. Return to `/library/end-to-end-story`; expand marginalia on the note; click "Reply" and submit "First marginalia."
7. As user B in a second browser, open the same folio. Add a reply: "Reply by B" — verify it appears indented under user A's marginalia in real-time without page refresh.
8. Tag the folio with "epic". Verify the tag appears.
9. As dragon, delete the folio. Confirm redirect to `/library` and folio absent.

---

## End-to-End: Multi-user mutex contention

Purpose: Validates AC3.2 and AC3.3 in a real socket scenario.

1. User A opens body editor on a folio.
2. User B opens the same folio in a different browser; clicks "Edit body".
3. User B sees "Another editor is editing the body".
4. User A clicks Cancel.
5. User B refreshes; clicks "Edit body" — succeeds.
6. User B closes the tab without saving (simulate disconnect).
7. Wait 5+ minutes; user A reopens, clicks "Edit body" — succeeds (stale lock claimed).

---

## Manual-Only Verification

These items require human observation and cannot be fully automated:

| Criterion | Why Manual | Steps |
|-----------|------------|-------|
| Body lock 5-minute auto-timeout | Real wall-clock; uses `Process.send_after` | Open body editor, wait > 5 min, observe second user can claim lock |
| Live preview 300ms debounce | Time-based UI | Type slowly; confirm preview updates feel debounced (not on every keystroke) |
| Real-time marginalia delivery in two browsers | Requires actual websocket connections | Open same folio in two tabs; submit in one; observe other |
| Composer drag-and-drop UX | Sortable.js drag interactions are JS-side | Drag entries; verify visual feedback and final order |
| Group-move-as-unit | Multi-entry group dragging | Group 2+ entries; drag one; verify group moves together |
| Glyph rendering visual quality | Glyphs use SVG/font assets; tests assert classes only | Confirm glyphs visually render as intended graphics |
| XSS safety end-to-end | Browser must actually attempt to execute script | Submit `<script>alert(1)</script>` in body, tag input, marginalia content; confirm no alerts fire |
| Music player + rumor map regression | Independent features sharing global JS | Open `/ost` and `/rumor`; confirm functional |

---

## Traceability

| AC | Automated Test | Manual Phase |
|---|---|---|
| AC1.1 | `admin_live_test` "dragon can view the admin page" | Phase 1.1 |
| AC1.2 | `admin_live_test` "dragon can assign a typeface" + `library_test` "assigns a valid typeface" | Phase 1.2 |
| AC1.3 | `admin_live_test` "dragon can revoke" + `library_test` "revokes an assigned typeface" | Phase 1.3 |
| AC1.4 | `library_test` "returns true after assigning a typeface" | Phase 1.2, Phase 2.1 |
| AC1.5 | `library_test` "returns false for user with no typefaces" + `folio_list_live_test` "non-folio-editor is redirected" | Phase 1.5, Phase 2.2 |
| AC1.6 | `folio_live_test` + `marginalia_test` "non-folio-editor sees no annotate button" | Phase 5.10 |
| AC2.1 | `library_test` "creates folio with title only" | Phase 2.3 |
| AC2.2 | `library_test` "slug is auto-generated from title" | Phase 2.3 |
| AC2.3 | `library_test` "duplicate title returns error" + `folio_list_live_test` | Phase 2.4 |
| AC2.4 | `library_test` "creates folio with body only" + `folio_live_test` "body-only renders" | Phase 2.5 |
| AC2.5 | `library_test` "creates folio without body" + `folio_live_test` "no body does not crash" | Phase 2.6 |
| AC2.6 | `folio_list_live_test` "non-folio-editor is redirected from /library/new" | Phase 1.5 |
| AC3.1 | `body_editor_test` "folio editor can open body editor" | Phase 3.1 |
| AC3.2 | `body_editor_test` "second editor sees locked flash" + `library_test` mutex tests | Phase 3.7, E2E mutex |
| AC3.3 | `body_editor_test` "save_body releases" + `library_test` stale-lock | Phase 3.8/9, E2E mutex |
| AC3.4 | `library_helpers_test` "renders known typeface tag as styled span" | Phase 3.3 |
| AC3.5 | `library_helpers_test` "renders unknown typeface name as literal text" | Phase 3.4 |
| AC3.6 | `library_helpers_test` "glyph pairs render correctly" | Phase 3.5 |
| AC3.7 | `body_editor_test` "update_preview event updates preview html" | Phase 3.2 |
| AC4.1 | `composer_live_test` "folio editor can access composer" | Phase 4.1 |
| AC4.2 | `composer_live_test` "filter_scenes logic preserves full-cast-session scenes" | Phase 4.3 |
| AC4.3 | `composer_live_test` "template conditional renders bg-emerald classes" | Phase 4.2 |
| AC4.4 | `composer_live_test` "toggle_my_scenes event filters" | Phase 4.4 |
| AC4.5 | `composer_live_test` "creates a post_ref entry at the current caret position" | Phase 4.6 |
| AC4.6 | `composer_live_test` "shift-click from anchor to post inserts contiguous post_ref entries" | Phase 4.7 |
| AC4.7 | `composer_live_test` "reorder_entries event" + grouping tests | Phase 4.8, group-move manual |
| AC4.8 | `composer_live_test` "adding a note via server event creates entry" | Phase 4.9 |
| AC4.9 | `composer_live_test` "caret position displays and updates" | Phase 4.6 |
| AC5.1 | `composer_live_test` "folio editor can see the note form" | Phase 4.11 |
| AC5.2 | `composer_live_test` "author can see and delete their entries" | Phase 4.10 |
| AC5.3 | `composer_live_test` "non-author folio editor does not see delete button" | Phase 4.11 |
| AC6.1 | `marginalia_test` "folio editor can post marginalia" | Phase 5.3 |
| AC6.2 | `marginalia_test` "string ID typeface" + `folio_live_test` "second typeface" | Phase 5.7/8 |
| AC6.3 | `marginalia_test` typeface tests assert `font` and `color` persisted | Phase 5.8 |
| AC6.4 | `marginalia_test` "marginalia threads are collapsed by default" | Phase 5.1 |
| AC6.5 | `marginalia_test` "replies render with depth-based indentation margins" | Phase 5.4/5 |
| AC6.6 | `marginalia_test` "new marginalia appear in real-time" | Phase 5.9, E2E step 7 |
| AC6.7 | `marginalia_test` "non-folio-editor does not see annotate" + "non-editor blocked by LiveView guard" | Phase 5.10 |
| AC7.1 | `library_test` search filters by title/subtitle/body/tag | Phase 7.2/3 |
| AC7.2 | `library_test` "results contain only Folio structs" | Phase 7 (implicit) |
| AC7.3 | `library_test` author/tag/sort tests | Phase 7.4–7 |
| AC7.4 | `library_test` "Scenes archive search returns same results" | Phase 7.8 |
| AC8.1 | `library_test` + `folio_live_test` tag tests | Phase 6.1–4 |
| AC8.2 | `folio_live_test` "non-folio-editor sees no add/remove tag UI" | Phase 6.5/6 |
| AC8.3 | `folio_live_test` "dragon can delete a folio" | Phase 6.7/8 |
| AC8.4 | `folio_live_test` "non-dragon does not see delete button" | Phase 6.9 |
