defmodule Strangepaths.Site do
  @moduledoc """
  The Site context.
  """

  import Ecto.Query, warn: false
  alias Strangepaths.Repo

  alias Strangepaths.Site.MusicQueue
  alias Strangepaths.Site.Song
  alias Strangepaths.Site.ContentPage
  alias Strangepaths.Site.ContentFolder

  @doc """
  Returns the list of songs.

  ## Examples

      iex> list_songs()
      [%Song{}, ...]

  """
  def list_songs do
    Repo.all(Song)
  end

  def disc1 do
    Song |> where(disc: 1) |> order_by(:order) |> Repo.all()
  end

  def disc2 do
    Song |> where(disc: 2) |> order_by(:order) |> Repo.all()
  end

  @doc """
  Gets a single song.

  Raises `Ecto.NoResultsError` if the Song does not exist.

  ## Examples

      iex> get_song!(123)
      %Song{}

      iex> get_song!(456)
      ** (Ecto.NoResultsError)

  """
  def get_song!(id), do: Repo.get!(Song, id)
  def get_song(id), do: Repo.get(Song, id)

  @doc """
  Gets a song by its file GUID.

  ## Examples

      iex> get_song_by_guid("abc-123")
      %Song{}

      iex> get_song_by_guid("nonexistent")
      nil

  """
  def get_song_by_guid(guid), do: Repo.get_by(Song, file_guid: guid)

  @doc """
  Creates a song.

  ## Examples

      iex> create_song(%{field: value})
      {:ok, %Song{}}

      iex> create_song(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_song(attrs \\ %{}) do
    # Calculate the next order number for the disc
    attrs_with_order =
      if attrs[:disc] && !attrs[:order] do
        next_order =
          Song
          |> where(disc: ^attrs.disc)
          |> select([s], max(s.order))
          |> Repo.one()
          |> case do
            # First song on this disc
            nil -> 1
            max_order -> max_order + 1
          end

        Map.put(attrs, :order, next_order)
      else
        attrs
      end

    %Song{}
    |> Song.changeset(attrs_with_order)
    |> Repo.insert()
  end

  @doc """
  Updates a song.

  ## Examples

      iex> update_song(song, %{field: new_value})
      {:ok, %Song{}}

      iex> update_song(song, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_song(%Song{} = song, attrs) do
    song
    |> Song.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a song.

  ## Examples

      iex> delete_song(song)
      {:ok, %Song{}}

      iex> delete_song(song)
      {:error, %Ecto.Changeset{}}

  """
  def delete_song(%Song{} = song) do
    Repo.delete(song)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking song changes.

  ## Examples

      iex> change_song(song)
      %Ecto.Changeset{data: %Song{}}

  """
  def change_song(%Song{} = song, attrs \\ %{}) do
    Song.changeset(song, attrs)
  end

  def broadcast_song(song_id, user_nickname) do
    song = get_song!(song_id)

    StrangepathsWeb.Endpoint.broadcast("music:broadcast", "play_song", %{
      song_id: song.id,
      title: song.title,
      link: song.link,
      queued_by: user_nickname
    })
  end

  def queue_song(song_id, user_nickname) do
    MusicQueue.enqueue(song_id, user_nickname)
  end

  def get_music_queue do
    MusicQueue.get_state()
  end

  def next_song(song_id) do
    MusicQueue.next_song(song_id)
  end

  def toggle_repeat do
    MusicQueue.toggle_repeat()
  end

  # Admin functions for song management

  @doc """
  Toggle the unlocked status of a song (admin only).
  """
  def toggle_song_lock(song_id) do
    song = get_song!(song_id)

    update_song(song, %{unlocked: !song.unlocked})
  end

  def toggle_song_lyrics_lock(song_id) do
    song = get_song!(song_id)

    update_song(song, %{lyrics_unlocked: !song.lyrics_unlocked})
  end

  @doc """
  Update song order within its disc. Reorders siblings accordingly.
  """
  def update_song_order(song_id, new_order) do
    song = get_song!(song_id)
    old_order = song.order
    disc = song.disc

    # Get all songs in the same disc ordered by current order
    songs_in_disc = Song |> where(disc: ^disc) |> order_by(:order) |> Repo.all()

    # If moving down (new_order > old_order), shift songs between old and new down
    # If moving up (new_order < old_order), shift songs between new and old up
    updated_songs =
      cond do
        new_order > old_order ->
          # Moving down: decrement order for songs between old and new
          Enum.map(songs_in_disc, fn s ->
            cond do
              s.id == song_id -> {s, new_order}
              s.order > old_order && s.order <= new_order -> {s, s.order - 1}
              true -> {s, s.order}
            end
          end)

        new_order < old_order ->
          # Moving up: increment order for songs between new and old
          Enum.map(songs_in_disc, fn s ->
            cond do
              s.id == song_id -> {s, new_order}
              s.order >= new_order && s.order < old_order -> {s, s.order + 1}
              true -> {s, s.order}
            end
          end)

        true ->
          # No change in order
          Enum.map(songs_in_disc, fn s -> {s, s.order} end)
      end

    # Update all affected songs
    Enum.each(updated_songs, fn {s, new_ord} ->
      if s.order != new_ord do
        update_song(s, %{order: new_ord})
      end
    end)

    {:ok, get_song!(song_id)}
  end

  @doc """
  Update song metadata (title, text/lyrics).
  """
  def update_song_metadata(song_id, attrs) do
    song = get_song!(song_id)
    update_song(song, attrs)
  end

  def render_lyrics(song_id) do
    song = get_song!(song_id)
    Earmark.as_html!(song.text)
  end

  def list_content_pages do
    Repo.all(ContentPage)
  end

  def list_published_content_pages do
    ContentPage
    |> where(published: true)
    |> order_by(:title)
    |> Repo.all()
  end

  def get_content_page!(id), do: Repo.get!(ContentPage, id)

  def get_content_page_by_slug(slug) do
    Repo.get_by(ContentPage, slug: slug)
  end

  def create_content_page(attrs \\ %{}) do
    %ContentPage{}
    |> ContentPage.changeset(attrs)
    |> Repo.insert()
  end

  def update_content_page(page, attrs) do
    page
    |> ContentPage.changeset(attrs)
    |> Repo.update()
  end

  def delete_content_page(page) do
    Repo.delete(page)
  end

  # --- Content Folders ---

  def get_folder!(id), do: Repo.get!(ContentFolder, id)

  def create_folder(attrs) do
    %ContentFolder{}
    |> ContentFolder.changeset(attrs)
    |> Repo.insert()
  end

  def update_folder(%ContentFolder{} = folder, attrs) do
    folder
    |> ContentFolder.changeset(attrs)
    |> Repo.update()
  end

  def delete_folder(%ContentFolder{} = folder) do
    has_subfolders =
      ContentFolder
      |> where(parent_id: ^folder.id)
      |> Repo.exists?()

    has_pages =
      ContentPage
      |> where(folder_id: ^folder.id)
      |> Repo.exists?()

    if has_subfolders or has_pages do
      {:error, :not_empty}
    else
      Repo.delete(folder)
    end
  end

  def list_folder_contents(folder_id, opts \\ []) do
    published_only = Keyword.get(opts, :published_only, false)

    folders =
      ContentFolder
      |> where(parent_id: ^folder_id)
      |> order_by(:name)
      |> Repo.all()

    pages_query =
      ContentPage
      |> where(folder_id: ^folder_id)
      |> order_by(:title)

    pages_query =
      if published_only do
        pages_query |> where(published: true)
      else
        pages_query
      end

    pages = Repo.all(pages_query)

    %{folders: folders, pages: pages}
  end

  def list_root_folder_contents(opts \\ []) do
    published_only = Keyword.get(opts, :published_only, false)

    folders =
      ContentFolder
      |> where([f], is_nil(f.parent_id))
      |> order_by(:name)
      |> Repo.all()

    pages_query =
      ContentPage
      |> where([p], is_nil(p.folder_id))
      |> order_by(:title)

    pages_query =
      if published_only do
        pages_query |> where(published: true)
      else
        pages_query
      end

    pages = Repo.all(pages_query)

    %{folders: folders, pages: pages}
  end

  def list_all_folders do
    ContentFolder
    |> order_by(:name)
    |> Repo.all()
    |> Enum.map(fn folder ->
      path = get_folder_breadcrumbs(folder.id) |> Enum.map(& &1.name) |> Enum.join(" / ")
      %{id: folder.id, name: folder.name, path: path}
    end)
  end

  def get_folder_breadcrumbs(nil), do: []

  def get_folder_breadcrumbs(folder_id) do
    folder = Repo.get!(ContentFolder, folder_id)
    build_breadcrumbs(folder, [])
  end

  defp build_breadcrumbs(%ContentFolder{parent_id: nil} = folder, acc) do
    [folder | acc]
  end

  defp build_breadcrumbs(%ContentFolder{parent_id: parent_id} = folder, acc) do
    parent = Repo.get!(ContentFolder, parent_id)
    build_breadcrumbs(parent, [folder | acc])
  end

  def reorder_folder_contents(_folder_id, ordered_folder_ids, ordered_page_ids) do
    Repo.transaction(fn ->
      ordered_folder_ids
      |> Enum.with_index()
      |> Enum.each(fn {id, idx} ->
        from(f in ContentFolder, where: f.id == ^id)
        |> Repo.update_all(set: [sort_order: idx])
      end)

      ordered_page_ids
      |> Enum.with_index()
      |> Enum.each(fn {id, idx} ->
        from(p in ContentPage, where: p.id == ^id)
        |> Repo.update_all(set: [sort_order: idx])
      end)
    end)
  end

  def move_page_to_folder(page_id, target_folder_id) do
    page = Repo.get!(ContentPage, page_id)

    # Get max sort_order in target folder
    max_order =
      ContentPage
      |> where(folder_id: ^target_folder_id)
      |> select([p], max(p.sort_order))
      |> Repo.one() || -1

    page
    |> ContentPage.changeset(%{folder_id: target_folder_id, sort_order: max_order + 1})
    |> Repo.update()
  end

  def move_page_to_root(page_id) do
    page = Repo.get!(ContentPage, page_id)

    max_order =
      ContentPage
      |> where([p], is_nil(p.folder_id))
      |> select([p], max(p.sort_order))
      |> Repo.one() || -1

    page
    |> ContentPage.changeset(%{folder_id: nil, sort_order: max_order + 1})
    |> Repo.update()
  end

  def move_folder_to_parent(folder_id, target_parent_id) do
    folder = Repo.get!(ContentFolder, folder_id)

    # Cycle detection: walk up from target_parent_id, ensure we don't hit folder_id
    if target_parent_id && has_ancestor?(target_parent_id, folder_id) do
      {:error, :cycle}
    else
      max_order =
        if target_parent_id do
          ContentFolder
          |> where(parent_id: ^target_parent_id)
          |> select([f], max(f.sort_order))
          |> Repo.one() || -1
        else
          ContentFolder
          |> where([f], is_nil(f.parent_id))
          |> select([f], max(f.sort_order))
          |> Repo.one() || -1
        end

      folder
      |> ContentFolder.changeset(%{parent_id: target_parent_id, sort_order: max_order + 1})
      |> Repo.update()
    end
  end

  defp has_ancestor?(folder_id, target_ancestor_id) do
    case Repo.get(ContentFolder, folder_id) do
      nil -> false
      %ContentFolder{id: id} when id == target_ancestor_id -> true
      %ContentFolder{parent_id: nil} -> false
      %ContentFolder{parent_id: pid} -> has_ancestor?(pid, target_ancestor_id)
    end
  end

  @doc """
  Uploads an MP3 file for a song, generating a GUID for secure storage.
  Returns {:ok, guid} on success, {:error, reason} on failure.
  """
  def upload_song_file(song_id, upload) do
    song = get_song!(song_id)
    guid = Ecto.UUID.generate()

    music_dir = Path.join([:code.priv_dir(:strangepaths), "static", "uploads", "music"])
    File.mkdir_p!(music_dir)

    dest_path = Path.join(music_dir, "#{guid}")

    case File.cp(upload.path, dest_path) do
      :ok ->
        # Update song with new GUID and link

        case update_song(song, %{
               file_guid: guid,
               link: "/uploads/music/#{guid}"
             }) do
          {:ok, _song} -> {:ok, guid}
          error -> error
        end

      {:error, reason} ->
        {:error, "Failed to copy file: #{inspect(reason)}"}
    end
  end

  @doc """
  Searches Codex pages (ContentPage) by title and body content using hybrid ILIKE + pg_trgm matching.
  Returns list of maps with page info and snippets showing matching content.
  Only searches published pages that the user has access to.
  """
  def search_codex_pages(query, user_id) do
    alias Strangepaths.Accounts.User

    search_pattern = "%#{query}%"
    # Lower threshold = more fuzzy matches. Try 0.1-0.3 range.
    # 0.3 = default (strict), 0.2 = medium, 0.1 = loose
    similarity_threshold = 0.2

    # Check if user is dragon
    dragon_query = from(u in User, where: u.id == ^user_id and u.role == :dragon, select: u.id)
    is_dragon = Repo.exists?(dragon_query)

    # Build base query with hybrid search
    base_query =
      from(p in ContentPage,
        where:
          # Exact substring matching (fast path using ILIKE)
          ilike(p.title_stripped, ^search_pattern) or
          ilike(p.body_stripped, ^search_pattern) or
          # Fuzzy matching for typos (uses GIN trigram indexes)
          # similarity() is bidirectional and better for typo matching than word_similarity()
          fragment("similarity(?, ?) > ?", p.title_stripped, ^query, ^similarity_threshold) or
          fragment("similarity(?, ?) > ?", p.body_stripped, ^query, ^similarity_threshold),
        select: %{
          page_id: p.id,
          title: p.title,
          slug: p.slug,
          body: p.body_stripped,
          published: p.published
        }
      )

    # Apply permissions: only published pages unless user is dragon
    final_query =
      if is_dragon do
        base_query
      else
        from([p] in base_query, where: p.published == true)
      end

    # Execute query and format results
    final_query
    |> Repo.all()
    |> Enum.map(fn page ->
      # Determine if match was in title or body
      matched_in_title = String.contains?(String.downcase(page.title), String.downcase(query))

      # Extract snippet from body
      snippet = extract_codex_snippet(page.body, query, 200)

      %{
        page_id: page.page_id,
        title: page.title,
        slug: page.slug,
        matched_in_title: matched_in_title,
        snippet: snippet
      }
    end)
  end

  # Helper function to extract a snippet around the search term from Codex content
  defp extract_codex_snippet(content, query, max_length) do
    content = content || ""
    query_lower = String.downcase(query)
    content_lower = String.downcase(content)

    case :binary.match(content_lower, query_lower) do
      {pos, len} ->
        # Calculate start and end positions for snippet
        start_pos = max(0, pos - div(max_length - len, 2))
        end_pos = min(String.length(content), start_pos + max_length)

        # Adjust start_pos if we're at the end
        start_pos = max(0, end_pos - max_length)

        snippet = String.slice(content, start_pos, max_length)

        # Add ellipsis if truncated
        snippet =
          cond do
            start_pos > 0 && end_pos < String.length(content) -> "..." <> snippet <> "..."
            start_pos > 0 -> "..." <> snippet
            end_pos < String.length(content) -> snippet <> "..."
            true -> snippet
          end

        snippet

      :nomatch ->
        # Fallback: return first max_length characters
        content
        |> String.slice(0, max_length)
        |> then(fn s -> if String.length(content) > max_length, do: s <> "...", else: s end)
    end
  end
end
