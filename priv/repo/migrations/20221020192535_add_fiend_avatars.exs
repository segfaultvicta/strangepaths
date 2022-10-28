defmodule Strangepaths.Repo.Migrations.AddFiendAvatars do
  use Ecto.Migration

  def change do
    execute(
      "INSERT INTO avatars (owner_id, filepath, public) VALUES ('1', '/images/avatars/lithos.png', '1')"
    )

    execute(
      "INSERT INTO avatars (owner_id, filepath, public) VALUES ('1', '/images/avatars/orichalca.png', '1')"
    )

    execute(
      "INSERT INTO avatars (owner_id, filepath, public) VALUES ('1', '/images/avatars/papyrus.png', '1')"
    )

    execute(
      "INSERT INTO avatars (owner_id, filepath, public) VALUES ('1', '/images/avatars/vitriol.png', '1')"
    )

    execute(
      "INSERT INTO avatars (owner_id, filepath, public) VALUES ('1', '/images/avatars/lutum.png', '1')"
    )
  end
end
