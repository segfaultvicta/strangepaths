defmodule Strangepaths.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field(:email, :string)
    field(:password, :string, virtual: true, redact: true)
    field(:hashed_password, :string, redact: true)
    field(:confirmed_at, :naive_datetime)
    field(:nickname, :string)
    field(:role, Ecto.Enum, values: [:user, :dragon], default: :user)
    field(:public_ascension, :boolean, default: false)
    field(:arete, :integer, default: 0)
    field(:primary_red, :integer, default: 4)
    field(:primary_green, :integer, default: 4)
    field(:primary_blue, :integer, default: 4)
    field(:primary_white, :integer, default: 4)
    field(:primary_black, :integer, default: 4)
    field(:primary_void, :integer, default: 4)
    field(:alethic_red, :integer, default: 0)
    field(:alethic_green, :integer, default: 0)
    field(:alethic_blue, :integer, default: 0)
    field(:alethic_white, :integer, default: 0)
    field(:alethic_black, :integer, default: 0)
    field(:alethic_void, :integer, default: 0)
    field(:techne, {:array, :string}, default: [])
    field(:theme, :string, default: "dark")

    timestamps()
  end

  @doc """
  A user changeset for registration.

  It is important to validate the length of both email and password.
  Otherwise databases may truncate the email without warnings, which
  could lead to unpredictable or insecure behaviour. Long passwords may
  also be very expensive to hash for certain algorithms.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.
  """
  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email, :password, :nickname])
    |> validate_email()
    |> validate_password(opts)
  end

  @doc """
  A user changeset for registering admins. User, attrs, superadmin boolean
  """

  def admin_registration_changeset(user, attrs, true) do
    user
    |> registration_changeset(attrs)
    |> prepare_changes(&set_dragon_role/1)
  end

  defp set_dragon_role(changeset) do
    changeset
    |> put_change(:role, :dragon)
  end

  defp validate_email(changeset) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> unsafe_validate_unique(:email, Strangepaths.Repo)
    |> unique_constraint(:email)
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 6, max: 72)
    # |> validate_format(:password, ~r/[a-z]/, message: "at least one lower case character")
    # |> validate_format(:password, ~r/[A-Z]/, message: "at least one upper case character")
    # |> validate_format(:password, ~r/[!?@#$%^&*_0-9]/, message: "at least one digit or punctuation character")
    |> maybe_hash_password(opts)
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      # If using Bcrypt, then further validate it is at most 72 bytes long
      |> validate_length(:password, max: 72, count: :bytes)
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  @doc """
  A user changeset for changing the email.

  It requires the email to change otherwise an error is added.
  """
  def email_changeset(user, attrs) do
    user
    |> cast(attrs, [:email])
    |> validate_email()
    |> case do
      %{changes: %{email: _}} = changeset -> changeset
      %{} = changeset -> add_error(changeset, :email, "did not change")
    end
  end

  def nick_changeset(user, attrs) do
    user
    |> cast(attrs, [:nickname])
    |> case do
      %{changes: %{nickname: _}} = changeset -> changeset
      %{} = changeset -> add_error(changeset, :nickname, "did not change")
    end
  end

  def arete_changeset(user, attrs) do
    user
    |> cast(attrs, [:arete])
  end

  def ascension_changeset(user, attrs) do
    user
    |> cast(attrs, [:public_ascension])
  end

  def techne_changeset(user, attrs) do
    user
    |> cast(attrs, [:techne])
  end

  def theme_changeset(user, attrs) do
    user
    |> cast(attrs, [:theme])
    |> validate_inclusion(:theme, ["light", "dark"])
  end

  # Change user's primary and alethic die values
  def die_changeset(user, attrs) do
    user
    |> cast(attrs, [
      :primary_red,
      :primary_green,
      :primary_blue,
      :primary_white,
      :primary_black,
      :primary_void,
      :alethic_red,
      :alethic_green,
      :alethic_blue,
      :alethic_white,
      :alethic_black,
      :alethic_void
    ])
  end

  # set arete to 0, public_ascension to false, techne to [], primary dice to 4, alethic dice to 0
  def clear_changeset(user, attrs) do
    user
    |> cast(attrs, [
      :arete,
      :public_ascension,
      :techne,
      :primary_red,
      :primary_green,
      :primary_blue,
      :primary_white,
      :primary_black,
      :primary_void,
      :alethic_red,
      :alethic_green,
      :alethic_blue,
      :alethic_white,
      :alethic_black,
      :alethic_void
    ])
  end

  @doc """
  A user changeset for changing the password.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.
  """
  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
  end

  @doc """
  Confirms the account by setting `confirmed_at`.
  """
  def confirm_changeset(user) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    change(user, confirmed_at: now)
  end

  @doc """
  Verifies the password.

  If there is no user or the user doesn't have a password, we call
  `Bcrypt.no_user_verify/0` to avoid timing attacks.
  """
  def valid_password?(%Strangepaths.Accounts.User{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end

  @doc """
  Validates the current password otherwise adds an error to the changeset.
  """
  def validate_current_password(changeset, password) do
    if valid_password?(changeset.data, password) do
      changeset
    else
      add_error(changeset, :current_password, "is not valid")
    end
  end
end
