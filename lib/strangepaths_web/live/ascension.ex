defmodule StrangepathsWeb.Ascension do
  use StrangepathsWeb, :live_view

  import StrangepathsWeb.MusicBroadcast

  alias Nostrum.Api.Message

  @impl true
  def mount(_params, session, socket) do
    socket = assign_defaults(session, socket)

    # Subscribe to the Ascension topic for real-time updates
    StrangepathsWeb.Endpoint.subscribe("ascension")
    # Subscribe to music broadcasts
    subscribe_to_music(socket)

    users = Strangepaths.Accounts.get_ascended_users()
    private_users = Strangepaths.Accounts.get_private_users()

    {:ok,
     socket
     |> assign(:ascended_users, users)
     |> assign(:private_users, private_users)
     |> assign(:crimes, System.unique_integer())
     |> assign(:selected_expenditure, "0")
     |> assign(:new_techne_name, "")
     |> assign(:new_techne_desc, "")}
  end

  defp discord(user, msg) do
    if user.public_ascension do
      Message.create(Application.get_env(:strangepaths, :discord_channel), msg)
    end
  end

  @impl true
  def handle_event(event, params, socket) do
    case forward_music_client_event(event, params, socket) do
      :not_music_event ->
        handle_ascension_event(event, params, socket)

      result ->
        result
    end
  end

  defp handle_ascension_event("toggle", %{"id" => user_id}, socket) do
    user = Strangepaths.Accounts.get_user!(user_id)

    {:ok, _user} =
      Strangepaths.Accounts.update_user_ascension(user, %{
        public_ascension: !user.public_ascension
      })

    StrangepathsWeb.Endpoint.broadcast("ascension", "update", %{})

    {:noreply, socket}
  end

  defp handle_ascension_event(
         "spend_arete",
         %{"arete_extern" => %{"spend_arete" => arete}},
         socket
       ) do
    user = socket.assigns.current_user
    # Decrement user's arete by arete
    if arete >= 0 do
      new_arete = max(user.arete - String.to_integer(arete), 0)

      {:ok, _user} =
        Strangepaths.Accounts.update_user_arete(user, %{
          arete: new_arete
        })

      StrangepathsWeb.Endpoint.broadcast("ascension", "update", %{})

      arete_msg = "#{user.nickname} has spent #{arete} Arete and now has #{new_arete} remaining."
      discord(user, arete_msg)
      # Message.create(Application.get_env(:strangepaths, :discord_channel), arete_msg)

      {:noreply,
       assign(socket, :selected_expenditure, "0")
       # I'm so sorry.
       |> assign(:crimes, System.unique_integer())}
    else
      arete_msg = "#{user.nickname} attempted to do Crimes."
      discord(user, arete_msg)

      {:noreply,
       assign(socket, :selected_expenditure, "0") |> assign(:crimes, System.unique_integer())}
    end
  end

  defp handle_ascension_event("roll", %{"color" => color}, socket) do
    user = socket.assigns.current_user
    # roll a number between 1 and the user's chosen color die
    roll_msg =
      case color do
        "red" ->
          if user.alethic_red >= user.primary_red do
            roll1 = Enum.random(1..user.primary_red)
            roll2 = Enum.random(1..user.primary_red)
            roll = max(roll1, roll2)

            if roll == user.primary_red do
              "#{user.nickname} rolled their [redacted] Red d#{user.primary_red}: (#{roll1}, #{roll2}) -> #{roll}! It explodes!"
            else
              "#{user.nickname} rolled their [redacted] Red d#{user.primary_red}: (#{roll1}, #{roll2}) -> #{roll}."
            end
          else
            roll = Enum.random(1..user.primary_red)

            if roll == user.primary_red do
              "#{user.nickname} rolled their Red d#{user.primary_red}: #{roll}! It explodes!"
            else
              "#{user.nickname} rolled their Red d#{user.primary_red}: #{roll}."
            end
          end

        "green" ->
          if user.alethic_green >= user.primary_green do
            roll1 = Enum.random(1..user.primary_green)
            roll2 = Enum.random(1..user.primary_green)
            roll = max(roll1, roll2)

            if roll == user.primary_green do
              "#{user.nickname} rolled their [redacted] Green d#{user.primary_green}: (#{roll1}, #{roll2}) -> #{roll}! It explodes!"
            else
              "#{user.nickname} rolled their [redacted] Green d#{user.primary_green}: (#{roll1}, #{roll2}) -> #{roll}."
            end
          else
            roll = Enum.random(1..user.primary_green)

            if roll == user.primary_green do
              "#{user.nickname} rolled their Green d#{user.primary_green}: #{roll}! It explodes!"
            else
              "#{user.nickname} rolled their Green d#{user.primary_green}: #{roll}."
            end
          end

        "blue" ->
          if user.alethic_blue >= user.primary_blue do
            roll1 = Enum.random(1..user.primary_blue)
            roll2 = Enum.random(1..user.primary_blue)
            roll = max(roll1, roll2)

            if roll == user.primary_blue do
              "#{user.nickname} rolled their [redacted] Blue d#{user.primary_blue}: (#{roll1}, #{roll2}) -> #{roll}! It explodes!"
            else
              "#{user.nickname} rolled their [redacted] Blue d#{user.primary_blue}: (#{roll1}, #{roll2}) -> #{roll}."
            end
          else
            roll = Enum.random(1..user.primary_blue)

            if roll == user.primary_blue do
              "#{user.nickname} rolled their Blue d#{user.primary_blue}: #{roll}! It explodes!"
            else
              "#{user.nickname} rolled their Blue d#{user.primary_blue}: #{roll}."
            end
          end

        "white" ->
          if user.alethic_white >= user.primary_white do
            roll1 = Enum.random(1..user.primary_white)
            roll2 = Enum.random(1..user.primary_white)
            roll = max(roll1, roll2)

            if roll == user.primary_white do
              "#{user.nickname} rolled their [redacted] White d#{user.primary_white}: (#{roll1}, #{roll2}) -> #{roll}! It explodes!"
            else
              "#{user.nickname} rolled their [redacted] White d#{user.primary_white}: (#{roll1}, #{roll2}) -> #{roll}."
            end
          else
            roll = Enum.random(1..user.primary_white)

            if roll == user.primary_white do
              "#{user.nickname} rolled their White d#{user.primary_white}: #{roll}! It explodes!"
            else
              "#{user.nickname} rolled their White d#{user.primary_white}: #{roll}."
            end
          end

        "black" ->
          if user.alethic_black >= user.primary_black do
            roll1 = Enum.random(1..user.primary_black)
            roll2 = Enum.random(1..user.primary_black)
            roll = max(roll1, roll2)

            if roll == user.primary_black do
              "#{user.nickname} rolled their [redacted] Black d#{user.primary_black}: (#{roll1}, #{roll2}) -> #{roll}! It explodes!"
            else
              "#{user.nickname} rolled their [redacted] Black d#{user.primary_black}: (#{roll1}, #{roll2}) -> #{roll}."
            end
          else
            roll = Enum.random(1..user.primary_black)

            if roll == user.primary_black do
              "#{user.nickname} rolled their Black d#{user.primary_black}: #{roll}! It explodes!"
            else
              "#{user.nickname} rolled their Black d#{user.primary_black}: #{roll}."
            end
          end

        "empty" ->
          if user.alethic_void >= user.primary_void do
            roll1 = Enum.random(1..user.primary_void)
            roll2 = Enum.random(1..user.primary_void)
            roll = max(roll1, roll2)

            if roll == user.primary_void do
              "#{user.nickname} rolled their [redacted] Empty d#{user.primary_void}: (#{roll1}, #{roll2}) -> #{roll}! It explodes!"
            else
              "#{user.nickname} rolled their [redacted] Empty d#{user.primary_void}: (#{roll1}, #{roll2}) -> #{roll}."
            end
          else
            roll = Enum.random(1..user.primary_void)

            if roll == user.primary_void do
              "#{user.nickname} rolled their Empty d#{user.primary_void}: #{roll}! It explodes!"
            else
              "#{user.nickname} rolled their Empty d#{user.primary_void}: #{roll}."
            end
          end
      end

    discord(user, roll_msg)
    # Message.create(Application.get_env(:strangepaths, :discord_channel), roll_msg)

    {:noreply, socket}
  end

  defp handle_ascension_event("ascend", %{"color" => color}, socket) do
    user = socket.assigns.current_user

    resp =
      case Strangepaths.Accounts.ascend(user, color) do
        :alethic_sacrifice ->
          "#{user.nickname} chose to perform a beautiful, and terrible, magic; for a brief moment their [redacted] sacrifice of their entire gnosis of #{color} allows them communion with the Dragon."

        {:ascension_successful, new_die} ->
          "#{user.nickname} has ascended to d#{new_die} in the aspect of #{color}."
      end

    discord(user, resp)
    # Message.create(Application.get_env(:strangepaths, :discord_channel), resp)

    StrangepathsWeb.Endpoint.broadcast("ascension", "update", %{})

    {:noreply, socket}
  end

  defp handle_ascension_event("sacrifice", %{"color" => color}, socket) do
    user = socket.assigns.current_user

    Strangepaths.Accounts.player_driven_sacrifice(user, color)

    msg = "#{user.nickname} made an offering of their mastery of #{color}."
    discord(user, msg)
    # Message.create(Application.get_env(:strangepaths, :discord_channel), msg)

    StrangepathsWeb.Endpoint.broadcast("ascension", "update", %{})

    {:noreply, socket}
  end

  defp handle_ascension_event("invoke_techne", %{"name" => name, "desc" => desc}, socket) do
    user = socket.assigns.current_user

    IO.puts("got request to invoke techne #{name} for user #{user.nickname}")

    invoke_msg = "#{user.nickname} invokes #{name} (#{desc})"

    discord(user, invoke_msg)
    # Message.create(Application.get_env(:strangepaths, :discord_channel), invoke_msg)

    {:noreply, socket}
  end

  defp handle_ascension_event("delete_techne", %{"name" => name}, socket) do
    user = socket.assigns.current_user

    current_true_techne = Strangepaths.Accounts.get_user!(user.id).techne

    new_techne =
      Enum.filter(current_true_techne, fn t ->
        String.split(t, ":") |> hd() != name
      end)

    {:ok, _} = Strangepaths.Accounts.update_user_techne(user, %{techne: new_techne})

    StrangepathsWeb.Endpoint.broadcast("ascension", "update", %{})

    {:noreply, socket}
  end

  defp handle_ascension_event(
         "add_techne",
         %{"new_techne_name" => name, "new_techne_desc" => desc},
         socket
       ) do
    user = socket.assigns.current_user

    current_true_techne = Strangepaths.Accounts.get_user!(user.id).techne
    new_techne = current_true_techne ++ ["#{name}:#{desc}"]
    {:ok, _} = Strangepaths.Accounts.update_user_techne(user, %{techne: new_techne})

    discord(user, "#{user.nickname} added a new techne: #{name} (#{desc})")

    # Message.create(Application.get_env(:strangepaths, :discord_channel), "#{user.nickname} added a new techne: #{name} (#{desc})")

    StrangepathsWeb.Endpoint.broadcast("ascension", "update", %{})

    {:noreply, socket |> assign(:new_techne_name, "") |> assign(:new_techne_desc, "")}
  end

  defp handle_ascension_event(
         "validate_techne",
         %{"new_techne_name" => new_name, "new_techne_desc" => new_desc},
         socket
       ) do
    {:noreply, socket |> assign(:new_techne_name, new_name) |> assign(:new_techne_desc, new_desc)}
  end

  # Handle music broadcasts
  @impl true
  def handle_info(msg, socket) do
    case forward_music_event(msg, socket) do
      :not_music_event ->
        # Fall through to ascension update handler
        handle_ascension_info(msg, socket)

      result ->
        result
    end
  end

  defp handle_ascension_info(%{event: "update"}, socket) do
    # update current_user and ascended_users/private_users lists, don't care about WHAT got updated really

    user = Strangepaths.Accounts.get_user!(socket.assigns.current_user.id)

    techne =
      case user.techne do
        nil ->
          [{"", ""}]

        _ ->
          Enum.map(user.techne, fn techne ->
            case String.split(techne, ":", parts: 2) do
              [name, desc] -> %{name: String.trim(name), desc: String.trim(desc)}
              [name] -> %{name: String.trim(name), desc: ""}
            end
          end)
      end

    users = Strangepaths.Accounts.get_ascended_users()
    private_users = Strangepaths.Accounts.get_private_users()

    {:noreply,
     socket
     |> assign(:ascended_users, users)
     |> assign(:private_users, private_users)
     |> assign(:current_user, %{user | techne: techne})}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end
end
