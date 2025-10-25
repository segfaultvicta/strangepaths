defmodule Strangepaths.DiscordHandler do
  @behaviour Nostrum.Consumer
  alias Nostrum.Api.Message

  # IC channel: 1429574745980010587
  # Bot testing channel: 1429573151272206499

  def handle_event({:MESSAGE_CREATE, msg, _ws_state}) do
    patterns = [
      {~r/Award (?<number>\d+) arete to (?<nickname>.+)\./u,
       fn %{"number" => n, "nickname" => k} ->
         %{result: :award, arete: String.to_integer(n), nickname: k}
       end},
      {~r/, the world cries out: \"Devour me!\"/u, fn _ -> %{result: :devour} end},
      {~r/Sacrifice (?<number>\d+) ranks? of (?<nickname>.+)'s (?<color>.+)./,
       fn %{"number" => n, "nickname" => k, "color" => c} ->
         %{result: :sacrifice, ranks: String.to_integer(n), nickname: k, color: c}
       end},
      {~r/Which environment are you running on\?/u, fn _ -> %{result: :environment} end},
      {~r/Clear the queue./u, fn _ -> %{result: :clear_queue} end}
    ]

    if msg.author.username != "segfaultvicta" or
         msg.channel_id != Application.get_env(:strangepaths, :discord_channel) do
      # It might be the case that I want to enable bot commands for players, too.
      # If that is so, I can change things here accordingly.
    else
      case msg.content do
        "!test" ->
          IO.puts("Discord message received: #{msg.content}")
          Message.create(msg.channel_id, "Test successful! Channel ID: #{msg.channel_id}")

        "ꙮ" <> rest ->
          resp =
            case Enum.find_value(patterns, :unrecognised_command, fn {regex, handler} ->
                   case Regex.named_captures(regex, String.trim(rest)) do
                     nil ->
                       false

                     captures ->
                       handler.(captures)
                   end
                 end) do
              %{result: :award, arete: arete, nickname: nickname} ->
                award(nickname, arete)

              %{result: :devour} ->
                devour()

              %{result: :environment} ->
                "I am running on #{Application.get_env(:strangepaths, :environment_name)}.  "

              %{result: :sacrifice, ranks: ranks, nickname: nickname, color: color} ->
                sacrifice(ranks, nickname, color)

              %{result: :clear_queue} ->
                Strangepaths.Site.MusicQueue.clear_queue()
                "Queue cleared."

              :unrecognised_command ->
                "Unrecognised command! :cry:"
            end

          Message.create(Application.get_env(:strangepaths, :discord_channel), resp)

        _ ->
          :ignore
      end
    end
  end

  def handle_event(_), do: :ok

  # Absolutely all of these will fuck up if ranks/nickname/color/arete
  # aren't a sane thing for them to be; I need to add error checking here.
  # I'm sorry.

  def sacrifice(ranks, nickname, color) do
    user = Strangepaths.Accounts.get_user_by_nickname(nickname)

    if user == nil do
      "Sacrifice failed: User #{nickname} not found."
    else
      case Strangepaths.Accounts.gm_driven_sacrifice_of(user, color, ranks) do
        {:ok, n} ->
          StrangepathsWeb.Endpoint.broadcast("ascension", "update", %{})
          "#{user.nickname} sacrificed #{fancify(n)} of #{color}."

        {:error, reason} ->
          "ERROR: #{nickname}'s sacrifice failed: #{reason}"
      end
    end
  end

  defp fancify(n) do
    case n do
      # shouldn't? ever actually be the case? but hey
      0 -> "naught"
      1 -> "once"
      2 -> "twice"
      3 -> "thrice"
      4 -> "deeply"
      5 -> "utterly and absolutely"
      _ -> ":poop:"
    end
  end

  def award(nickname, arete) do
    user = Strangepaths.Accounts.get_user_by_nickname(nickname)

    if user == nil do
      "Award failed: User #{nickname} not found."
    else
      new_arete = user.arete + arete

      {:ok, _user} =
        Strangepaths.Accounts.update_user_arete(user, %{
          arete: new_arete
        })

      StrangepathsWeb.Endpoint.broadcast("ascension", "update", %{})
      "#{user.nickname} has gained #{arete} Arete, and now has #{new_arete}."
    end
  end

  def devour() do
    users = Strangepaths.Accounts.get_ascended_users()

    msgs =
      Enum.map(users, fn user ->
        {:ok, red} = Strangepaths.Accounts.gm_driven_sacrifice_to(user, "red", 4)
        {:ok, green} = Strangepaths.Accounts.gm_driven_sacrifice_to(user, "green", 4)
        {:ok, blue} = Strangepaths.Accounts.gm_driven_sacrifice_to(user, "blue", 4)
        {:ok, white} = Strangepaths.Accounts.gm_driven_sacrifice_to(user, "white", 4)
        {:ok, black} = Strangepaths.Accounts.gm_driven_sacrifice_to(user, "black", 4)
        {:ok, void} = Strangepaths.Accounts.gm_driven_sacrifice_to(user, "empty", 4)

        IO.inspect(red)

        # insert an 'and' between the last two elements if there's more than one rank
        ranks =
          [
            {red, "red"},
            {green, "green"},
            {blue, "blue"},
            {white, "white"},
            {black, "black"},
            {void, "empty"}
          ]
          |> Enum.reject(fn {val, _} -> val == 0 end)
          |> Enum.map(fn {val, color} -> "#{fancify(round(val))} of #{color}" end)
          |> case do
            [] ->
              ""

            [single] ->
              single

            [first, second] ->
              "#{first} and #{second}"

            list ->
              {last, rest} = List.pop_at(list, -1)
              Enum.join(rest, ", ") <> ", and #{last}"
          end

        if ranks == "" do
          nil
        else
          "* #{user.nickname}, you have sacrificed #{ranks}.\n"
        end
      end)

    StrangepathsWeb.Endpoint.broadcast("ascension", "update", %{})

    "The worlds have been consumed, in overgrowth, in madness, and in fire.\n" <>
      Enum.join(msgs, "")
  end
end
