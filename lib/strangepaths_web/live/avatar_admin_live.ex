defmodule StrangepathsWeb.AvatarAdminLive do
  use StrangepathsWeb, :live_view

  alias Strangepaths.Accounts

  @impl true
  def mount(_params, session, socket) do
    socket = assign_defaults(session, socket)

    if socket.assigns.current_user.role == :dragon do
      {:ok,
       socket
       |> assign(:avatars, Accounts.list_avatars())
       |> assign(:editing_avatar, nil)
       |> assign(:creating_avatar, false)}
    else
      {:ok,
       socket
       |> put_flash(:error, "Unauthorized")
       |> push_redirect(to: "/")}
    end
  end

  @impl true
  def handle_event("start_create", _, socket) do
    {:noreply, assign(socket, :creating_avatar, true)}
  end

  def handle_event("cancel_create", _, socket) do
    {:noreply, assign(socket, :creating_avatar, false)}
  end

  def handle_event("create", params, socket) do
    filepath = "/images/avatars/#{params["filename"]}"

    attrs = %{
      filepath: filepath,
      category: params["category"],
      display_name: params["display_name"],
      public: params["public"] == "true"
    }

    case Accounts.create_avatar(attrs) do
      {:ok, _avatar} ->
        {:noreply,
         socket
         |> assign(:avatars, Accounts.list_avatars())
         |> assign(:creating_avatar, false)
         |> put_flash(:info, "Avatar created!")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create avatar")}
    end
  end

  def handle_event("start_edit", %{"id" => id}, socket) do
    {:noreply, assign(socket, :editing_avatar, String.to_integer(id))}
  end

  def handle_event("cancel_edit", _, socket) do
    {:noreply, assign(socket, :editing_avatar, nil)}
  end

  def handle_event("update", params, socket) do
    avatar = Accounts.get_avatar!(params["id"])

    attrs = %{
      category: params["category"],
      display_name: params["display_name"],
      public: params["public"] == "true"
    }

    case Accounts.update_avatar(avatar, attrs) do
      {:ok, _avatar} ->
        {:noreply,
         socket
         |> assign(:avatars, Accounts.list_avatars())
         |> assign(:editing_avatar, nil)
         |> put_flash(:info, "Avatar updated!")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update avatar")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    avatar = Accounts.get_avatar!(id)

    case Accounts.delete_avatar(avatar) do
      {:ok, _avatar} ->
        {:noreply,
         socket
         |> assign(:avatars, Accounts.list_avatars())
         |> put_flash(:info, "Avatar deleted!")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to delete avatar")}
    end
  end

  def handle_event("toggle_public", %{"id" => id}, socket) do
    avatar = Accounts.get_avatar!(id)
    Accounts.update_avatar(avatar, %{public: !avatar.public})

    {:noreply, assign(socket, :avatars, Accounts.list_avatars())}
  end
end
