defmodule StrangepathsWeb.Ascension do
  use StrangepathsWeb, :live_view

  @impl true
  def mount(_params, session, socket) do
    socket = assign_defaults(session, socket)

    users = Strangepaths.Accounts.get_ascended_users()
    private_users = Strangepaths.Accounts.get_private_users()

    {:ok,
     socket
     |> assign(:ascended_users, users)
     |> assign(:private_users, private_users)
     |> assign(:new_techne_name, "")
     |> assign(:new_techne_desc, "")}
  end

  @impl true
  def handle_event("toggle", %{"id" => user_id}, socket) do
    user = Strangepaths.Accounts.get_user!(user_id)

    {:ok, _user} =
      Strangepaths.Accounts.update_user_ascension(user, %{
        public_ascension: !user.public_ascension
      })

    users = Strangepaths.Accounts.get_ascended_users()
    private_users = Strangepaths.Accounts.get_private_users()

    {:noreply,
     socket
     |> assign(:ascended_users, users)
     |> assign(:private_users, private_users)}
  end

  @impl true
  def handle_event("spend_arete", %{"_target" => ["spend_arete"], "spend_arete" => arete}, socket) do
    user = socket.assigns.current_user
    IO.puts("handle_event spend_arete for user #{user.nickname} spending #{arete}")

    {:noreply, socket}
  end

  @impl true
  def handle_event("roll", %{"color" => color}, socket) do
    user = socket.assigns.current_user

    IO.puts("got request to roll #{color} for user #{user.nickname}")

    {:noreply, socket}
  end

  @impl true
  def handle_event("ascend", %{"color" => color}, socket) do
    user = socket.assigns.current_user

    IO.puts("got request to ascend #{color} for user #{user.nickname}")

    {:noreply, socket}
  end

  @impl true
  def handle_event("sacrifice", %{"color" => color}, socket) do
    user = socket.assigns.current_user

    IO.puts("got request to sacrifice #{color} for user #{user.nickname}")

    {:noreply, socket}
  end

  @impl true
  def handle_event("delete_techne", %{"name" => name}, socket) do
    user = socket.assigns.current_user

    current_true_techne = Strangepaths.Accounts.get_user!(user.id).techne

    new_techne =
      Enum.filter(current_true_techne, fn t ->
        String.split(t, ":") |> hd() != name
      end)

    {:ok, _} = Strangepaths.Accounts.update_user_techne(user, %{techne: new_techne})

    {:noreply, socket}
  end

  def handle_event("add_techne", %{"name" => name, "desc" => desc}, socket) do
    user = socket.assigns.current_user

    current_true_techne = Strangepaths.Accounts.get_user!(user.id).techne
    new_techne = current_true_techne ++ ["#{name}:#{desc}"]
    {:ok, _} = Strangepaths.Accounts.update_user_techne(user, %{techne: new_techne})

    {:noreply, socket |> assign(:new_techne_name, "") |> assign(:new_techne_desc, "")}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end
end
