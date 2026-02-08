defmodule StrangepathsWeb.MusicPlayerComponent do
  use StrangepathsWeb, :live_component

  @impl true
  def mount(socket) do
    {:ok, assign(socket, :initialized, false)}
  end

  @impl true
  def update(assigns, socket) do
    # Handle forwarded events from parent LiveView via send_update
    socket =
      cond do
        Map.has_key?(assigns, :online_users) ->
          assign(socket, :online_users, assigns.online_users)

        Map.has_key?(assigns, :song_ended) ->
          # Call next_song with the song_id
          Strangepaths.Site.next_song(assigns.song_ended)
          socket

        Map.has_key?(assigns, :queue_update) ->
          queue_state = Strangepaths.Site.get_music_queue()
          assign(socket, :music_queue, queue_state)

        Map.has_key?(assigns, :play_song) ->
          push_event(socket, "play_song", assigns.play_song)

        Map.has_key?(assigns, :stopped) ->
          push_event(socket, "stopped", %{})

        true ->
          # Standard update from parent re-render (e.g., typing in Scenes)
          # Only initialize on first update, not on every parent re-render
          if socket.assigns[:initialized] do
            # Already initialized, just pass through without syncing playback
            socket
          else
            # First update after mount - load queue state and sync playback
            queue_state = Strangepaths.Site.get_music_queue()

            # If there's a song playing, push event to start it at current position
            socket =
              if queue_state.now_playing && queue_state.current_position do
                push_event(socket, "play_song", %{
                  song_id: queue_state.now_playing.song.id,
                  title: queue_state.now_playing.song.title,
                  link: queue_state.now_playing.song.link,
                  queued_by: queue_state.now_playing.queued_by,
                  start_position: queue_state.current_position
                })
              else
                socket
              end

            socket
            |> assign(:music_queue, queue_state)
            |> assign(:online_users, get_presence_list())
            |> assign(:initialized, true)
          end
      end

    {:ok, assign(socket, assigns)}
  end

  defp get_presence_list do
    Strangepaths.Presence.list("music")
    |> Enum.map(fn {_id, %{metas: [meta | _]}} -> meta.nickname end)
    |> Enum.sort()
  end

  @impl true
  def render(assigns) do
    ~H"""
      <div id="music-player" style="z-index: 100;" class="fixed bottom-0 left-0 right-0 bg-black/90 backdrop-blur border-t border-purple-500/30 p-4" phx-hook="MusicPlayer" phx-target={@myself}>
        <audio id="audio-player" class="hidden" preload="none"></audio>
        <div class="container mx-auto flex items-center gap-4">
          <%= if @current_user != nil and @current_user.role == :dragon do %>
            <button id="clear_queue" data-confirm="Confirm queue clear?" phx-click="clear_queue" class="text-red-500">✘</button>
            <button id="emit_message" phx-click="emit_message" class="">🎉</button>
          <% end %>

          <button id="manual-play-btn" class="hidden text-purple-600">
            ▶
          </button>

          <!-- Now Playing -->
          <div class="flex items-center gap-4 mb-2">
            <div class="flex-1">
              <%= if @music_queue.now_playing do %>
                <div class="text-sm font-medium text-purple-300" id="song-title"><%= @music_queue.now_playing.song.title %></div>
                <div class="text-xs text-gray-500" id="queued-by">Queued by <%= @music_queue.now_playing.queued_by %></div>
              <% else %>
                <div class="text-sm font-medium text-gray-500" id="song-title">No song playing</div>
                <div class="text-xs text-gray-500" id="queued-by"></div>
              <% end %>
            </div>
          </div>

          <!-- Hidden div for queue tooltip content -->
          <div id="queue-tooltip" style="display: none;">
            <div class="text-left text-sm">
              <%= if length(@music_queue.queue) == 0 do %>
                <div class="text-gray-400">Queue is empty</div>
              <% else %>
                <%= for {item, i} <- Enum.with_index(@music_queue.queue, 1) do %>
                  <div><%= i %>. <%= item.song.title %> <span class="text-gray-400">(Queued by <%= item.queued_by %>)</span></div>
                <% end %>
              <% end %>
            </div>
          </div>

          <!-- Hidden div for listeners tooltip content -->
          <div id="listeners-tooltip" style="display: none;">
            <div class="text-left text-sm">
              <%= for user <- @online_users do %>
                <div>• <%= user %></div>
              <% end %>
            </div>
          </div>

          <!-- Element with tooltip -->
          <span
            class="text-xs cursor-help text-gray-600 hover:text-gray-500"
            phx-hook="TooltipUpdater"
            data-tooltip-template="queue-tooltip"
            id="queue-tooltip-trigger"
          >
            <details class="text-xs">
              <summary class="cursor-pointer text-gray-500">Up next: <span id="queue-count"><%= length(@music_queue.queue) %></span> songs</summary>
              <ul id="queue-list" class="mt-2 space-y-1 text-gray-400">
                <%= for {item, i} <- Enum.with_index(@music_queue.queue) do %>
                  <li><%= i + 1 %>. <%= item.song.title %> (by <%= item.queued_by %>)</li>
                <% end %>
              </ul>
            </details>
          </span>

          <!-- Online Listeners -->
          <%= if assigns[:online_users] && length(@online_users) > 0 do %>
            <span
              class="text-xs cursor-help text-gray-500 hover:text-gray-300"
              phx-hook="TooltipUpdater"
              data-tooltip-template="listeners-tooltip"
              id="listeners-tooltip-trigger"
            >
              <details class="text-xs">
                <summary class="cursor-pointer text-gray-500">
                  <i class="fa-solid fa-users"></i> <%= length(@online_users) %> listening
                </summary>
                <ul class="mt-2 space-y-1 text-gray-400">
                  <%= for user <- @online_users do %>
                    <li><i class="fa-solid fa-circle text-green-500 text-[6px]"></i> <%= user %></li>
                  <% end %>
                </ul>
              </details>
            </span>
          <% end %>

          <!-- Volume -->
          <input type="range" id="volume-control" min="0" max="100" value="50"
                class="w-24 h-1 bg-gray-700 rounded-lg appearance-none cursor-pointer">

          <div class="flex-1 relative">
            <div class="h-1 bg-gradient-to-r from-gray-900 via-gray-800 to-gray-900 rounded-full relative overflow-hidden">
              <div class="absolute inset-0 bg-gradient-to-r from-transparent via-purple-500/20 to-transparent animate-pulse"></div>
              <div
                id="progress-fill"
                class="absolute h-full bg-gradient-to-r from-purple-600 to-pink-500 rounded-full shadow-lg shadow-purple-500/50"
                style="width: 0%"
              ></div>
            </div>
          </div>
        </div>
      </div>
    """
  end
end
