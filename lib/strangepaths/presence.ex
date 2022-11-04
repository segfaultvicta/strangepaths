defmodule Strangepaths.Presence do
  use Phoenix.Presence,
    otp_app: :strangepaths,
    pubsub_server: Strangepaths.PubSub
end
