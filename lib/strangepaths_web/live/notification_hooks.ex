defmodule StrangepathsWeb.NotificationHooks do
  @moduledoc """
  `on_mount` hook attached to every LiveView via `live_session` in the router.

  On a connected mount with a logged-in user it:
    * subscribes the LiveView process to "user:USER_ID:notifications", and
    * attaches a `:handle_info` lifecycle hook that forwards "activity" broadcasts
      to the client as `push_event(socket, "activity", payload)` and lets every other
      message fall through to the LiveView untouched.

  Dead (disconnected) mounts and logged-out visitors do nothing.
  """
  import Phoenix.LiveView, only: [connected?: 1, attach_hook: 4, push_event: 3]

  alias Strangepaths.Accounts

  def on_mount(:subscribe, _params, session, socket) do
    socket =
      if token = session["user_token"] do
        case Accounts.get_user_by_session_token(token) do
          %{id: user_id} when is_integer(user_id) ->
            maybe_subscribe(socket, user_id)

          _ ->
            socket
        end
      else
        socket
      end

    {:cont, socket}
  end

  defp maybe_subscribe(socket, user_id) do
    if connected?(socket) do
      topic = "user:#{user_id}:notifications"
      StrangepathsWeb.Endpoint.subscribe(topic)

      attach_hook(socket, :activity_notifications, :handle_info, fn message, sock ->
        handle_activity(message, sock, topic)
      end)
    else
      socket
    end
  end

  # The one message this hook consumes.
  defp handle_activity(
         %Phoenix.Socket.Broadcast{topic: topic, event: "activity", payload: payload},
         socket,
         topic
       ) do
    {:halt, push_event(socket, "activity", payload)}
  end

  # Everything else — other broadcasts on the topic, and every unrelated handle_info
  # message the LiveView expects to handle itself — passes straight through.
  defp handle_activity(_message, socket, _topic), do: {:cont, socket}
end
