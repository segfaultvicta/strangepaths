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
    result = Repo.transaction(fn ->
      ordered_ids
      |> Enum.with_index(1)
      |> Enum.each(fn {id, position} ->
        from(e in Entry, where: e.id == ^id and e.folio_id == ^folio_id)
        |> Repo.update_all(set: [position: position])
      end)
    end)

    case result do
      {:ok, _} -> :ok
      error -> error
    end
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

  def create_marginalia(entry, user, attrs) do
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
        Repo.insert(validated_changeset)
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
end
