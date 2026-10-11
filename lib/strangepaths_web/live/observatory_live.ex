defmodule StrangepathsWeb.ObservatoryLive do
  @moduledoc """
  The Library Annex Observatory: a WebGL planetarium of the northern dome.

  Entirely client-side (the `Observatory` hook in assets/js/observatory.js);
  this LiveView only supplies the shell and static asset URLs.
  """
  use StrangepathsWeb, :live_view

  import StrangepathsWeb.MusicBroadcast

  def mount(_params, session, socket) do
    socket = assign_defaults(session, socket)
    subscribe_to_music(socket)

    {:ok, assign(socket, :page_title, "Observatory")}
  end
end
