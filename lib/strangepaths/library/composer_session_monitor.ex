defmodule Strangepaths.Library.ComposerSessionMonitor do
  use GenServer
  require Logger

  alias Strangepaths.Library

  # State: %{monitor_ref => %{pid, folio_id, user_id, ops}}

  def start_link(_), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  # Called by the Composer LiveView on connected mount.
  def register(folio_id, user_id) do
    GenServer.call(__MODULE__, {:register, self(), folio_id, user_id})
  end

  # Called after every operation to keep the ops snapshot current.
  def sync_ops(folio_id, ops) do
    GenServer.cast(__MODULE__, {:sync_ops, self(), folio_id, ops})
  end

  # Called on clean terminate so the monitor doesn't double-flush.
  def unregister(folio_id) do
    GenServer.cast(__MODULE__, {:unregister, self(), folio_id})
  end

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call({:register, pid, folio_id, user_id}, _from, state) do
    ref = Process.monitor(pid)
    entry = %{pid: pid, folio_id: folio_id, user_id: user_id, ops: []}
    {:reply, :ok, Map.put(state, ref, entry)}
  end

  @impl true
  def handle_cast({:sync_ops, pid, folio_id, ops}, state) do
    case find_ref(state, pid, folio_id) do
      nil -> {:noreply, state}
      ref -> {:noreply, put_in(state, [ref, :ops], ops)}
    end
  end

  def handle_cast({:unregister, pid, folio_id}, state) do
    case find_ref(state, pid, folio_id) do
      nil -> {:noreply, state}
      ref ->
        Process.demonitor(ref, [:flush])
        {:noreply, Map.delete(state, ref)}
    end
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, reason}, state) do
    case Map.pop(state, ref) do
      {nil, state} ->
        {:noreply, state}

      {%{folio_id: folio_id, user_id: user_id, ops: ops}, state} ->
        Logger.info(
          "[FolioFlush] monitor :DOWN folio=#{folio_id} user=#{user_id} ops=#{length(ops)} reason=#{inspect(reason)}"
        )
        flush_and_release(folio_id, user_id, ops)
        {:noreply, state}
    end
  end

  defp find_ref(state, pid, folio_id) do
    Enum.find_value(state, fn {ref, entry} ->
      if entry.pid == pid and entry.folio_id == folio_id, do: ref
    end)
  end

  defp flush_and_release(folio_id, user_id, ops) do
    if ops != [] do
      try do
        summary = build_count_summary(ops)
        detail = build_entry_detail(ops)
        Library.record_entries_edit(folio_id, user_id, summary, detail)

        Logger.info(
          "[FolioFlush] monitor flush folio=#{folio_id} user=#{user_id} ops=#{length(ops)} result=ok summary=#{inspect(summary)}"
        )
      rescue
        e ->
          Logger.error(
            "[FolioFlush] monitor flush folio=#{folio_id} user=#{user_id} ops=#{length(ops)} result=raised class=#{inspect(e.__struct__)} message=#{Exception.message(e)}"
          )
          Logger.error(Exception.format(:error, e, __STACKTRACE__))
      end
    else
      Logger.info(
        "[FolioFlush] monitor flush folio=#{folio_id} user=#{user_id} ops=0 result=noop"
      )
    end

    Library.release_entries_lock(folio_id)
  end

  defp build_count_summary(ops) do
    posts_added  = Enum.count(ops, &(&1.op == :added_post))
    notes_added  = Enum.count(ops, &(&1.op == :added_note))
    notes_edited = Enum.count(ops, &(&1.op == :edited_note))
    deleted      = Enum.count(ops, &(&1.op in [:deleted_post, :deleted_note]))
    reordered    = Enum.any?(ops, &(&1.op == :reordered))

    [
      posts_added  > 0 && "added #{posts_added} post#{if posts_added == 1, do: "", else: "s"}",
      notes_added  > 0 && "added #{notes_added} note#{if notes_added == 1, do: "", else: "s"}",
      notes_edited > 0 && "edited #{notes_edited} note#{if notes_edited == 1, do: "", else: "s"}",
      deleted      > 0 && "deleted #{deleted} entr#{if deleted == 1, do: "y", else: "ies"}",
      reordered            && "reordered entries"
    ]
    |> Enum.filter(& &1)
    |> Enum.join(", ")
  end

  defp build_entry_detail(ops) do
    added_posts  = ops |> Enum.filter(&(&1.op == :added_post))  |> Enum.map(& &1.label)
    added_notes  = ops |> Enum.filter(&(&1.op == :added_note))  |> Enum.map(& &1.content)
    deleted_post = ops |> Enum.filter(&(&1.op == :deleted_post)) |> Enum.map(& &1.label)
    deleted_note = ops |> Enum.filter(&(&1.op == :deleted_note)) |> Enum.map(& &1.content)
    edited_notes = ops |> Enum.filter(&(&1.op == :edited_note)) |> Enum.map(& &1.content)
    reordered    = Enum.any?(ops, &(&1.op == :reordered))

    [
      if(added_posts  != [], do: "added: #{Enum.join(added_posts, ", ")}"),
      if(added_notes  != [], do: Enum.map_join(added_notes, ", ", &"added note: \"#{&1}\"")),
      if(deleted_post != [], do: "deleted: #{Enum.join(deleted_post, ", ")}"),
      if(deleted_note != [], do: Enum.map_join(deleted_note, ", ", &"deleted note: \"#{&1}\"")),
      if(edited_notes != [], do: Enum.map_join(edited_notes, ", ", &"edited note: \"#{&1}\"")),
      if(reordered,           do: "reordered entries"),
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" · ")
  end
end
