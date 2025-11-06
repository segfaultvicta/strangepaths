defmodule Strangepaths.Cards.Aspect do
  use Ecto.Schema
  import Ecto.Changeset

  schema "aspect" do
    field(:name, :string)
    field(:parent_aspect_id, :id)
    field(:unlocked, :boolean, default: false)
    field(:description, :string)

    belongs_to(:parent_aspect, __MODULE__, foreign_key: :parent_aspect_id, define_field: false)
    has_many(:child_aspects, __MODULE__, foreign_key: :parent_aspect_id)
  end

  @doc false
  def changeset(aspect, attrs) do
    aspect
    |> cast(attrs, [:name, :parent_aspect_id, :unlocked, :description])
    |> validate_required([:name])
    |> validate_parent_aspect()
    |> validate_no_grandchildren()
    |> unique_constraint(:name)
  end

  # Validate that parent_aspect_id is one of the base aspects (1-4: Fang, Claw, Scale, Breath)
  defp validate_parent_aspect(changeset) do
    case get_field(changeset, :parent_aspect_id) do
      nil -> changeset
      parent_id when parent_id in [1, 2, 3, 4] -> changeset
      _ -> add_error(changeset, :parent_aspect_id, "must be one of the base aspects (Fang, Claw, Scale, or Breath)")
    end
  end

  # Validate that we're not creating a sub-aspect of a sub-aspect (only 2 levels deep)
  defp validate_no_grandchildren(changeset) do
    parent_id = get_field(changeset, :parent_aspect_id)

    if parent_id && parent_id not in [1, 2, 3, 4] do
      add_error(changeset, :parent_aspect_id, "cannot create sub-aspect of a sub-aspect (only 2 levels deep allowed)")
    else
      changeset
    end
  end
end
