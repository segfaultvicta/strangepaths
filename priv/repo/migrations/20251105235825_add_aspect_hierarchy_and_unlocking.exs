defmodule Strangepaths.Repo.Migrations.AddAspectHierarchyAndUnlocking do
  use Ecto.Migration

  def up do
    # Add new columns to aspect table
    alter table(:aspect) do
      add :parent_aspect_id, references(:aspect, on_delete: :restrict), null: true
      add :unlocked, :boolean, default: false, null: false
      add :description, :text, null: true
    end

    # Create index for parent_aspect_id lookups
    create index(:aspect, [:parent_aspect_id])

    # Delete unused aspects: Star (5), Void (6), Mountain (7), Island (8)
    execute("DELETE FROM aspect WHERE id IN (5, 6, 7, 8)")

    # Set base aspects and sidereal colors as unlocked
    execute("""
    UPDATE aspect
    SET unlocked = true
    WHERE id IN (1, 2, 3, 4, 9, 10, 11, 12, 13, 14, 15)
    """)

    # Add descriptions for base aspects
    execute("""
    UPDATE aspect
    SET description = 'The aspect of primal aggression, teeth and claws tearing through flesh.'
    WHERE id = 1
    """)

    execute("""
    UPDATE aspect
    SET description = 'The aspect of swift strikes, razor-sharp talons rending armor.'
    WHERE id = 2
    """)

    execute("""
    UPDATE aspect
    SET description = 'The aspect of impenetrable defense, scales harder than steel.'
    WHERE id = 3
    """)

    execute("""
    UPDATE aspect
    SET description = 'The aspect of elemental fury, fire and ice and lightning.'
    WHERE id = 4
    """)

    # Add descriptions for sidereal colors
    execute("""
    UPDATE aspect
    SET description = 'Burning mana, the power of flame and fury.'
    WHERE id = 9
    """)

    execute("""
    UPDATE aspect
    SET description = 'Pellucid mana, the power of water and thought.'
    WHERE id = 10
    """)

    execute("""
    UPDATE aspect
    SET description = 'Flourishing mana, the power of growth and life.'
    WHERE id = 11
    """)

    execute("""
    UPDATE aspect
    SET description = 'Radiant mana, the power of light and order.'
    WHERE id = 12
    """)

    execute("""
    UPDATE aspect
    SET description = 'Tenebrous mana, the power of shadow and death.'
    WHERE id = 13
    """)

    # Add descriptions for special aspects
    execute("""
    UPDATE aspect
    SET description = 'Status effects and conditions.'
    WHERE id = 14
    """)

    execute("""
    UPDATE aspect
    SET description = 'Secret truths hidden behind the veil of knowledge.'
    WHERE id = 15
    """)
  end

  def down do
    # Re-insert deleted aspects
    execute("""
    INSERT INTO aspect (id, name, unlocked) VALUES
    (5, 'Star', false),
    (6, 'Void', false),
    (7, 'Mountain', false),
    (8, 'Island', false)
    """)

    # Drop index
    drop index(:aspect, [:parent_aspect_id])

    # Remove columns
    alter table(:aspect) do
      remove :parent_aspect_id
      remove :unlocked
      remove :description
    end
  end
end
