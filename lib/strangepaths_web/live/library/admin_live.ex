defmodule StrangepathsWeb.LibraryLive.Admin do
  use StrangepathsWeb, :live_view

  alias Strangepaths.Accounts
  alias Strangepaths.Library

  @impl true
  def mount(_params, session, socket) do
    socket = assign_defaults(session, socket)

    if socket.assigns.current_user && socket.assigns.current_user.role == :dragon do
      users = load_users_with_typefaces()

      {:ok,
       socket
       |> assign(:page_title, "Library Admin — Typeface Assignments")
       |> assign(:users, users)
       |> assign(:typefaces, Library.Typefaces.all())}
    else
      {:ok,
       socket
       |> put_flash(:error, "Unauthorized")
       |> push_redirect(to: "/")}
    end
  end

  @impl true
  def handle_event(
        "toggle_typeface",
        %{"user-id" => user_id_str, "typeface-id" => typeface_id},
        socket
      ) do
    user_id = String.to_integer(user_id_str)

    case Enum.find(socket.assigns.users, &(&1.id == user_id)) do
      nil ->
        {:noreply, put_flash(socket, :error, "User no longer exists.")}

      %{typeface_ids: assigned_ids} ->
        if typeface_id in assigned_ids do
          Library.remove_user_typeface(user_id, typeface_id)
        else
          Library.assign_user_typeface(user_id, typeface_id)
        end

        users = load_users_with_typefaces()
        {:noreply, assign(socket, :users, users)}
    end
  end

  defp load_users_with_typefaces do
    Accounts.list_users()
    |> Enum.map(fn user ->
      typeface_ids = Library.list_user_typefaces(user.id)
      Map.put(user, :typeface_ids, typeface_ids)
    end)
  end
end
