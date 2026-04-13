defmodule StrangepathsWeb.UserAdminLive do
  use StrangepathsWeb, :live_view

  alias Strangepaths.Accounts

  @impl true
  def mount(_params, session, socket) do
    socket = assign_defaults(session, socket)

    if socket.assigns.current_user && socket.assigns.current_user.role == :dragon do
      users =
        Accounts.list_users()
        |> Enum.reject(&(&1.role == :dragon))
        |> Enum.sort_by(&String.downcase(&1.nickname))

      {:ok,
       socket
       |> assign(:page_title, "User Admin")
       |> assign(:users, users)
       |> assign(:selected_user_id, nil)
       |> assign(:pw_error, nil)
       |> assign(:pw_success, nil)}
    else
      {:ok,
       socket
       |> put_flash(:error, "Unauthorized")
       |> push_redirect(to: "/")}
    end
  end

  @impl true
  def handle_event("select_user", %{"id" => id}, socket) do
    {:noreply,
     socket
     |> assign(:selected_user_id, String.to_integer(id))
     |> assign(:pw_error, nil)
     |> assign(:pw_success, nil)}
  end

  def handle_event("set_password", %{"password" => pw, "password_confirmation" => pw_conf}, socket) do
    user = Accounts.get_user!(socket.assigns.selected_user_id)

    case Accounts.admin_set_user_password(user, %{
           password: pw,
           password_confirmation: pw_conf
         }) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> assign(:pw_error, nil)
         |> assign(:pw_success, "Password updated for #{user.nickname}.")}

      {:error, changeset} ->
        errors =
          Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
            Enum.reduce(opts, msg, fn {key, value}, acc ->
              String.replace(acc, "%{#{key}}", to_string(value))
            end)
          end)

        {:noreply,
         socket
         |> assign(:pw_error, inspect(errors))
         |> assign(:pw_success, nil)}
    end
  end
end
