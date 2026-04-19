defmodule Strangepaths.QueryTracker do
  use GenServer
  require Logger

  @report_interval 60_000
  @slow_query_ms 100
  @pool_pressure_ms 50

  def start_link(_), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  def init(_) do
    :telemetry.attach(
      "strangepaths-query-tracker",
      [:strangepaths, :repo, :query],
      &__MODULE__.handle_query/4,
      nil
    )

    schedule_report()
    {:ok, %{counts: %{}, pool_pressure: 0}}
  end

  def handle_query(_, measurements, metadata, _) do
    total_ms = div(measurements.total_time, 1_000_000)
    queue_ms = div(Map.get(measurements, :queue_time, 0) || 0, 1_000_000)
    source = metadata[:source] || "unknown"
    fingerprint = query_fingerprint(metadata[:query], source)

    if total_ms >= @slow_query_ms do
      Logger.warning("[SLOW QUERY #{total_ms}ms source=#{source}] #{String.slice(metadata[:query] || "", 0, 120)}")
    end

    if queue_ms >= @pool_pressure_ms do
      Logger.warning("[POOL PRESSURE queue=#{queue_ms}ms] #{source}")
    end

    GenServer.cast(__MODULE__, {:record, fingerprint, queue_ms >= @pool_pressure_ms})
  end

  # Produces a short human-readable key distinguishing query patterns on the same table.
  # Pulls the WHERE clause start so "users WHERE id = $1" and "users WHERE public_ascension"
  # show up as separate entries.
  defp query_fingerprint(nil, source), do: source
  defp query_fingerprint(query, source) do
    where =
      case Regex.run(~r/WHERE \(([^)]{0,40})/i, query) do
        [_, clause] -> " WHERE (#{clause})"
        _ -> ""
      end

    source <> where
  end

  def handle_cast({:record, source, pool_pressure}, state) do
    counts = Map.update(state.counts, source, 1, & &1 + 1)
    pressure = if pool_pressure, do: state.pool_pressure + 1, else: state.pool_pressure
    {:noreply, %{state | counts: counts, pool_pressure: pressure}}
  end

  def handle_info(:report, state) do
    total = state.counts |> Map.values() |> Enum.sum()
    top = state.counts |> Enum.sort_by(fn {_, v} -> -v end) |> Enum.take(10)

    Logger.info(
      "[QUERY REPORT] #{total} queries in last 60s, #{state.pool_pressure} with pool pressure. " <>
        "Top tables: #{inspect(top)}"
    )

    schedule_report()
    {:noreply, %{state | counts: %{}, pool_pressure: 0}}
  end

  defp schedule_report, do: Process.send_after(self(), :report, @report_interval)
end
