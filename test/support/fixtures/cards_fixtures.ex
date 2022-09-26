defmodule Strangepaths.CardsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Strangepaths.Cards` context.
  """

  @doc """
  Generate a card.
  """
  def card_fixture(attrs \\ %{}) do
    {:ok, card} =
      attrs
      |> Enum.into(%{
        img: "some img",
        name: "some name",
        principle: :Dragon,
        rules: "some rules",
        type: :Rite
      })
      |> Strangepaths.Cards.create_card()

    card
  end

  @doc """
  Generate a deck.
  """
  def deck_fixture(attrs \\ %{}) do
    {:ok, deck} =
      attrs
      |> Enum.into(%{
        name: "some name",
        principle: :Dragon
      })
      |> Strangepaths.Cards.create_deck()

    deck
  end
end
