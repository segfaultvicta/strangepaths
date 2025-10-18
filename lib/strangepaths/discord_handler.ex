defmodule Strangepaths.DiscordHandler do
  @behaviour Nostrum.Consumer

  # alias Nostrum.Api.Message

  def handle_event({:MESSAGE_CREATE, msg, _ws_state}) do
    case msg.content do
      _ ->
        :ignore
    end
  end

  def handle_event(_), do: :ok
end
