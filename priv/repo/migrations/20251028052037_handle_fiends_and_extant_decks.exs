defmodule Strangepaths.Repo.Migrations.HandleFiendsAndExtantDecks do
  use Ecto.Migration

  def change do
    execute("update decks set avatar_id = 1")
  end
end
