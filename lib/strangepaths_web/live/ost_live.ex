defmodule StrangepathsWeb.OstLive do
  use StrangepathsWeb, :live_view

  import StrangepathsWeb.MusicBroadcast

  alias Strangepaths.Site

  @impl true
  def mount(_params, session, socket) do
    socket = assign_defaults(session, socket)

    # Subscribe to music broadcasts
    subscribe_to_music(socket)

    disc1 = Site.disc1()
    disc2 = Site.disc2()

    {:ok,
     socket
     |> assign(:disc1, disc1)
     |> assign(:disc2, disc2)
     |> assign(:editing_song, nil)
     |> assign(:creating_song, nil)}
  end

  @impl true
  def handle_event(event, params, socket) do
    # Try forwarding music client events first
    case forward_music_client_event(event, params, socket) do
      :not_music_event ->
        # Handle our own events
        handle_ost_event(event, params, socket)

      result ->
        result
    end
  end

  defp handle_ost_event("start_create_song", %{"disc" => disc}, socket) do
    {:noreply, assign(socket, :creating_song, String.to_integer(disc))}
  end

  defp handle_ost_event("cancel_create_song", _, socket) do
    {:noreply, assign(socket, :creating_song, nil)}
  end

  defp handle_ost_event("create_song", %{"title" => title, "disc" => disc}, socket) do
    if socket.assigns.current_user.role in [:admin, :god] do
      case Site.create_song(%{
             title: title,
             disc: String.to_integer(disc),
             unlocked: false,
             text: "",
             link: ""
           }) do
        {:ok, _song} ->
          {:noreply,
           socket
           # ← Refresh disc 1 list
           |> assign(:disc1, Site.disc1())
           # ← Refresh disc 2 list
           |> assign(:disc2, Site.disc2())
           |> assign(:creating_song, nil)
           |> put_flash(:info, "Song created!")}

        {:error, _changeset} ->
          {:noreply, socket |> put_flash(:error, "Failed to create song")}
      end
    else
      {:noreply, socket |> put_flash(:error, "Unauthorized")}
    end
  end

  defp handle_ost_event("queue_song", %{"song-id" => song_id}, socket) do
    user = socket.assigns.current_user

    case Site.queue_song(song_id, user.nickname) do
      {:ok, _state} ->
        {:noreply,
         socket
         |> put_flash(:info, "Song queued!")}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to queue song: #{inspect(reason)}")}
    end
  end

  # Admin-only event handlers

  defp handle_ost_event("toggle_lock", %{"song-id" => song_id}, socket) do
    user = socket.assigns.current_user

    if user.role in [:admin, :god] do
      case Site.toggle_song_lock(String.to_integer(song_id)) do
        {:ok, _song} ->
          {:noreply,
           socket
           |> assign(:disc1, Site.disc1())
           |> assign(:disc2, Site.disc2())
           |> put_flash(:info, "Song lock toggled")}

        {:error, _} ->
          {:noreply, socket |> put_flash(:error, "Failed to toggle lock")}
      end
    else
      {:noreply, socket |> put_flash(:error, "Unauthorized")}
    end
  end

  defp handle_ost_event("update_title", %{"song-id" => song_id, "title" => title}, socket) do
    user = socket.assigns.current_user

    if user.role in [:admin, :god] do
      case Site.update_song_metadata(String.to_integer(song_id), %{title: title}) do
        {:ok, _song} ->
          {:noreply,
           socket
           |> assign(:disc1, Site.disc1())
           |> assign(:disc2, Site.disc2())
           |> assign(:editing_song, nil)
           |> put_flash(:info, "Song title updated")}

        {:error, _} ->
          {:noreply, socket |> put_flash(:error, "Failed to update title")}
      end
    else
      {:noreply, socket |> put_flash(:error, "Unauthorized")}
    end
  end

  defp handle_ost_event("start_edit_title", %{"song-id" => song_id}, socket) do
    user = socket.assigns.current_user

    if user.role in [:admin, :god] do
      {:noreply, assign(socket, :editing_song, String.to_integer(song_id))}
    else
      {:noreply, socket}
    end
  end

  defp handle_ost_event("cancel_edit_title", _, socket) do
    {:noreply, assign(socket, :editing_song, nil)}
  end

  defp handle_ost_event("reorder_song", %{"song_id" => song_id, "new_order" => new_order}, socket) do
    user = socket.assigns.current_user

    if user.role in [:admin, :god] do
      case Site.update_song_order(String.to_integer(song_id), new_order) do
        {:ok, _song} ->
          {:noreply,
           socket
           |> assign(:disc1, Site.disc1())
           |> assign(:disc2, Site.disc2())
           |> put_flash(:info, "Song order updated")}
      end
    else
      {:noreply, socket |> put_flash(:error, "Unauthorized")}
    end
  end

  @impl true
  def handle_info(msg, socket) do
    # Forward music broadcasts to the component
    case forward_music_event(msg, socket) do
      :not_music_event ->
        # Handle other non-music events here if needed
        {:noreply, socket}

      result ->
        result
    end
  end
end
