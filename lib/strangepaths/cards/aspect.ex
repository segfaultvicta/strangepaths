defmodule Strangepaths.Cards.Aspect do
  use Ecto.Schema
  import Ecto.Changeset

  schema "aspect" do
    field(:name, :string)
  end

  @doc false
  def changeset(aspect, attrs) do
    aspect
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end
end
