defmodule StrangepathsWeb.MusicBroadcast do
  @moduledoc """
  Helper module for LiveViews to subscribe to and forward music broadcasts
  to the MusicPlayerComponent.

  Usage in your LiveView:

      import StrangepathsWeb.MusicBroadcast

      def mount(_params, session, socket) do
        subscribe_to_music()
        # ... rest of mount
      end

      # Add this catch-all for music events
      def handle_info(%{event: event} = msg, socket) do
        forward_music_event(event, msg, socket)
      end
  """

  @doc """
  Subscribe to music broadcast events and track presence.
  Call this in your LiveView's mount/3 and pass the socket.
  """
  def subscribe_to_music(socket \\ nil) do
    StrangepathsWeb.Endpoint.subscribe("music:broadcast")
    StrangepathsWeb.Endpoint.subscribe("music")

    # Track presence if socket and user are available
    if socket && socket.assigns[:current_user] do
      user = socket.assigns.current_user

      {:ok, _} =
        Strangepaths.Presence.track(
          self(),
          "music",
          user.id,
          %{nickname: user.nickname}
        )
    end
  end

  @doc """
  Forward client events (from JavaScript/buttons) to the MusicPlayerComponent.
  Use this in your handle_event/3 like this:

      def handle_event(event, params, socket) do
        case forward_music_client_event(event, params, socket) do
          :not_music_event ->
            # Handle your own events
            {:noreply, socket}
          result ->
            result
        end
      end
  """
  def forward_music_client_event("song_ended", %{"song_id" => song_id}, socket) do
    Phoenix.LiveView.send_update(StrangepathsWeb.MusicPlayerComponent,
      id: "music-player",
      song_ended: song_id
    )

    {:noreply, socket}
  end

  def forward_music_client_event(_event, _params, _socket) do
    :not_music_event
  end

  @doc """
  Forward music broadcast events to the MusicPlayerComponent.
  Returns {:noreply, socket} or :not_music_event if it's not a music event.

  Use this in your handle_info/2 like this:

      def handle_info(msg, socket) do
        case forward_music_event(msg, socket) do
          :not_music_event ->
            # Handle other events
            {:noreply, socket}
          result ->
            result
        end
      end
  """

  def forward_music_event(
        %Phoenix.Socket.Broadcast{event: "presence_diff", topic: "music"},
        socket
      ) do
    online_users =
      Strangepaths.Presence.list("music")
      |> Enum.map(fn {_id, %{metas: [meta | _]}} -> meta.nickname end)
      |> Enum.sort()

    Phoenix.LiveView.send_update(StrangepathsWeb.MusicPlayerComponent,
      id: "music-player",
      online_users: online_users
    )

    {:noreply, socket}
  end

  def forward_music_event(%{event: "queue_update", payload: payload}, socket) do
    Phoenix.LiveView.send_update(StrangepathsWeb.MusicPlayerComponent,
      id: "music-player",
      queue_update: payload
    )

    {:noreply, socket}
  end

  def forward_music_event(%{event: "play_song", payload: payload}, socket) do
    Phoenix.LiveView.send_update(StrangepathsWeb.MusicPlayerComponent,
      id: "music-player",
      play_song: payload
    )

    {:noreply, socket}
  end

  def forward_music_event(%{event: "song_ended", payload: payload}, socket) do
    Phoenix.LiveView.send_update(StrangepathsWeb.MusicPlayerComponent,
      id: "music-player",
      song_ended: payload
    )

    {:noreply, socket}
  end

  def forward_music_event(_msg, _socket) do
    # Not a music event
    :not_music_event
  end
end
