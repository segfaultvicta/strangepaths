defmodule Strangepaths.Site.WorldState do
  use Ecto.Schema

  schema "world_state" do
    field :devour_count, :integer, default: 0
  end
end
