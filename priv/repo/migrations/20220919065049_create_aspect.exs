defmodule Strangepaths.Repo.Migrations.CreateAspect do
  use Ecto.Migration

  def change do
    create table(:aspect) do
      add(:name, :string)
    end

    execute("INSERT INTO aspect (name) VALUES ('Fang')")
    execute("INSERT INTO aspect (name) VALUES ('Claw')")
    execute("INSERT INTO aspect (name) VALUES ('Scale')")
    execute("INSERT INTO aspect (name) VALUES ('Breath')")
    execute("INSERT INTO aspect (name) VALUES ('Star')")
    execute("INSERT INTO aspect (name) VALUES ('Void')")
    execute("INSERT INTO aspect (name) VALUES ('Mountain')")
    execute("INSERT INTO aspect (name) VALUES ('Island')")
    execute("INSERT INTO aspect (name) VALUES ('Red')")
    execute("INSERT INTO aspect (name) VALUES ('Blue')")
    execute("INSERT INTO aspect (name) VALUES ('Green')")
    execute("INSERT INTO aspect (name) VALUES ('White')")
    execute("INSERT INTO aspect (name) VALUES ('Black')")
    execute("INSERT INTO aspect (name) VALUES ('Status')")
  end
end
