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
      {~r/Sacrifice (?<number>\d+) ranks of (?<nickname>.+)'s (?<color>.+)./,
       fn %{"number" => n, "nickname" => k, "color" => c} ->
         %{result: :sacrifice, ranks: String.to_integer(n), nickname: k, color: c}
       end}
    ]

    if msg.author.username != "segfaultvicta" do
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

              %{result: :sacrifice, ranks: ranks, nickname: nickname, color: color} ->
                sacrifice(ranks, nickname, color)

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
      Strangepaths.Accounts.gm_driven_sacrifice(user, color, ranks)
      StrangepathsWeb.Endpoint.broadcast("ascension", "update", %{})
      "#{user.nickname} sacrificed #{ranks} ranks of #{color}."
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
        red = Strangepaths.Accounts.gm_driven_sacrifice(user, "red", 4)
        green = Strangepaths.Accounts.gm_driven_sacrifice(user, "green", 4)
        blue = Strangepaths.Accounts.gm_driven_sacrifice(user, "blue", 4)
        white = Strangepaths.Accounts.gm_driven_sacrifice(user, "white", 4)
        black = Strangepaths.Accounts.gm_driven_sacrifice(user, "black", 4)
        void = Strangepaths.Accounts.gm_driven_sacrifice(user, "empty", 4)

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
          |> Enum.map(fn {val, color} -> "#{round(val)} #{color}" end)
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

        "* #{user.nickname}, you have lost #{ranks} ranks of ascension."
      end)

    StrangepathsWeb.Endpoint.broadcast("ascension", "update", %{})

    "The world has been consumed, in overgrowth, in madness, and in fire.\n" <>
      Enum.join(msgs, "")
  end
end
