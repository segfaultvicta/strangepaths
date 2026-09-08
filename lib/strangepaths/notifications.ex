defmodule Strangepaths.Notifications do
  @moduledoc """
  Opt-in "louder" activity cues (sound / OS notification / toast) layered on top of
  the site's quiet unread signals. `publish/3` is the single entry point: the four
  write paths (scenes, library, bbs, rumor) call it after a successful save.

  It resolves who may see the event, drops the actor, gates each remaining recipient
  on their saved `notif_*` preference columns, and sends a per-user `"activity"`
  broadcast on `"user:<id>:notifications"` carrying that recipient's resolved cue flags.
  Users with both flags off for the source receive nothing.
  """

  import Ecto.Query, warn: false

  require Logger

  alias Strangepaths.Repo
  alias Strangepaths.Accounts
  alias Strangepaths.Accounts.User
  alias Strangepaths.Scenes
  alias Strangepaths.Scenes.Scene
  alias StrangepathsWeb.Endpoint

  @excerpt_limit 140

  @type source :: :scene | :library | :bbs | :rumor

  # Safely executes a function, catching any exception and logging the error.
  # Never raises to the caller — always returns :ok.
  defp safely(fun) do
    try do
      fun.()
    rescue
      e ->
        Logger.error("Notifications builder failed: #{inspect(e)}")
        :ok
    catch
      kind, reason ->
        Logger.error("Notifications builder #{kind}: #{inspect(reason)}")
        :ok
    end
  end

  @type event ::
          :new_post | :new_thread | :body_edit | :marginalia | :node_create | :node_update

  @user_notif_fields [
    :id,
    :role,
    :notif_scene_sound,
    :notif_scene_web,
    :notif_library_sound,
    :notif_library_web,
    :notif_bbs_sound,
    :notif_bbs_web,
    :notif_rumor_sound,
    :notif_rumor_web
  ]

  # ---- payload builders --------------------------------------------------------

  # Collapse whitespace, drop markdown/diff markup, truncate with an ellipsis.
  defp excerpt(nil), do: ""

  defp excerpt(text) when is_binary(text) do
    cleaned =
      text
      # `body_diff_summary/2` output: unwrap [+ins+] / [-del-] to their inner words,
      # collapse its literal "..." separators to a single ellipsis.
      |> String.replace(~r/\[\+(.*?)\+\]/s, "\\1")
      |> String.replace(~r/\[-(.*?)-\]/s, "\\1")
      |> String.replace(~r/\.{3,}/, "… ")
      # markdown noise
      |> String.replace(~r/[*_`#>]/u, "")
      |> String.replace(~r/[\[\]]/u, "")
      |> String.replace(~r/\s+/u, " ")
      |> String.trim()

    if String.length(cleaned) > @excerpt_limit do
      String.slice(cleaned, 0, @excerpt_limit - 1) <> "…"
    else
      cleaned
    end
  end

  # ---- BBS ---------------------------------------------------------------

  def publish_bbs_new_thread(board, thread, post, actor) do
    safely(fn ->
      publish(:bbs, :new_thread, %{
        actor_id: actor.id,
        actor_name: post.display_name || actor.nickname,
        title: thread.title,
        excerpt: excerpt(post.content),
        url: "/bbs/#{board.slug}/#{thread.id}",
        context_key: "bbs_thread:#{thread.id}"
      })
    end)
  end

  def publish_bbs_new_post(thread, post, actor) do
    safely(fn ->
      thread = Repo.preload(thread, :board)

      publish(:bbs, :new_post, %{
        actor_id: actor.id,
        actor_name: post.display_name || actor.nickname,
        title: thread.title,
        excerpt: excerpt(post.content),
        url: "/bbs/#{thread.board.slug}/#{thread.id}",
        context_key: "bbs_thread:#{thread.id}"
      })
    end)
  end

  # ---- Library --------------------------------------------------------

  def publish_library_body_edit(folio, actor_id, diff_summary) do
    safely(fn ->
      actor = Accounts.get_user!(actor_id)

      publish(:library, :body_edit, %{
        actor_id: actor.id,
        actor_name: actor.nickname,
        title: folio.title,
        excerpt: excerpt(diff_summary),
        url: "/library/#{folio.slug}",
        context_key: "folio:#{folio.id}",
        folio: folio
      })
    end)
  end

  def publish_library_marginalia(folio, _entry, marginalia, actor) do
    safely(fn ->
      publish(:library, :marginalia, %{
        actor_id: actor.id,
        actor_name: actor.nickname,
        title: folio.title,
        excerpt: excerpt(marginalia.content),
        url: "/library/#{folio.slug}",
        context_key: "folio:#{folio.id}",
        folio: folio
      })
    end)
  end

  # ---- Scenes --------------------------------------------------------

  # Called from the scene LiveView right after SceneServer.broadcast_post/2 as
  # `publish_scene_post(%{post: post, scene: scene})`. The `when not is_nil(post.user_id)`
  # guard is the AC1.8 protection; the trailing `_` clause absorbs system posts.
  def publish_scene_post(%{post: post, scene: scene}) when not is_nil(post.user_id) do
    safely(fn ->
      actor = Accounts.get_user!(post.user_id)

      publish(:scene, :new_post, %{
        actor_id: actor.id,
        actor_name: actor.nickname,
        title: scene.name,
        excerpt: excerpt(post.content),
        url: "/scenes",
        context_key: "scene:#{scene.id}",
        scene: scene
      })
    end)
  end

  def publish_scene_post(_), do: :ok

  # ---- Rumor -------------------------------------------------------

  # event :: :node_create | :node_update. Called from RumorMapLive.Show, which
  # supplies the acting user (the Rumor context never receives it).
  def publish_rumor_node(event, node, actor) when event in [:node_create, :node_update] do
    safely(fn ->
      publish(:rumor, event, %{
        actor_id: actor.id,
        actor_name: actor.nickname,
        title: node.title || "a node",
        excerpt: excerpt(node.content),
        url: "/rumor?node=#{node.id}",
        context_key: "rumor"
      })
    end)
  end

  def publish_rumor_node(_, _, _), do: :ok

  # ---- recipient resolution -------------------------------------------------

  # Returns the list of candidate %User{} structs for a source, BEFORE actor
  # exclusion and preference gating. Each User struct carries its notif_* fields.
  defp candidates(:bbs, _meta), do: all_users()
  defp candidates(:rumor, _meta), do: all_users()

  defp candidates(:scene, %{scene: %Scene{} = scene}) do
    Enum.filter(all_users(), fn user -> Scenes.can_view_scene?(scene, user) end)
  end

  defp candidates(:library, %{folio: folio}) do
    if folio.is_private do
      author_and_dragons(folio.user_id)
    else
      all_users()
    end
  end

  defp all_users do
    Repo.all(
      from(u in User,
        select: ^@user_notif_fields
      )
    )
  end

  defp author_and_dragons(author_id) do
    Repo.all(
      from(u in User,
        where: u.id == ^author_id or u.role == :dragon,
        select: ^@user_notif_fields
      )
    )
  end

  # ---- preference gating --------------------------------------------------

  @doc false
  # Given a source atom, returns {sound_field, web_field} atoms.
  def pref_fields(:scene), do: {:notif_scene_sound, :notif_scene_web}
  def pref_fields(:library), do: {:notif_library_sound, :notif_library_web}
  def pref_fields(:bbs), do: {:notif_bbs_sound, :notif_bbs_web}
  def pref_fields(:rumor), do: {:notif_rumor_sound, :notif_rumor_web}

  # %User{} -> %{sound: bool, web: bool} for the given source.
  defp cues_for(user, source) do
    {sound_field, web_field} = pref_fields(source)
    %{sound: Map.fetch!(user, sound_field), web: Map.fetch!(user, web_field)}
  end

  defp entitled?(%{sound: sound, web: web}), do: sound == true or web == true

  # ---- publishing ---------------------------------------------------------

  @doc """
  Resolve recipients for `{source, event}`, exclude the actor, gate on each
  recipient's saved preferences, and broadcast one `"activity"` payload per
  surviving recipient. Always returns `:ok` (fire-and-forget; never raises to
  the caller — a broadcast failure must not roll back the write that triggered it).
  """
  @spec publish(source, event, map) :: :ok
  def publish(source, event, meta) do
    actor_id = Map.fetch!(meta, :actor_id)

    recipients =
      source
      |> candidates(meta)
      |> Enum.reject(fn u -> u.id == actor_id end)
      |> Enum.map(fn u -> {u, cues_for(u, source)} end)
      |> Enum.filter(fn {_u, cues} -> entitled?(cues) end)

    Enum.each(recipients, fn {user, cues} ->
      Endpoint.broadcast(
        "user:#{user.id}:notifications",
        "activity",
        payload(source, event, meta, cues)
      )
    end)

    :ok
  rescue
    # Defensive: publishing is best-effort and must never break the caller's write path.
    e ->
      Logger.error("Notifications.publish/3 failed: #{inspect(e)}")
      :ok
  catch
    kind, reason ->
      Logger.error("Notifications.publish/3 #{kind}: #{inspect(reason)}")
      :ok
  end

  defp payload(source, event, meta, cues) do
    %{
      source: source,
      event: event,
      title: Map.fetch!(meta, :title),
      excerpt: Map.get(meta, :excerpt, ""),
      url: Map.fetch!(meta, :url),
      context_key: Map.fetch!(meta, :context_key),
      actor_name: Map.fetch!(meta, :actor_name),
      cues: cues
    }
  end
end
