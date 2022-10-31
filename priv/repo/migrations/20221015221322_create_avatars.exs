defmodule Strangepaths.Repo.Migrations.CreateAvatars do
  use Ecto.Migration

  def change do
    create table(:avatars) do
      add(:filepath, :string)
      add(:public, :boolean, default: false, null: false)
      add(:owner_id, references(:users, on_delete: :nothing))
    end

    create(index(:avatars, [:owner_id]))

    Strangepaths.Accounts.register_god(%{
      email: "jon.c.cantwell@gmail.com",
      nickname: "Teakwood",
      password: "B4h4mUtz3r0",
      password_confirmation: "B4h4mUtz3r0"
    })

    execute(
      "INSERT INTO avatars (owner_id, filepath, public) VALUES ('1', '/images/avatars/abstract.png', '1')"
    )

    execute(
      "INSERT INTO avatars (owner_id, filepath, public) VALUES ('1', '/images/avatars/dragon.png', '1')"
    )

    execute(
      "INSERT INTO avatars (owner_id, filepath, public) VALUES ('1', '/images/avatars/eye.png', '1')"
    )

    execute(
      "INSERT INTO avatars (owner_id, filepath, public) VALUES ('1', '/images/avatars/eye2.png', '1')"
    )

    execute(
      "INSERT INTO avatars (owner_id, filepath, public) VALUES ('1', '/images/avatars/fire.png', '1')"
    )

    execute(
      "INSERT INTO avatars (owner_id, filepath, public) VALUES ('1', '/images/avatars/fire2.png', '1')"
    )

    execute(
      "INSERT INTO avatars (owner_id, filepath, public) VALUES ('1', '/images/avatars/flower.png', '1')"
    )

    execute(
      "INSERT INTO avatars (owner_id, filepath, public) VALUES ('1', '/images/avatars/flower2.png', '1')"
    )

    execute(
      "INSERT INTO avatars (owner_id, filepath, public) VALUES ('1', '/images/avatars/flower3.png', '1')"
    )

    execute(
      "INSERT INTO avatars (owner_id, filepath, public) VALUES ('1', '/images/avatars/flower4.png', '1')"
    )

    execute(
      "INSERT INTO avatars (owner_id, filepath, public) VALUES ('1', '/images/avatars/geometric.png', '1')"
    )

    execute(
      "INSERT INTO avatars (owner_id, filepath, public) VALUES ('1', '/images/avatars/geometric2.png', '1')"
    )

    execute(
      "INSERT INTO avatars (owner_id, filepath, public) VALUES ('1', '/images/avatars/geometric3.png', '1')"
    )

    execute(
      "INSERT INTO avatars (owner_id, filepath, public) VALUES ('1', '/images/avatars/geometric4.png', '1')"
    )

    execute(
      "INSERT INTO avatars (owner_id, filepath, public) VALUES ('1', '/images/avatars/geometric5.png', '1')"
    )

    execute(
      "INSERT INTO avatars (owner_id, filepath, public) VALUES ('1', '/images/avatars/monster.png', '1')"
    )

    execute(
      "INSERT INTO avatars (owner_id, filepath, public) VALUES ('1', '/images/avatars/mountains.png', '1')"
    )

    execute(
      "INSERT INTO avatars (owner_id, filepath, public) VALUES ('1', '/images/avatars/mountains2.png', '1')"
    )

    execute(
      "INSERT INTO avatars (owner_id, filepath, public) VALUES ('1', '/images/avatars/rainbows.png', '1')"
    )

    execute(
      "INSERT INTO avatars (owner_id, filepath, public) VALUES ('1', '/images/avatars/rainbows2.png', '1')"
    )

    execute(
      "INSERT INTO avatars (owner_id, filepath, public) VALUES ('1', '/images/avatars/rainbows3.png', '1')"
    )

    execute(
      "INSERT INTO avatars (owner_id, filepath, public) VALUES ('1', '/images/avatars/seamonster.png', '1')"
    )

    execute(
      "INSERT INTO avatars (owner_id, filepath, public) VALUES ('1', '/images/avatars/stars.png', '1')"
    )

    execute(
      "INSERT INTO avatars (owner_id, filepath, public) VALUES ('1', '/images/avatars/stars2.png', '1')"
    )

    execute(
      "INSERT INTO avatars (owner_id, filepath, public) VALUES ('1', '/images/avatars/stars3.png', '1')"
    )

    execute(
      "INSERT INTO avatars (owner_id, filepath, public) VALUES ('1', '/images/avatars/stars4.png', '1')"
    )

    execute(
      "INSERT INTO avatars (owner_id, filepath, public) VALUES ('1', '/images/avatars/the Beating Heart.png', '1')"
    )

    execute(
      "INSERT INTO avatars (owner_id, filepath, public) VALUES ('1', '/images/avatars/the Dreaming Serpent.png', '1')"
    )

    execute(
      "INSERT INTO avatars (owner_id, filepath, public) VALUES ('1', '/images/avatars/the Duelists Mask.png', '1')"
    )

    execute(
      "INSERT INTO avatars (owner_id, filepath, public) VALUES ('1', '/images/avatars/the Empty Space.png', '1')"
    )

    execute(
      "INSERT INTO avatars (owner_id, filepath, public) VALUES ('1', '/images/avatars/the Fallen Leaf.png', '1')"
    )

    execute(
      "INSERT INTO avatars (owner_id, filepath, public) VALUES ('1', '/images/avatars/the Fiend-Engine.png', '1')"
    )

    execute(
      "INSERT INTO avatars (owner_id, filepath, public) VALUES ('1', '/images/avatars/the Golden Lion.png', '1')"
    )

    execute(
      "INSERT INTO avatars (owner_id, filepath, public) VALUES ('1', '/images/avatars/the Hollow Skull.png', '1')"
    )

    execute(
      "INSERT INTO avatars (owner_id, filepath, public) VALUES ('1', '/images/avatars/the Key-and-Gate.png', '1')"
    )

    execute(
      "INSERT INTO avatars (owner_id, filepath, public) VALUES ('1', '/images/avatars/the Lantern-and-Eye.png', '1')"
    )

    execute(
      "INSERT INTO avatars (owner_id, filepath, public) VALUES ('1', '/images/avatars/the Soldier-and-Brother.png', '1')"
    )

    execute(
      "INSERT INTO avatars (owner_id, filepath, public) VALUES ('1', '/images/avatars/the Stillness and the Song.png', '1')"
    )

    execute(
      "INSERT INTO avatars (owner_id, filepath, public) VALUES ('1', '/images/avatars/the Sundered Wolf.png', '1')"
    )

    execute(
      "INSERT INTO avatars (owner_id, filepath, public) VALUES ('1', '/images/avatars/the Unburnt Book.png', '1')"
    )

    execute(
      "INSERT INTO avatars (owner_id, filepath, public) VALUES ('1', '/images/avatars/trees.png', '1')"
    )

    execute(
      "INSERT INTO avatars (owner_id, filepath, public) VALUES ('1', '/images/avatars/trees2.png', '1')"
    )

    execute(
      "INSERT INTO avatars (owner_id, filepath, public) VALUES ('1', '/images/avatars/waves.png', '1')"
    )
  end
end
