defmodule Strangepaths.CardsTest do
  use Strangepaths.DataCase

  alias Strangepaths.Cards

  describe "cards" do
    alias Strangepaths.Cards.Card

    import Strangepaths.CardsFixtures

    @invalid_attrs %{img: nil, name: nil, principle: nil, rules: nil, type: nil}

    test "list_cards/0 returns all cards" do
      card = card_fixture()
      assert Cards.list_cards() == [card]
    end

    test "get_card!/1 returns the card with given id" do
      card = card_fixture()
      assert Cards.get_card!(card.id) == card
    end

    test "create_card/1 with valid data creates a card" do
      valid_attrs = %{img: "some img", name: "some name", principle: :Dragon, rules: "some rules", type: :Rite}

      assert {:ok, %Card{} = card} = Cards.create_card(valid_attrs)
      assert card.img == "some img"
      assert card.name == "some name"
      assert card.principle == :Dragon
      assert card.rules == "some rules"
      assert card.type == :Rite
    end

    test "create_card/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Cards.create_card(@invalid_attrs)
    end

    test "update_card/2 with valid data updates the card" do
      card = card_fixture()
      update_attrs = %{img: "some updated img", name: "some updated name", principle: :Stillness, rules: "some updated rules", type: :Grace}

      assert {:ok, %Card{} = card} = Cards.update_card(card, update_attrs)
      assert card.img == "some updated img"
      assert card.name == "some updated name"
      assert card.principle == :Stillness
      assert card.rules == "some updated rules"
      assert card.type == :Grace
    end

    test "update_card/2 with invalid data returns error changeset" do
      card = card_fixture()
      assert {:error, %Ecto.Changeset{}} = Cards.update_card(card, @invalid_attrs)
      assert card == Cards.get_card!(card.id)
    end

    test "delete_card/1 deletes the card" do
      card = card_fixture()
      assert {:ok, %Card{}} = Cards.delete_card(card)
      assert_raise Ecto.NoResultsError, fn -> Cards.get_card!(card.id) end
    end

    test "change_card/1 returns a card changeset" do
      card = card_fixture()
      assert %Ecto.Changeset{} = Cards.change_card(card)
    end
  end

  describe "decks" do
    alias Strangepaths.Cards.Deck

    import Strangepaths.CardsFixtures

    @invalid_attrs %{name: nil, principle: nil}

    test "list_decks/0 returns all decks" do
      deck = deck_fixture()
      assert Cards.list_decks() == [deck]
    end

    test "get_deck!/1 returns the deck with given id" do
      deck = deck_fixture()
      assert Cards.get_deck!(deck.id) == deck
    end

    test "create_deck/1 with valid data creates a deck" do
      valid_attrs = %{name: "some name", principle: :Dragon}

      assert {:ok, %Deck{} = deck} = Cards.create_deck(valid_attrs)
      assert deck.name == "some name"
      assert deck.principle == :Dragon
    end

    test "create_deck/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Cards.create_deck(@invalid_attrs)
    end

    test "update_deck/2 with valid data updates the deck" do
      deck = deck_fixture()
      update_attrs = %{name: "some updated name", principle: :Stillness}

      assert {:ok, %Deck{} = deck} = Cards.update_deck(deck, update_attrs)
      assert deck.name == "some updated name"
      assert deck.principle == :Stillness
    end

    test "update_deck/2 with invalid data returns error changeset" do
      deck = deck_fixture()
      assert {:error, %Ecto.Changeset{}} = Cards.update_deck(deck, @invalid_attrs)
      assert deck == Cards.get_deck!(deck.id)
    end

    test "delete_deck/1 deletes the deck" do
      deck = deck_fixture()
      assert {:ok, %Deck{}} = Cards.delete_deck(deck)
      assert_raise Ecto.NoResultsError, fn -> Cards.get_deck!(deck.id) end
    end

    test "change_deck/1 returns a deck changeset" do
      deck = deck_fixture()
      assert %Ecto.Changeset{} = Cards.change_deck(deck)
    end
  end
end
