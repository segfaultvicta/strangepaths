defmodule Strangepaths.Library do
  import Ecto.Query
  import Ecto.Changeset
  alias Strangepaths.Repo

  alias Strangepaths.Library.{
    Folio,
    FolioEdit,
    FolioTag,
    Entry,
    Marginalia,
    UserTypeface,
    FolioReadMark,
    MarginaliaReadMark
  }

  @bird_barks [
    "Welcome to the Liminal Library!",
    "Feel free to scan the shelves!",
    "We remember so you don't have to.",
    "Yeah, we all saw that.",
    "Check the logs!",
    "What do you MEAN you forgot to log it?!",
    "hmm-HM-HM-hmmm~ ♪",
    "Are you sure that really happened?",
    "It's organized CHAOS!",
    "Hahaha... hahahahah... haha... hahaha... ha... Yes.",
    "All Your Lucre Is Belong To Me!",
    "The other world was better.",
    ".. -- / .- / -.-. --- -.. . / -... .-. . .- -.- . .-.",
    "Chaw!",
    "Not a fish, not a man, but a BIRD!",
    "No open flames in the Library.",
    "ACKSHUALLY, it's an ARCHIVE, not a Library.",
    "You don't sleep much, do you?",
    "No, you can't set this as your Home Point.",
    "It is a Ritual, and must be Observed.",
    "Anything Could Happen.",
    "Those with a Pure Heart can Travel to a Whole New World...?",
    "The trick to doing something impossible is, obviously, to just do something much easier in an adjacent fashion."
  ]

  # === USER TYPEFACES ===

  def assign_user_typeface(user_id, typeface_id) do
    %UserTypeface{}
    |> UserTypeface.changeset(%{user_id: user_id, typeface_id: typeface_id})
    |> Repo.insert(on_conflict: :nothing, conflict_target: [:user_id, :typeface_id])
  end

  # Note: remove_user_typeface is NOT idempotent — revoking an unassigned typeface
  # returns {:error, :not_found}. This is intentional to prevent silent failures in
  # dragon moderation flows (trying to revoke a typeface the user doesn't have
  # suggests a client/admin UI error worth surfacing).
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

  def folio_editor?(user_id) do
    Repo.exists?(from(ut in UserTypeface, where: ut.user_id == ^user_id))
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

  def list_folio_authors do
    from(u in Strangepaths.Accounts.User,
      join: f in Folio,
      on: f.user_id == u.id,
      distinct: u.id,
      order_by: u.nickname
    )
    |> Repo.all()
  end

  @doc """
  Search and filter folios. Returns a list of Folio structs with :user preloaded.

  Options:
    - :query       - String to search title, subtitle, and body (ILIKE; nil or "" = no search)
    - :author_id   - Filter to folios by this user id (nil = all authors)
    - :tags        - List of tag strings; folios must match ALL tags (AND logic). Empty list = no filter.
    - :sort_by     - :updated (recently updated first, default), :date (recently accessioned first), :title (asc), :author (asc by nickname)
    - :viewer_id   - The current user's id; they can see their own private folios (nil = anonymous)
    - :is_dragon   - If true, all folios including private ones are visible
  """
  def search_folios(opts \\ []) do
    query_str = Keyword.get(opts, :query)
    author_id = Keyword.get(opts, :author_id)
    tags_filter = Keyword.get(opts, :tags, [])
    sort_by = Keyword.get(opts, :sort_by, :updated)
    viewer_id = Keyword.get(opts, :viewer_id)
    is_dragon = Keyword.get(opts, :is_dragon, false)

    query =
      from(f in Folio,
        join: u in Strangepaths.Accounts.User,
        on: u.id == f.user_id,
        left_join: ub in Strangepaths.Accounts.User,
        on: ub.id == f.last_updated_by_id,
        preload: [user: u, last_updated_by: ub]
      )

    # Text search across title, subtitle, body
    # TODO: migrate to tsvector + GIN index + ts_rank for full-text search once folio count grows; ILIKE is fine for small datasets
    query =
      if query_str && String.trim(query_str) != "" do
        pattern = "%#{query_str}%"

        from([f] in query,
          where:
            ilike(f.title, ^pattern) or
              ilike(f.subtitle, ^pattern) or
              ilike(f.body, ^pattern)
        )
      else
        query
      end

    # Author filter
    query =
      if author_id do
        from([f] in query, where: f.user_id == ^author_id)
      else
        query
      end

    # Tag filter — one subquery per tag (AND logic); subqueries avoid DISTINCT ON interfering with ORDER BY
    query =
      Enum.reduce(tags_filter, query, fn tag, q ->
        tag_pattern = "%#{String.downcase(String.trim(tag))}%"
        tag_subquery = from(ft in FolioTag, where: ilike(ft.tag, ^tag_pattern), select: ft.folio_id)
        from([f] in q, where: f.id in subquery(tag_subquery))
      end)

    # Visibility: hide private folios unless viewer is the author or a dragon
    query =
      cond do
        is_dragon ->
          query

        is_integer(viewer_id) ->
          from([f] in query, where: not f.is_private or f.user_id == ^viewer_id)

        true ->
          from([f] in query, where: not f.is_private)
      end

    # Sort
    query =
      case sort_by do
        :title -> from([f, u] in query, order_by: [asc: f.title])
        :author -> from([f, u] in query, order_by: [asc: u.nickname, asc: f.title])
        :date -> from([f, u] in query, order_by: [desc: f.inserted_at])
        _ -> from([f, u] in query, order_by: [desc: f.updated_at])
      end

    query
    |> Repo.all()
    |> Repo.preload(:tags)
  end

  def search_folios_for_archives(query, _user_id, author_filter \\ "") do
    pattern = "%#{query}%"
    threshold = 0.15
    query_lower = String.downcase(query)

    # Body has no author attribution — skip when filtering by author
    body_ids =
      if author_filter == "" do
        from(f in Folio,
          where:
            not f.is_private and
              (ilike(f.body, ^pattern) or
                 fragment("similarity(?, ?) > ?", f.body, ^query, ^threshold)),
          select: f.id
        )
        |> Repo.all()
        |> MapSet.new()
      else
        MapSet.new()
      end

    note_base =
      from(e in Entry,
        join: f in Folio,
        on: f.id == e.folio_id,
        where:
          not f.is_private and
            e.kind == :note and
            (ilike(e.content, ^pattern) or
               fragment("similarity(?, ?) > ?", e.content, ^query, ^threshold)),
        select: e.folio_id
      )

    note_folio_ids =
      if author_filter != "" do
        author_pattern = "%#{author_filter}%"
        where(note_base, [e, _f], ilike(e.name, ^author_pattern))
      else
        note_base
      end
      |> Repo.all()
      |> MapSet.new()

    marginalia_base =
      from(m in Marginalia,
        join: e in Entry,
        on: e.id == m.entry_id,
        join: f in Folio,
        on: f.id == e.folio_id,
        where:
          not f.is_private and
            (ilike(m.content, ^pattern) or
               fragment("similarity(?, ?) > ?", m.content, ^query, ^threshold)),
        select: e.folio_id
      )

    marginalia_folio_ids =
      if author_filter != "" do
        author_pattern = "%#{author_filter}%"
        where(marginalia_base, [m, _e, _f], ilike(m.name, ^author_pattern))
      else
        marginalia_base
      end
      |> Repo.all()
      |> MapSet.new()

    all_folio_ids =
      MapSet.union(body_ids, MapSet.union(note_folio_ids, marginalia_folio_ids))
      |> MapSet.to_list()

    if all_folio_ids == [] do
      []
    else
      folios = from(f in Folio, where: f.id in ^all_folio_ids and not f.is_private) |> Repo.all()

      folios
      |> Enum.map(fn folio ->
        snippets =
          [
            folio_body_snippet(folio, body_ids, query),
            folio_note_snippet(folio, note_folio_ids, pattern, query),
            folio_marginalia_snippet(folio, marginalia_folio_ids, pattern, query)
          ]
          |> Enum.reject(&is_nil/1)
          |> Enum.take(3)

        body_exact = String.contains?(String.downcase(folio.body || ""), query_lower)

        content_exact =
          Enum.any?(snippets, fn s ->
            String.contains?(String.downcase(s.snippet), query_lower)
          end)

        sort_score =
          cond do
            body_exact -> 0
            content_exact -> 1
            true -> 2
          end

        %{
          folio_id: folio.id,
          folio_slug: folio.slug,
          folio_title: folio.title,
          snippets: snippets,
          sort_score: sort_score
        }
      end)
      |> Enum.sort_by(& &1.sort_score)
      |> Enum.map(&Map.delete(&1, :sort_score))
    end
  end

  defp folio_body_snippet(folio, body_ids, query) do
    if MapSet.member?(body_ids, folio.id) do
      %{snippet: archive_extract_snippet(folio.body, query, 150), source: :prolegomenon}
    end
  end

  defp folio_note_snippet(folio, note_folio_ids, pattern, query) do
    if MapSet.member?(note_folio_ids, folio.id) do
      entry =
        from(e in Entry,
          where:
            e.folio_id == ^folio.id and e.kind == :note and
              (ilike(e.content, ^pattern) or
                 fragment("similarity(?, ?) > ?", e.content, ^query, ^0.15)),
          limit: 1
        )
        |> Repo.one()

      if entry, do: %{snippet: archive_extract_snippet(entry.content, query, 150), source: :note}
    end
  end

  defp folio_marginalia_snippet(folio, marginalia_folio_ids, pattern, query) do
    if MapSet.member?(marginalia_folio_ids, folio.id) do
      marg =
        from(m in Marginalia,
          join: e in Entry,
          on: e.id == m.entry_id,
          where:
            e.folio_id == ^folio.id and
              (ilike(m.content, ^pattern) or
                 fragment("similarity(?, ?) > ?", m.content, ^query, ^0.15)),
          limit: 1,
          select: m
        )
        |> Repo.one()

      if marg,
        do: %{snippet: archive_extract_snippet(marg.content, query, 150), source: :marginalia}
    end
  end

  defp archive_extract_snippet(content, query, max_length) do
    content = content || ""
    query_lower = String.downcase(query)
    content_lower = String.downcase(content)

    case :binary.match(content_lower, query_lower) do
      {pos, len} ->
        start_pos = max(0, pos - div(max_length - len, 2))
        end_pos = min(String.length(content), start_pos + max_length)
        start_pos = max(0, end_pos - max_length)
        snippet = String.slice(content, start_pos, max_length)

        cond do
          start_pos > 0 && end_pos < String.length(content) -> "..." <> snippet <> "..."
          start_pos > 0 -> "..." <> snippet
          end_pos < String.length(content) -> snippet <> "..."
          true -> snippet
        end

      :nomatch ->
        String.slice(content, 0, max_length)
    end
  end

  def list_all_folio_tags do
    from(ft in FolioTag, select: ft.tag, distinct: true, order_by: ft.tag)
    |> Repo.all()
  end

  def get_folio!(id), do: Repo.get!(Folio, id)

  def get_folio_by_slug!(slug), do: Repo.get_by!(Folio, slug: slug)

  def get_folio_by_slug(slug) do
    case Repo.get_by(Folio, slug: slug) do
      nil -> nil
      folio -> Repo.preload(folio, :user)
    end
  end

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

  def update_folio_privacy(folio, is_private) do
    folio
    |> Folio.create_changeset(%{is_private: is_private})
    |> Repo.update()
  end

  def delete_folio(folio), do: Repo.delete(folio)

  def change_folio(folio \\ %Folio{}, attrs \\ %{}) do
    Folio.create_changeset(folio, attrs)
  end

  # Lock timeout in seconds — also used by the LiveView for Process.send_after
  # 5 minutes
  def lock_timeout_seconds, do: 300

  # Atomically claims the body lock if unclaimed or stale.
  # Returns :ok on success, {:error, :locked} if another user currently holds it.
  def claim_body_lock(folio_id, user_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    stale_before = DateTime.add(now, -lock_timeout_seconds(), :second)

    {count, _} =
      from(f in Folio,
        where:
          f.id == ^folio_id and
            (is_nil(f.body_locked_by_id) or
               f.body_locked_at < ^stale_before or
               f.body_locked_by_id == ^user_id)
      )
      |> Repo.update_all(set: [body_locked_by_id: user_id, body_locked_at: now])

    if count == 1, do: :ok, else: {:error, :locked}
  end

  # Releases the lock unconditionally.
  def release_body_lock(folio_id) do
    from(f in Folio, where: f.id == ^folio_id)
    |> Repo.update_all(set: [body_locked_by_id: nil, body_locked_at: nil])

    :ok
  end

  # Saves body content and releases the lock atomically.
  # Verifies the caller (user_id) currently holds the lock before saving.
  # Returns :ok on success, {:error, :lock_lost} if the lock is not held by the caller.
  def save_body(folio, user_id, content) do
    {count, _} =
      from(f in Folio,
        where: f.id == ^folio.id and f.body_locked_by_id == ^user_id
      )
      |> Repo.update_all(
        set: [
          body: content,
          body_locked_by_id: nil,
          body_locked_at: nil,
          last_updated_by_id: user_id,
          updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
        ]
      )

    if count == 1 do
      StrangepathsWeb.Endpoint.broadcast(
        "library_folio:#{folio.id}",
        "body_updated",
        %{body: content, updated_by_id: user_id}
      )

      summary = body_diff_summary(folio.body, content)
      record_folio_edit(folio.id, user_id, "body", summary)

      :ok
    else
      {:error, :lock_lost}
    end
  end

  def entries_lock_timeout_seconds, do: 300

  def claim_entries_lock(folio_id, user_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    stale_before = DateTime.add(now, -entries_lock_timeout_seconds(), :second)

    {count, _} =
      from(f in Folio,
        where:
          f.id == ^folio_id and
            (is_nil(f.entries_locked_by_id) or
               f.entries_locked_at < ^stale_before or
               f.entries_locked_by_id == ^user_id)
      )
      |> Repo.update_all(set: [entries_locked_by_id: user_id, entries_locked_at: now])

    if count == 1, do: :ok, else: {:error, :locked}
  end

  def release_entries_lock(folio_id) do
    from(f in Folio, where: f.id == ^folio_id)
    |> Repo.update_all(set: [entries_locked_by_id: nil, entries_locked_at: nil])

    :ok
  end

  # Returns a locked folio (with lock metadata) — used by the LiveView to check lock holder.
  def get_folio_lock_info(folio_id) do
    from(f in Folio,
      where: f.id == ^folio_id,
      select: %{locked_by_id: f.body_locked_by_id, locked_at: f.body_locked_at}
    )
    |> Repo.one()
  end

  # === TAGS ===

  def list_tags(folio_id) do
    from(t in FolioTag, where: t.folio_id == ^folio_id, select: t.tag, order_by: t.tag)
    |> Repo.all()
  end

  def list_folio_tags(folio_id) do
    from(ft in FolioTag, where: ft.folio_id == ^folio_id, select: ft.tag, order_by: ft.tag)
    |> Repo.all()
  end

  def add_tag(folio, tag) do
    normalized = tag |> String.downcase() |> String.trim()

    %FolioTag{}
    |> FolioTag.changeset(%{folio_id: folio.id, tag: normalized})
    |> Repo.insert(on_conflict: :nothing, conflict_target: [:folio_id, :tag])
  end

  # Note: remove_tag is idempotent — removing a tag that doesn't exist returns {:ok, nil}.
  # This is intentional per liminal-library.AC8.1 design: tags are designed to be
  # idempotent operations, suitable for frontend click-toggle UI patterns without
  # requiring extra checks.
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
      preload: [scene_post: [:user, :scene]]
    )
    |> Repo.all()
  end

  def create_post_entry(folio, user, scene_post_id, position \\ nil) do
    pos = position || next_entry_position(folio.id)

    case Repo.transaction(fn ->
           # Use temporary negative positions to avoid unique constraint violations during shift.
           # First, shift all entries at position >= pos to temporary negative positions.
           from(e in Entry, where: e.folio_id == ^folio.id and e.position >= ^pos)
           |> Repo.update_all(inc: [position: -10_000])

           # Then shift them to their final positions (incrementing by 10_001 to get positive positions).
           from(e in Entry, where: e.folio_id == ^folio.id and e.position < 0)
           |> Repo.update_all(inc: [position: 10_001])

           # Insert new entry at the caret position
           result =
             %Entry{}
             |> Entry.post_ref_changeset(%{
               folio_id: folio.id,
               user_id: user.id,
               scene_post_id: scene_post_id,
               position: pos
             })
             |> Repo.insert()

           touch_folio_updated_at(folio.id, user.id)
           result
         end) do
      {:ok, {:ok, entry}} -> {:ok, entry}
      {:ok, {:error, changeset}} -> {:error, changeset}
      error -> error
    end
  end

  def create_post_entries_at(folio, user, post_ids, position) do
    case Repo.transaction(fn ->
           # Use temporary negative positions to avoid unique constraint violations during shift.
           # First, shift all entries at position >= position to temporary negative positions.
           from(e in Entry, where: e.folio_id == ^folio.id and e.position >= ^position)
           |> Repo.update_all(inc: [position: -10_000])

           # Then shift them to their final positions (incrementing by 10_000 + n to make room for n new entries).
           from(e in Entry, where: e.folio_id == ^folio.id and e.position < 0)
           |> Repo.update_all(inc: [position: 10_000 + length(post_ids)])

           # Insert all entries with consecutive positions starting at position
           entries =
             post_ids
             |> Enum.with_index(position)
             |> Enum.map(fn {post_id, pos} ->
               now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

               %{
                 folio_id: folio.id,
                 user_id: user.id,
                 scene_post_id: post_id,
                 position: pos,
                 kind: :post_ref,
                 inserted_at: now
               }
             end)

           result = Repo.insert_all(Entry, entries, returning: true)
           touch_folio_updated_at(folio.id, user.id)
           result
         end) do
      {:ok, {_count, entries}} -> {:ok, entries}
      error -> error
    end
  end

  def create_note_entry(folio, user, attrs, position \\ nil) do
    pos = position || next_entry_position(folio.id)

    case Repo.transaction(fn ->
           # Use temporary negative positions to avoid unique constraint violations during shift.
           # First, shift all entries at position >= pos to temporary negative positions.
           from(e in Entry, where: e.folio_id == ^folio.id and e.position >= ^pos)
           |> Repo.update_all(inc: [position: -10_000])

           # Then shift them to their final positions (incrementing by 10_001 to get positive positions).
           from(e in Entry, where: e.folio_id == ^folio.id and e.position < 0)
           |> Repo.update_all(inc: [position: 10_001])

           # Insert new entry at the caret position
           result =
             %Entry{}
             |> Entry.note_changeset(
               attrs
               |> Map.put("folio_id", folio.id)
               |> Map.put("user_id", user.id)
               |> Map.put("position", pos)
             )
             |> Repo.insert()

           touch_folio_updated_at(folio.id, user.id)
           result
         end) do
      {:ok, {:ok, entry}} -> {:ok, entry}
      {:ok, {:error, changeset}} -> {:error, changeset}
      error -> error
    end
  end

  def delete_entry(entry, user_id \\ nil) do
    result = Repo.delete(entry)
    touch_folio_updated_at(entry.folio_id, user_id)
    result
  end

  def entry_has_marginalia?(entry_id) do
    Repo.exists?(from(m in Marginalia, where: m.entry_id == ^entry_id))
  end

  def update_note_entry(entry, attrs, user_id \\ nil) do
    result = entry |> Entry.note_changeset(attrs) |> Repo.update()
    if match?({:ok, _}, result), do: touch_folio_updated_at(entry.folio_id, user_id)
    result
  end

  def reorder_entries(folio_id, ordered_ids, user_id \\ nil) do
    result =
      Repo.transaction(fn ->
        # Use temporary negative positions to avoid unique constraint violations
        # First, assign temporary negative positions based on current order
        ordered_ids
        |> Enum.with_index()
        |> Enum.each(fn {id, temp_pos} ->
          from(e in Entry, where: e.id == ^id and e.folio_id == ^folio_id)
          |> Repo.update_all(set: [position: -(temp_pos + 1)])
        end)

        # Then assign the final positive positions
        ordered_ids
        |> Enum.with_index(1)
        |> Enum.each(fn {id, final_pos} ->
          from(e in Entry, where: e.id == ^id and e.folio_id == ^folio_id)
          |> Repo.update_all(set: [position: final_pos])
        end)

        touch_folio_updated_at(folio_id, user_id)
      end)

    case result do
      {:ok, _} -> :ok
      error -> error
    end
  end

  def update_entry_group(entry, group_id) do
    result = entry |> Entry.group_changeset(%{group_id: group_id}) |> Repo.update()
    if match?({:ok, _}, result), do: touch_folio_updated_at(entry.folio_id)
    result
  end

  defp touch_folio_updated_at(folio_id, user_id \\ nil) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    set = [updated_at: now] ++ if(user_id, do: [last_updated_by_id: user_id], else: [])
    from(f in Folio, where: f.id == ^folio_id) |> Repo.update_all(set: set)
  end

  defp next_entry_position(folio_id) do
    # Note: Known race condition — two concurrent create_*_entry calls can both
    # read the same count(e.id) and both assign the same position. Acceptable for
    # Phase 1 (single-user editing). Future fix: use MAX(position)+1 in an INSERT...SELECT
    # or advisory locks at the Ecto level to guarantee atomic position assignment.
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

  def list_all_marginalia_for_folio(folio_id) do
    entry_ids =
      from(e in Entry, where: e.folio_id == ^folio_id, select: e.id)
      |> Repo.all()

    from(m in Marginalia,
      where: m.entry_id in ^entry_ids,
      order_by: m.inserted_at,
      preload: [:user]
    )
    |> Repo.all()
  end

  def list_recent_marginalia(limit \\ 10) do
    from(m in Marginalia,
      join: e in Entry,
      on: e.id == m.entry_id,
      join: f in Folio,
      on: f.id == e.folio_id,
      where: not f.is_private,
      order_by: [desc: m.inserted_at],
      limit: ^limit,
      select: %{
        id: m.id,
        name: m.name,
        content: m.content,
        inserted_at: m.inserted_at,
        folio_slug: f.slug,
        folio_title: f.title
      }
    )
    |> Repo.all()
  end


  def list_folio_edits(folio_id) do
    from(fe in FolioEdit,
      join: u in Strangepaths.Accounts.User, on: u.id == fe.editor_id,
      where: fe.folio_id == ^folio_id,
      order_by: [desc: fe.inserted_at],
      select: %{
        kind: fe.kind,
        summary: fe.summary,
        detail: fe.detail,
        editor_nickname: u.nickname,
        inserted_at: fe.inserted_at
      }
    )
    |> Repo.all()
  end

  def list_recent_folio_edits(limit \\ 10) do
    from(fe in FolioEdit,
      join: f in Folio, on: f.id == fe.folio_id,
      join: u in Strangepaths.Accounts.User, on: u.id == fe.editor_id,
      where: not f.is_private,
      order_by: [desc: fe.inserted_at],
      limit: ^limit,
      select: %{
        folio_title: f.title,
        folio_slug: f.slug,
        editor_nickname: u.nickname,
        kind: fe.kind,
        summary: fe.summary,
        inserted_at: fe.inserted_at
      }
    )
    |> Repo.all()
  end

  def record_entries_edit(folio_id, editor_id, summary, detail \\ nil) do
    record_folio_edit(folio_id, editor_id, "entries", summary, detail)
  end

  defp record_folio_edit(folio_id, editor_id, kind, summary, detail \\ nil) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    Repo.insert_all("library_folio_edits", [%{
      folio_id: folio_id,
      editor_id: editor_id,
      kind: kind,
      summary: summary,
      detail: detail,
      inserted_at: now
    }])
  end

  defp strip_typeface_tags(text) do
    Regex.replace(~r/\[[a-z]+\](.*?)\[\/[a-z]+\]/s, text, "\\1")
  end

  defp body_diff_summary(old_body, new_body) do
    old_clean = strip_typeface_tags(old_body || "")
    new_clean = strip_typeface_tags(new_body || "")

    case Strangepaths.Rumor.Diff.word_diff(old_clean, new_clean) do
      nil ->
        new_clean

      segments ->
        segments
        |> Enum.map(fn
          :sep -> "..."
          {:eq, w} -> w
          {:del, w} -> "[-#{w}-]"
          {:ins, w} -> "[+#{w}+]"
        end)
        |> Enum.join(" ")
        |> String.replace(" ... ", "...")
    end
  end

  def create_marginalia(entry, user, attrs) do
    parent_id = attrs["parent_id"] || attrs[:parent_id]

    depth =
      if parent_id != nil && parent_id != "" do
        case Repo.get(Marginalia, String.to_integer(to_string(parent_id))) do
          nil -> 0
          parent -> parent.depth + 1
        end
      else
        0
      end

    changeset =
      %Marginalia{}
      |> Marginalia.create_changeset(
        attrs
        |> Map.put("entry_id", entry.id)
        |> Map.put("user_id", user.id)
        |> Map.put("depth", depth)
      )

    case validate_parent_marginalia(changeset, entry.id) do
      {:ok, validated_changeset} ->
        case Repo.insert(validated_changeset) do
          {:ok, marginalia} ->
            StrangepathsWeb.Endpoint.broadcast(
              "library_folio:#{entry.folio_id}",
              "new_marginalia",
              %{marginalia: Repo.preload(marginalia, :user), entry_id: entry.id}
            )

            {:ok, marginalia}

          error ->
            error
        end

      {:error, error_changeset} ->
        {:error, error_changeset}
    end
  end

  # === FOLIO READ MARKS ===

  def record_folio_visit(user_id, folio_id) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    %FolioReadMark{}
    |> FolioReadMark.changeset(%{user_id: user_id, folio_id: folio_id, last_visited_at: now})
    |> Repo.insert(
      on_conflict: [set: [last_visited_at: now, updated_at: now]],
      conflict_target: [:user_id, :folio_id]
    )
  end

  # Returns a map of %{folio_id => new_marginalia_count} for the given folio IDs and user.
  # A marginalia item is "new" if it was inserted after the user's last recorded visit.
  # Folios the user has never visited show the count of all their marginalia.
  # Folios with no new marginalia are omitted (use Map.get(counts, id, 0) in callers).
  def new_marginalia_counts([], _user_id), do: %{}

  def new_marginalia_counts(folio_ids, user_id) do
    from(e in Entry,
      join: m in Marginalia,
      on: m.entry_id == e.id,
      left_join: rm in FolioReadMark,
      on: rm.folio_id == e.folio_id and rm.user_id == ^user_id,
      where: e.folio_id in ^folio_ids,
      where: is_nil(rm.last_visited_at) or m.inserted_at > rm.last_visited_at,
      group_by: e.folio_id,
      select: {e.folio_id, count(m.id)}
    )
    |> Repo.all()
    |> Map.new()
  end

  # Returns a MapSet of marginalia IDs the user has not yet read within the given folio.
  def unread_marginalia_ids(_folio_id, nil), do: MapSet.new()

  def unread_marginalia_ids(folio_id, user_id) do
    from(m in Marginalia,
      join: e in Entry,
      on: e.id == m.entry_id,
      left_join: rm in MarginaliaReadMark,
      on: rm.marginalia_id == m.id and rm.user_id == ^user_id,
      where: e.folio_id == ^folio_id,
      where: is_nil(rm.id),
      select: m.id
    )
    |> Repo.all()
    |> MapSet.new()
  end

  # Marks all marginalia on an entry as read for the given user (idempotent).
  def mark_entry_marginalia_read(user_id, entry_id) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    marginalia_ids =
      from(m in Marginalia, where: m.entry_id == ^entry_id, select: m.id) |> Repo.all()

    rows = Enum.map(marginalia_ids, &%{user_id: user_id, marginalia_id: &1, inserted_at: now})

    Repo.insert_all(MarginaliaReadMark, rows,
      on_conflict: :nothing,
      conflict_target: [:user_id, :marginalia_id]
    )

    :ok
  end

  def bird_bark() do
    seed = div(System.os_time(:second), 10)
    {idx, _} = :rand.uniform_s(length(@bird_barks), :rand.seed_s(:exsss, {seed, seed, seed}))
    Enum.at(@bird_barks, idx - 1)
  end

  @spec update_marginalia(
          {map(),
           %{
             optional(atom()) =>
               atom()
               | {:array | :assoc | :embed | :in | :map | :parameterized | :supertype | :try,
                  any()}
           }}
          | %{
              :__struct__ => atom() | %{:__changeset__ => any(), optional(any()) => any()},
              optional(atom()) => any()
            },
          :invalid | %{optional(:__struct__) => none(), optional(atom() | binary()) => any()}
        ) :: any()
  def update_marginalia(marginalia, attrs) do
    marginalia
    |> Marginalia.update_changeset(attrs)
    |> Repo.update()
  end

  defp validate_parent_marginalia(changeset, entry_id) do
    parent_id = get_change(changeset, :parent_id)

    if parent_id do
      case Repo.get(Marginalia, parent_id) do
        nil ->
          {:error, add_error(changeset, :parent_id, "does not exist")}

        parent ->
          if parent.entry_id == entry_id do
            {:ok, changeset}
          else
            {:error, add_error(changeset, :parent_id, "must belong to the same entry")}
          end
      end
    else
      {:ok, changeset}
    end
  end
end
