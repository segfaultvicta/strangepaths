defmodule Strangepaths.Library do
  import Ecto.Query
  import Ecto.Changeset
  alias Strangepaths.Repo
  alias Strangepaths.Library.{Folio, FolioTag, Entry, Marginalia, UserTypeface}

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

  def list_folio_authors do
    from(u in Strangepaths.Accounts.User,
      join: f in Folio, on: f.user_id == u.id,
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
    - :tag         - Filter to folios with this tag (nil or "" = no tag filter)
    - :sort_by     - :date (newest first, default), :title (asc), :author (asc by nickname)
  """
  def search_folios(opts \\ []) do
    query_str = Keyword.get(opts, :query)
    author_id = Keyword.get(opts, :author_id)
    tag_filter = Keyword.get(opts, :tag)
    sort_by = Keyword.get(opts, :sort_by, :date)

    query =
      from(f in Folio,
        join: u in Strangepaths.Accounts.User, on: u.id == f.user_id,
        preload: [user: u]
      )

    # Text search across title, subtitle, body
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

    # Tag filter — use subquery to avoid DISTINCT ON interfering with ORDER BY
    query =
      if tag_filter && String.trim(tag_filter) != "" do
        tag_pattern = "%#{String.downcase(String.trim(tag_filter))}%"
        tag_subquery = from(ft in FolioTag, where: ilike(ft.tag, ^tag_pattern), select: ft.folio_id)
        from([f] in query, where: f.id in subquery(tag_subquery))
      else
        query
      end

    # Sort
    query =
      case sort_by do
        :title -> from([f, u] in query, order_by: [asc: f.title])
        :author -> from([f, u] in query, order_by: [asc: u.nickname, asc: f.title])
        _ -> from([f, u] in query, order_by: [desc: f.inserted_at])
      end

    Repo.all(query)
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

  def delete_folio(folio), do: Repo.delete(folio)

  def change_folio(folio \\ %Folio{}, attrs \\ %{}) do
    Folio.create_changeset(folio, attrs)
  end

  # Lock timeout in seconds — also used by the LiveView for Process.send_after
  def lock_timeout_seconds, do: 300   # 5 minutes

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
        set: [body: content, body_locked_by_id: nil, body_locked_at: nil, updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)]
      )

    if count == 1, do: :ok, else: {:error, :lock_lost}
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
      preload: [scene_post: [:user]]
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
      %Entry{}
      |> Entry.post_ref_changeset(%{
        folio_id: folio.id,
        user_id: user.id,
        scene_post_id: scene_post_id,
        position: pos
      })
      |> Repo.insert()
    end) do
      {:ok, {:ok, entry}} -> {:ok, entry}
      {:ok, {:error, changeset}} -> {:error, changeset}
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
      %Entry{}
      |> Entry.note_changeset(
        attrs
        |> Map.put("folio_id", folio.id)
        |> Map.put("user_id", user.id)
        |> Map.put("position", pos)
      )
      |> Repo.insert()
    end) do
      {:ok, {:ok, entry}} -> {:ok, entry}
      {:ok, {:error, changeset}} -> {:error, changeset}
      error -> error
    end
  end

  def delete_entry(entry), do: Repo.delete(entry)

  def update_note_entry(entry, attrs) do
    entry
    |> Entry.note_changeset(attrs)
    |> Repo.update()
  end

  def reorder_entries(folio_id, ordered_ids) do
    result = Repo.transaction(fn ->
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
    end)

    case result do
      {:ok, _} -> :ok
      error -> error
    end
  end

  def update_entry_group(entry, group_id) do
    entry
    |> Entry.group_changeset(%{group_id: group_id})
    |> Repo.update()
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

  @max_marginalia_depth 3

  def create_marginalia(entry, user, attrs) do
    parent_id = attrs["parent_id"] || attrs[:parent_id]

    cond do
      parent_id != nil && parent_id != "" ->
        depth = marginalia_depth(String.to_integer(to_string(parent_id)))

        if depth >= @max_marginalia_depth do
          {:error, :max_depth_exceeded}
        else
          do_create_marginalia(entry, user, attrs)
        end

      true ->
        do_create_marginalia(entry, user, attrs)
    end
  end

  defp do_create_marginalia(entry, user, attrs) do
    changeset =
      %Marginalia{}
      |> Marginalia.create_changeset(
        attrs
        |> Map.put("entry_id", entry.id)
        |> Map.put("user_id", user.id)
      )

    # Validate parent marginalia belongs to the same entry (structural validation
    # is in the changeset; DB validation is here per FCIS pattern).
    case validate_parent_marginalia(changeset, entry.id) do
      {:ok, validated_changeset} ->
        result = Repo.insert(validated_changeset)

        case result do
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

  # Computes the depth of a marginalia by walking up the parent chain.
  # Note: Does O(depth) queries via Repo.get/1 per ancestor, bounded by @max_marginalia_depth.
  # Max queries = @max_marginalia_depth (3), so this is acceptable despite the N+1 pattern.
  defp marginalia_depth(nil), do: 0
  defp marginalia_depth(parent_id) when is_integer(parent_id) do
    case Repo.get(Marginalia, parent_id) do
      nil -> 0
      parent -> 1 + marginalia_depth(parent.parent_id)
    end
  end
end
