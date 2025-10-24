defmodule Strangepaths.Site.MusicQueue do
  use GenServer
  require Logger

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc "Add a song to the queue"
  def enqueue(song_id, queued_by) do
    IO.puts("in enqueue, song_id: #{song_id}, queued_by: #{queued_by}")
    GenServer.call(__MODULE__, {:enqueue, song_id, queued_by})
  end

  @doc "Get current state (now playing + queue)"
  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  @doc "Mark current song as finished, advance to next. Only advances if song_id matches the currently playing song."
  def next_song(song_id) do
    GenServer.call(__MODULE__, {:next_song, song_id})
  end

  @doc "Clear the entire queue"
  def clear_queue do
    GenServer.call(__MODULE__, :clear_queue)
  end

  # Server Callbacks

  @impl true
  def init(_) do
    # Schedule periodic check for song completion every 10 seconds
    schedule_playback_check()

    {:ok,
     %{
       now_playing: nil,
       started_at: nil,
       queue: [],
       history: [],
       timer_ref: nil
     }}
  end

  @impl true
  def handle_call({:enqueue, song_id, queued_by}, _from, state) do
    case Strangepaths.Site.get_song(song_id) do
      nil ->
        {:reply, {:error, :song_not_found}, state}

      song ->
        queue_item = %{
          song: song,
          queued_by: queued_by,
          queued_at: DateTime.utc_now()
        }

        new_state =
          if state.now_playing == nil do
            # Nothing playing, start immediately
            started_at = DateTime.utc_now()
            broadcast_now_playing(queue_item, 0)
            %{state | now_playing: queue_item, started_at: started_at}
          else
            # Add to queue
            %{state | queue: state.queue ++ [queue_item]}
          end

        broadcast_queue_update(new_state)
        {:reply, {:ok, new_state}, new_state}
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    # Calculate current playback position
    state_with_position =
      if state.now_playing && state.started_at do
        elapsed_seconds = DateTime.diff(DateTime.utc_now(), state.started_at, :second)
        Map.put(state, :current_position, elapsed_seconds)
      else
        Map.put(state, :current_position, 0)
      end

    {:reply, state_with_position, state}
  end

  @impl true
  def handle_call({:next_song, song_id}, _from, state) do
    # Only advance if the song_id matches the currently playing song
    case state.now_playing do
      nil ->
        # Nothing playing, ignore
        {:reply, {:error, :nothing_playing}, state}

      %{song: %{id: ^song_id}} ->
        # Song IDs match, advance to next
        new_state = advance_queue(state)
        {:reply, {:ok, new_state}, new_state}

      %{song: %{id: other_id}} ->
        # Different song is playing now, ignore (already advanced)
        {:reply, {:error, :song_already_changed, other_id}, state}
    end
  end

  @impl true
  def handle_call(:clear_queue, _from, state) do
    history =
      if state.now_playing do
        # Keep last 50
        [state.now_playing | state.history] |> Enum.take(50)
      else
        state.history
      end

    new_state = %{
      state
      | queue: [],
        now_playing: nil,
        started_at: nil,
        history: history,
        timer_ref: nil
    }

    broadcast_stopped()
    broadcast_queue_update(new_state)
    {:reply, {:ok, new_state}, new_state}
  end

  @impl true
  def handle_info(:auto_advance, state) do
    new_state = advance_queue(state)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:check_playback, state) do
    # Periodic check to see if current song should have ended
    # This replaces the need for arbitrary 5-minute timeout
    schedule_playback_check()

    new_state =
      if state.now_playing && state.started_at do
        elapsed = DateTime.diff(DateTime.utc_now(), state.started_at, :second)

        # Assume songs are max 6 minutes (360 seconds) unless we have duration data
        # TODO: Store actual song duration in DB or extract from MP3 metadata
        max_duration = 360

        if elapsed > max_duration do
          advance_queue(state)
        else
          state
        end
      else
        state
      end

    {:noreply, new_state}
  end

  # Private Functions

  defp schedule_playback_check do
    # Check every 10 seconds if the song should have ended
    Process.send_after(self(), :check_playback, :timer.seconds(10))
  end

  defp advance_queue(state) do
    # Cancel any existing timer
    if state.timer_ref, do: Process.cancel_timer(state.timer_ref)

    # Move current song to history
    history =
      if state.now_playing do
        # Keep last 50
        [state.now_playing | state.history] |> Enum.take(50)
      else
        state.history
      end

    new_state =
      case state.queue do
        [] ->
          # Queue empty, stop playing
          broadcast_stopped()
          %{state | now_playing: nil, started_at: nil, history: history, timer_ref: nil}

        [next | rest] ->
          # Play next song from the beginning
          started_at = DateTime.utc_now()
          broadcast_now_playing(next, 0)

          # Schedule auto-advance as fallback (5 minutes + 10 second buffer)
          # This ensures the queue doesn't get stuck if all browsers close
          timer_ref =
            Process.send_after(self(), :auto_advance, :timer.minutes(5) + :timer.seconds(10))

          %{
            state
            | now_playing: next,
              started_at: started_at,
              queue: rest,
              history: history,
              timer_ref: timer_ref
          }
      end

    # Always broadcast queue update after advancing
    broadcast_queue_update(new_state)
    new_state
  end

  defp broadcast_now_playing(queue_item, start_position_seconds) do
    StrangepathsWeb.Endpoint.broadcast("music:broadcast", "play_song", %{
      song_id: queue_item.song.id,
      title: queue_item.song.title,
      link: queue_item.song.link,
      queued_by: queue_item.queued_by,
      start_position: start_position_seconds
    })
  end

  defp broadcast_queue_update(state) do
    StrangepathsWeb.Endpoint.broadcast("music:broadcast", "queue_update", %{
      now_playing: format_queue_item(state.now_playing),
      queue: Enum.map(state.queue, &format_queue_item/1),
      queue_length: length(state.queue)
    })
  end

  defp broadcast_stopped do
    StrangepathsWeb.Endpoint.broadcast("music:broadcast", "stopped", %{})
  end

  defp format_queue_item(nil), do: nil

  defp format_queue_item(item) do
    %{
      title: item.song.title,
      queued_by: item.queued_by,
      queued_at: item.queued_at
    }
  end
end
