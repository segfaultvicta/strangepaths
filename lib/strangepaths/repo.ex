defmodule Strangepaths.Repo do
  use Ecto.Repo,
    otp_app: :strangepaths,
    adapter: Ecto.Adapters.Postgres
end
