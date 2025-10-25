defmodule Strangepaths.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias Strangepaths.Repo

  alias Strangepaths.Accounts.{User, UserToken, UserNotifier}

  ## Database getters

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  def get_user_by_nickname(nickname) do
    Repo.get_by(User, nickname: nickname)
  end

  def get_ascended_users() do
    users =
      User
      |> where(public_ascension: true)
      |> order_by(:nickname)
      |> Repo.all()

    # I want to turn each user's techne into a tuple of name, description
    # where the name cuts off at the first colon, and the description is the rest
    Enum.map(users, fn user ->
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

      Map.put(user, :techne, techne)
    end)
  end

  def get_private_users() do
    User
    |> where(public_ascension: false)
    |> order_by(:nickname)
    |> Repo.all()
  end

  ## User registration

  @doc """
  Registers a user.

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %User{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs) do
    default_nick = generate_default_nickname()

    %User{}
    |> User.registration_changeset(%{
      email: attrs["email"],
      password: attrs["password"],
      nickname: default_nick
    })
    |> Repo.insert()
  end

  def generate_default_nickname do
    adjective =
      ~w(aggressive agreeable ambidextrous ambitious brave breezy calm content dapper delightful eager easy faithful frabjous friendly gentle grateful happy helpful irate irenic jolly kind lovely lively neighborly nice obedient opulent odd polite proud punctual quirky quiet rad rambunctious shy silly towering unctuous victorious vorpal witty wonderful xeric xenial yowling zealous)

    noun =
      ~w(aardvark antelope armadillo alligator aquerne axolotl badger beaver booby blobfish brontosaur capybara cheetah crocodile crow cuttlefish dingo dragon ermine emu eel ferret falcon fox gerbil heron impala ibex jackalope jellyfish koala leopard lion lobster lynx matamata meerkat narwhal ocelot octopus otter pangolin panther puffin quetzal ringtail salamander snek squirrel tiger titmouse tortoise unicorn vulture wolf werewolf xoloitzcuintle yak zebra)

    "#{String.capitalize(Enum.take_random(adjective, 1) |> List.first())} #{String.capitalize(Enum.take_random(noun, 1) |> List.first())}"
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user_registration(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_registration(%User{} = user, attrs \\ %{}) do
    User.registration_changeset(user, attrs, hash_password: false)
  end

  ## Settings

  def update_nickname(user, attrs \\ %{}) do
    user
    |> User.nick_changeset(attrs)
    |> Repo.update()
  end

  def change_user_nickname(user, attrs \\ %{}) do
    User.nick_changeset(user, attrs)
  end

  def update_user_ascension(user, attrs \\ %{}) do
    user
    |> User.ascension_changeset(attrs)
    |> Repo.update()
  end

  def update_user_arete(user, attrs \\ %{}) do
    user
    |> User.arete_changeset(attrs)
    |> Repo.update()
  end

  def update_user_techne(user, attrs \\ %{}) do
    user
    |> User.techne_changeset(attrs)
    |> Repo.update()
  end

  def update_user_die(user, attrs \\ %{}) do
    user
    |> User.die_changeset(attrs)
    |> Repo.update()
  end

  def clear_user(user) do
    user
    |> User.clear_changeset(%{
      arete: 0,
      public_ascension: false,
      techne: [],
      primary_red: 4,
      primary_green: 4,
      primary_blue: 4,
      primary_white: 4,
      primary_black: 4,
      primary_void: 4,
      alethic_red: 0,
      alethic_green: 0,
      alethic_blue: 0,
      alethic_white: 0,
      alethic_black: 0,
      alethic_void: 0
    })
    |> Repo.update()
  end

  def player_driven_sacrifice(user, color) do
    case color do
      "red" ->
        user
        |> update_user_die(%{primary_red: 10, alethic_red: max(user.alethic_red, 10)})

      "green" ->
        user
        |> update_user_die(%{primary_green: 10, alethic_green: max(user.alethic_green, 10)})

      "blue" ->
        user
        |> update_user_die(%{primary_blue: 10, alethic_blue: max(user.alethic_blue, 10)})

      "white" ->
        user
        |> update_user_die(%{primary_white: 10, alethic_white: max(user.alethic_white, 10)})

      "black" ->
        user
        |> update_user_die(%{primary_black: 10, alethic_black: max(user.alethic_black, 10)})

      "empty" ->
        user
        |> update_user_die(%{primary_void: 10, alethic_void: max(user.alethic_void, 10)})

      _ ->
        {:error, "Invalid color"}
    end
  end

  def sacrifice_diff(start, finish) do
    round(
      if start == 20 do
        (start - finish) / 2 - 3
      else
        (start - finish) / 2
      end
    )
  end

  def gm_driven_sacrifice_of(user, color, ranks) do
    case get_die_value(user, color) do
      :wrong_color ->
        {:error, "Invalid color"}

      current_die ->
        final_die = reduce_die(current_die, ranks)
        attrs = build_sacrifice(color, final_die, current_die, user)
        update_user_die(user, attrs)
        {:ok, sacrifice_diff(current_die, final_die)}
    end
  end

  defp get_die_value(user, color) do
    case color do
      "red" -> user.primary_red
      "green" -> user.primary_green
      "blue" -> user.primary_blue
      "white" -> user.primary_white
      "black" -> user.primary_black
      "empty" -> user.primary_void
      _ -> :wrong_color
    end
  end

  defp build_sacrifice(color, new_val, old_val, user) do
    {primary_key, alethic_key} =
      case color do
        "red" -> {:primary_red, :alethic_red}
        "green" -> {:primary_green, :alethic_green}
        "blue" -> {:primary_blue, :alethic_blue}
        "white" -> {:primary_white, :alethic_white}
        "black" -> {:primary_black, :alethic_black}
        "empty" -> {:primary_void, :alethic_void}
      end

    alethic_val = Map.get(user, alethic_key)

    %{
      primary_key => new_val,
      alethic_key => max(alethic_val, old_val)
    }
  end

  defp reduce_die(die, 0), do: die
  # Can't go below d4
  defp reduce_die(4, _ranks), do: 4
  # d20 -> d12
  defp reduce_die(20, ranks), do: reduce_die(12, ranks - 1)
  defp reduce_die(die, ranks) when die > 4, do: reduce_die(die - 2, ranks - 1)
  # Catch-all for safety
  defp reduce_die(die, _ranks), do: die

  def gm_driven_sacrifice_to(user, color, degree) do
    IO.puts("in gm_driven_sacrifice_to #{user.nickname} #{color} #{degree}")

    case get_die_value(user, color) do
      :wrong_color ->
        {:error, "Invalid color"}

      current_die ->
        IO.puts("current die is #{current_die}")
        diff = sacrifice_diff(current_die, degree)
        IO.puts("diff is #{diff}")
        attrs = build_sacrifice(color, degree, current_die, user)
        update_user_die(user, attrs)
        {:ok, diff}
    end
  end

  def ascend(dieval) do
    cond do
      dieval >= 20 -> {:alethic_sacrifice, 20}
      dieval >= 12 -> {:ok, 20}
      dieval >= 10 -> {:ok, 12}
      dieval >= 8 -> {:ok, 10}
      dieval >= 6 -> {:ok, 8}
      dieval >= 4 -> {:ok, 6}
      true -> {:ok, 4}
    end
  end

  def ascend(user, color) do
    case color do
      "red" ->
        case ascend(user.primary_red) do
          {:alethic_sacrifice, _} ->
            user |> update_user_die(%{primary_red: 4, alethic_red: 20})
            :alethic_sacrifice

          {:ok, new_die} ->
            user |> update_user_die(%{primary_red: new_die})
            {:ascension_successful, new_die}
        end

      "green" ->
        case ascend(user.primary_green) do
          {:alethic_sacrifice, _} ->
            user |> update_user_die(%{primary_green: 4, alethic_green: 20})
            :alethic_sacrifice

          {:ok, new_die} ->
            user |> update_user_die(%{primary_green: new_die})
            {:ascension_successful, new_die}
        end

      "blue" ->
        case ascend(user.primary_blue) do
          {:alethic_sacrifice, _} ->
            user |> update_user_die(%{primary_blue: 4, alethic_blue: 20})
            :alethic_sacrifice

          {:ok, new_die} ->
            user |> update_user_die(%{primary_blue: new_die})
            {:ascension_successful, new_die}
        end

      "white" ->
        case ascend(user.primary_white) do
          {:alethic_sacrifice, _} ->
            user |> update_user_die(%{primary_white: 4, alethic_white: 20})
            :alethic_sacrifice

          {:ok, new_die} ->
            user |> update_user_die(%{primary_white: new_die})
            {:ascension_successful, new_die}
        end

      "black" ->
        case ascend(user.primary_black) do
          {:alethic_sacrifice, _} ->
            user |> update_user_die(%{primary_black: 4, alethic_black: 20})
            :alethic_sacrifice

          {:ok, new_die} ->
            user |> update_user_die(%{primary_black: new_die})
            {:ascension_successful, new_die}
        end

      "empty" ->
        case ascend(user.primary_void) do
          {:alethic_sacrifice, _} ->
            user |> update_user_die(%{primary_void: 4, alethic_void: 20})
            :alethic_sacrifice

          {:ok, new_die} ->
            user |> update_user_die(%{primary_void: new_die})
            {:ascension_successful, new_die}
        end
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.

  ## Examples

      iex> change_user_email(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_email(user, attrs \\ %{}) do
    User.email_changeset(user, attrs)
  end

  @doc """
  Emulates that the email will change without actually changing
  it in the database.

  ## Examples

      iex> apply_user_email(user, "valid password", %{email: ...})
      {:ok, %User{}}

      iex> apply_user_email(user, "invalid password", %{email: ...})
      {:error, %Ecto.Changeset{}}

  """
  def apply_user_email(user, password, attrs) do
    user
    |> User.email_changeset(attrs)
    |> User.validate_current_password(password)
    |> Ecto.Changeset.apply_action(:update)
  end

  @doc """
  Updates the user email using the given token.

  If the token matches, the user email is updated and the token is deleted.
  The confirmed_at date is also updated to the current time.
  """
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
         %UserToken{sent_to: email} <- Repo.one(query),
         {:ok, _} <- Repo.transaction(user_email_multi(user, email, context)) do
      :ok
    else
      _ -> :error
    end
  end

  defp user_email_multi(user, email, context) do
    changeset =
      user
      |> User.email_changeset(%{email: email})
      |> User.confirm_changeset()

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, [context]))
  end

  @doc """
  Delivers the update email instructions to the given user.

  ## Examples

      iex> deliver_update_email_instructions(user, current_email, &Routes.user_update_email_url(conn, :edit, &1))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.

  ## Examples

      iex> change_user_password(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_password(user, attrs \\ %{}) do
    User.password_changeset(user, attrs, hash_password: false)
  end

  @doc """
  Updates the user password.

  ## Examples

      iex> update_user_password(user, "valid password", %{password: ...})
      {:ok, %User{}}

      iex> update_user_password(user, "invalid password", %{password: ...})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_password(user, password, attrs) do
    changeset =
      user
      |> User.password_changeset(attrs)
      |> User.validate_current_password(password)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_session_token(token) do
    Repo.delete_all(UserToken.token_and_context_query(token, "session"))
    :ok
  end

  ## Confirmation

  @doc """
  Delivers the confirmation email instructions to the given user.

  ## Examples

      iex> deliver_user_confirmation_instructions(user, &Routes.user_confirmation_url(conn, :edit, &1))
      {:ok, %{to: ..., body: ...}}

      iex> deliver_user_confirmation_instructions(confirmed_user, &Routes.user_confirmation_url(conn, :edit, &1))
      {:error, :already_confirmed}

  """
  def deliver_user_confirmation_instructions(%User{} = user, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    if user.confirmed_at do
      {:error, :already_confirmed}
    else
      {encoded_token, user_token} = UserToken.build_email_token(user, "confirm")
      Repo.insert!(user_token)
      UserNotifier.deliver_confirmation_instructions(user, confirmation_url_fun.(encoded_token))
    end
  end

  @doc """
  Confirms a user by the given token.

  If the token matches, the user account is marked as confirmed
  and the token is deleted.
  """
  def confirm_user(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "confirm"),
         %User{} = user <- Repo.one(query),
         {:ok, %{user: user}} <- Repo.transaction(confirm_user_multi(user)) do
      {:ok, user}
    else
      _ -> :error
    end
  end

  defp confirm_user_multi(user) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.confirm_changeset(user))
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, ["confirm"]))
  end

  ## Reset password

  @doc """
  Delivers the reset password email to the given user.

  ## Examples

      iex> deliver_user_reset_password_instructions(user, &Routes.user_reset_password_url(conn, :edit, &1))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_reset_password_instructions(%User{} = user, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "reset_password")
    Repo.insert!(user_token)
    UserNotifier.deliver_reset_password_instructions(user, reset_password_url_fun.(encoded_token))
  end

  @doc """
  Gets the user by reset password token.

  ## Examples

      iex> get_user_by_reset_password_token("validtoken")
      %User{}

      iex> get_user_by_reset_password_token("invalidtoken")
      nil

  """
  def get_user_by_reset_password_token(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "reset_password"),
         %User{} = user <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Resets the user password.

  ## Examples

      iex> reset_user_password(user, %{password: "new long password", password_confirmation: "new long password"})
      {:ok, %User{}}

      iex> reset_user_password(user, %{password: "valid", password_confirmation: "not the same"})
      {:error, %Ecto.Changeset{}}

  """
  def reset_user_password(user, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.password_changeset(user, attrs))
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  @doc """
  Registers an admin user.

  ## Examples
      iex> register_admin(%{field: value})
      {:ok, %User{}}

      iex> register_admin(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def register_admin(attrs) do
    %User{}
    |> User.admin_registration_changeset(attrs, false)
    |> Repo.insert()
  end

  @doc """
  Registers a superadmin user.

  ## Examples
      iex> register_god(%{field: value})
      {:ok, %User{}}

      iex> register_god(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def register_god(attrs) do
    %User{}
    |> User.admin_registration_changeset(attrs, true)
    |> Repo.insert()
  end

  alias Strangepaths.Accounts.Avatar

  @doc """
  Returns the list of avatars.

  ## Examples

      iex> list_avatars()
      [%Avatar{}, ...]

  """
  def list_avatars do
    Repo.all(Avatar)
  end

  def list_public_avatars do
    list_avatars()
    |> Enum.filter(fn a -> a.public end)
  end

  def list_avatars_of(user_id) do
    list_avatars()
    |> Enum.filter(fn a -> a.public == false && a.owner_id == user_id end)
  end

  @doc """
  Gets a single avatar.

  Raises `Ecto.NoResultsError` if the Avatar does not exist.

  ## Examples

      iex> get_avatar!(123)
      %Avatar{}

      iex> get_avatar!(456)
      ** (Ecto.NoResultsError)

  """
  def get_avatar!(id), do: Repo.get!(Avatar, id)

  @doc """
  Creates a avatar.

  ## Examples

      iex> create_avatar(%{field: value})
      {:ok, %Avatar{}}

      iex> create_avatar(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_avatar(attrs \\ %{}) do
    %Avatar{}
    |> Avatar.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a avatar.

  ## Examples

      iex> update_avatar(avatar, %{field: new_value})
      {:ok, %Avatar{}}

      iex> update_avatar(avatar, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_avatar(%Avatar{} = avatar, attrs) do
    avatar
    |> Avatar.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a avatar.

  ## Examples

      iex> delete_avatar(avatar)
      {:ok, %Avatar{}}

      iex> delete_avatar(avatar)
      {:error, %Ecto.Changeset{}}

  """
  def delete_avatar(%Avatar{} = avatar) do
    Repo.delete(avatar)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking avatar changes.

  ## Examples

      iex> change_avatar(avatar)
      %Ecto.Changeset{data: %Avatar{}}

  """
  def change_avatar(%Avatar{} = avatar, attrs \\ %{}) do
    Avatar.changeset(avatar, attrs)
  end
end
