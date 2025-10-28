defmodule StrangepathsWeb.Scenes do
  use StrangepathsWeb, :live_view

  import StrangepathsWeb.MusicBroadcast

  # need to have a concept of "scenes" that can be created by anybody,
  # but only closed by me; scenes are archived once they have concluded.
  # some scenes are ongoing and do not close, like the side-channel scenes
  # with the stars. on which note: scenes can be locked such that only one
  # (or maybe more, I want to leave my options open) user can see that they exist.
  # "OOC Chat" is a scene to which all online users are participants.
  # Much if not all of the functionality of the Ascension page and Discord interop
  # is going to get folded in to the Scenes UX.

  @impl true
  def mount(_params, session, socket) do
    socket = assign_defaults(session, socket)
    subscribe_to_music(socket)

    # hmm. do I want to forget the concept of an "ascended" user, and instead
    # let any user formally Join a Scene and that makes them show up in that
    # scene's userlist? (Or it could be that if you've ever posted in a scene
    # that means you've Joined the scene. Either way, I should load users here)

    {:ok, socket}
  end

  @impl true
  def handle_event(event, params, socket) do
    case forward_music_client_event(event, params, socket) do
      :not_music_event ->
        handle_scene_event(event, params, socket)

      result ->
        result
    end
  end

  defp handle_scene_event(event, params, socket) do
    IO.puts(
      "unhandled event #{event} with params #{inspect(params)} in state #{socket.assigns.state}"
    )

    {:noreply, socket}
  end

  # Handle music broadcasts
  @impl true
  def handle_info(msg, socket) do
    case forward_music_event(msg, socket) do
      :not_music_event ->
        # Fall through to ascension update handler
        handle_scene_info(msg, socket)

      result ->
        result
    end
  end

  defp handle_scene_info(msg, socket) do
    IO.puts("unhandled message #{inspect(msg)} in state #{socket.assigns.state}")
    {:noreply, socket}
  end
end
