defmodule StrangepathsWeb.WriteLock do
  @moduledoc """
  Global read-only ("no Tomestone") mode for the Linkpearl and Library.

  When `site_settings.tomestone_required` is on, non-dragons may observe but not write.
  `attach/3` assigns `:read_only`, refuses the given write events server-side, and keeps
  `:read_only` current when the setting is toggled while a page is open.
  """

  use Phoenix.Component, only: [sigil_H: 2]
  import Phoenix.LiveView, only: [assign: 3, attach_hook: 4, connected?: 1, put_flash: 3, push_redirect: 2]

  alias Strangepaths.Site

  @topic "site_settings"
  @message "You do not currently have access to a Tomestone"
  @banner "You do not have a Tomestone - and yet you can still observe, but not write to, the Library and Linkpearl."

  def message, do: @message

  def locked_for?(user, settings) do
    settings.tomestone_required && !(user && user.role == :dragon)
  end

  @doc """
  Options: `:on_lock` — `fn socket -> path end`, redirect there if the lock engages mid-session.
  """
  def attach(socket, write_events, opts \\ []) do
    if connected?(socket), do: StrangepathsWeb.Endpoint.subscribe(@topic)

    socket
    |> assign(:read_only, locked_for?(socket.assigns.current_user, Site.get_site_settings()))
    |> attach_hook(:write_lock_events, :handle_event, fn event, _params, socket ->
      if event in write_events and locked_for?(socket.assigns.current_user, Site.get_site_settings()) do
        {:halt, put_flash(socket, :error, @message)}
      else
        {:cont, socket}
      end
    end)
    |> attach_hook(:write_lock_info, :handle_info, fn
      %Phoenix.Socket.Broadcast{topic: @topic, event: "updated"}, socket ->
        locked = locked_for?(socket.assigns.current_user, Site.get_site_settings())
        socket = assign(socket, :read_only, locked)

        case {locked, opts[:on_lock]} do
          {true, on_lock} when is_function(on_lock, 1) ->
            {:halt, socket |> put_flash(:error, @message) |> push_redirect(to: on_lock.(socket))}

          _ ->
            {:halt, socket}
        end

      _msg, socket ->
        {:cont, socket}
    end)
  end

  def tomestone_banner(assigns) do
    assigns = assign(assigns, :text, @banner)

    ~H"""
    <div role="status" class="border border-yellow-700 bg-yellow-900/20 text-yellow-200 text-sm rounded px-4 py-3 mb-6">
      <%= @text %>
    </div>
    """
  end
end
