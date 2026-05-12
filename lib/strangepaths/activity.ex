defmodule Strangepaths.Activity do
  alias Strangepaths.{Rumor, BBS, Library, Scenes}

  defstruct [:type, :timestamp, :actor_name, :title, :body, :url]

  def list_recent_activity(user, limit, type_filter \\ nil)

  def list_recent_activity(_user, limit, :rumor_change), do: fetch_rumor_changes(limit)
  def list_recent_activity(_user, limit, :bbs_post), do: fetch_bbs_posts(limit)
  def list_recent_activity(_user, limit, :library) do
    (fetch_marginalia(limit) ++ fetch_folio_updates(limit))
    |> Enum.sort_by(& &1.timestamp, {:desc, DateTime})
    |> Enum.take(limit)
  end
  def list_recent_activity(user, limit, :archived_scene), do: fetch_archived_scenes(user, limit)

  def list_recent_activity(user, limit, nil) do
    per_source = limit * 2

    (fetch_rumor_changes(per_source) ++
       fetch_bbs_posts(per_source) ++
       fetch_marginalia(per_source) ++
       fetch_folio_updates(per_source) ++
       fetch_archived_scenes(user, per_source))
    |> Enum.sort_by(& &1.timestamp, {:desc, DateTime})
    |> Enum.take(limit)
  end

  defp fetch_rumor_changes(limit) do
    Rumor.list_recent_changes(limit)
    |> Enum.reject(&(&1.action == "node_moved"))
    |> Enum.map(&rumor_to_activity/1)
  end

  defp fetch_bbs_posts(limit) do
    BBS.list_recent_posts(limit)
    |> Enum.map(fn p ->
      %__MODULE__{
        type: :bbs_post,
        timestamp: to_utc(p.posted_at),
        actor_name: p.display_name,
        title: p.thread_title,
        body: String.slice(p.content, 0, 120),
        url: "/bbs/#{p.board_slug}/#{p.thread_id}"
      }
    end)
  end

  defp fetch_marginalia(limit) do
    Library.list_recent_marginalia(limit)
    |> Enum.map(fn m ->
      %__MODULE__{
        type: :marginalia,
        timestamp: to_utc(m.inserted_at),
        actor_name: m.name,
        title: "Comment on \"#{m.folio_title}\"",
        body: String.slice(m.content, 0, 120),
        url: "/library/#{m.folio_slug}"
      }
    end)
  end

  defp fetch_folio_updates(limit) do
    Library.list_recent_folio_edits(limit)
    |> Enum.map(fn edit ->
      label = if edit.kind == "body", do: "Prolegomenon edited", else: "Entries updated"

      %__MODULE__{
        type: :folio_update,
        timestamp: to_utc(edit.inserted_at),
        actor_name: edit.editor_nickname,
        title: "#{label}: #{edit.folio_title}",
        body: edit.summary && String.slice(edit.summary, 0, 200),
        url: "/library/#{edit.folio_slug}"
      }
    end)
  end

  defp fetch_archived_scenes(user, limit) do
    Scenes.list_recent_archived_scenes(user, limit)
    |> Enum.map(fn s ->
      %__MODULE__{
        type: :archived_scene,
        timestamp: to_utc(s.archived_at),
        actor_name: nil,
        title: "Scene archived: #{s.name}",
        body: if(s.tags != [], do: Enum.join(s.tags, ", "), else: nil),
        url: "/scenes/archives/#{s.slug}"
      }
    end)
  end

  defp rumor_to_activity(entry) do
    %__MODULE__{
      type: :rumor_change,
      timestamp: to_utc(entry.inserted_at),
      actor_name: entry.actor_nickname,
      title: rumor_title(entry),
      body: rumor_body(entry),
      url: "/rumor"
    }
  end

  defp rumor_title(%{action: "node_created", node_title: t}), do: "Node created: #{t}"
  defp rumor_title(%{action: "node_updated", node_title: t}), do: "Node updated: #{t}"
  defp rumor_title(%{action: "node_deleted", node_title: t}), do: "Node deleted: #{t}"

  defp rumor_title(%{action: "connection_created", details: d}),
    do: "Connection: #{d["from"]} → #{d["to"]}"

  defp rumor_title(%{action: "connection_updated", details: d}),
    do: "Connection updated: #{d["from"]} → #{d["to"]}"

  defp rumor_title(%{action: "connection_deleted", details: d}),
    do: "Connection removed: #{d["from"]} → #{d["to"]}"

  defp rumor_title(entry), do: entry.action

  defp rumor_body(%{action: "node_updated", details: %{"changes" => changes}})
       when is_list(changes) do
    changes
    |> Enum.map(&format_node_change/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.join("; ")
    |> case do
      "" -> nil
      s -> s
    end
  end

  defp rumor_body(_), do: nil

  defp format_node_change(%{"field" => "content", "from" => from, "to" => to}) do
    case Rumor.Diff.word_diff(from, to) do
      nil ->
        nil

      segments ->
        text =
          segments
          |> Enum.map(fn
            :sep -> " ... "
            {:eq, w} -> w
            {:del, w} -> "[-#{w}-]"
            {:ins, w} -> "[+#{w}+]"
          end)
          |> Enum.join(" ")
          |> String.replace(" ... ", "...")

        if String.length(text) > 300, do: "(content updated)", else: text
    end
  end

  defp format_node_change(%{"field" => field, "from" => from, "to" => to}) do
    "#{field}: #{inspect(from)} → #{inspect(to)}"
  end

  defp format_node_change(_), do: nil

  defp to_utc(%DateTime{} = dt), do: dt
  defp to_utc(%NaiveDateTime{} = ndt), do: DateTime.from_naive!(ndt, "Etc/UTC")
end
