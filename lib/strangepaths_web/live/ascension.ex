defmodule StrangepathsWeb.Ascension do
  use StrangepathsWeb, :live_view

  @impl true
  def mount(_params, session, socket) do
    socket = assign_defaults(session, socket)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    IO.puts("handle_params ascension")
    IO.inspect(params)
    {:noreply, socket}
  end
end
