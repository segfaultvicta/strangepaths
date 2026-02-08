defmodule StrangepathsWeb.AvatarAdminLive do
  use StrangepathsWeb, :live_view

  alias Strangepaths.Accounts

  @impl true
  def mount(_params, session, socket) do
    socket = assign_defaults(session, socket)

    if socket.assigns.current_user.role == :dragon do
      {:ok,
       socket
       |> assign_avatars()
       |> assign(:editing_avatar, nil)
       |> assign(:creating_avatar, false)
       |> allow_upload(:avatar_image, accept: ~w(.png .jpg .jpeg .webp), max_entries: 1)}
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

  def handle_event("validate_upload", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("create", params, socket) do
    filepath = handle_avatar_upload(socket)

    if filepath do
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
           |> assign_avatars()
           |> assign(:creating_avatar, false)
           |> put_flash(:info, "Avatar created!")}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to create avatar")}
      end
    else
      {:noreply, put_flash(socket, :error, "Please select an image file")}
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
         |> assign_avatars()
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
         |> assign_avatars()
         |> put_flash(:info, "Avatar deleted!")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to delete avatar")}
    end
  end

  def handle_event("toggle_public", %{"id" => id}, socket) do
    avatar = Accounts.get_avatar!(id)
    Accounts.update_avatar(avatar, %{public: !avatar.public})

    {:noreply, assign_avatars(socket)}
  end

  defp assign_avatars(socket) do
    avatars = Accounts.list_avatars()

    avatars_by_category =
      avatars
      |> Enum.group_by(fn a -> a.category || "general" end)
      |> Enum.sort_by(fn {cat, _} -> cat end)

    categories = Enum.map(avatars_by_category, fn {cat, _} -> cat end)

    socket
    |> assign(:avatars_by_category, avatars_by_category)
    |> assign(:categories, categories)
  end

  defp handle_avatar_upload(socket) do
    dest_dir =
      Path.join([:code.priv_dir(:strangepaths), "static", "uploads", "avatars"])

    File.mkdir_p!(dest_dir)

    paths =
      consume_uploaded_entries(socket, :avatar_image, fn %{path: path}, entry ->
        filename =
          "avatar_#{System.system_time(:second)}_#{entry.client_name}"

        dest = Path.join(dest_dir, filename)
        File.cp!(path, dest)
        {:ok, Routes.static_path(socket, "/uploads/avatars/#{filename}")}
      end)

    List.first(paths)
  end

  def friendly_error(:too_large), do: "Image too large"
  def friendly_error(:too_many_files), do: "Too many files"
  def friendly_error(:not_accepted), do: "Unacceptable file type"
end
