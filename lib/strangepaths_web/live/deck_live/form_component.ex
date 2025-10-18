defmodule StrangepathsWeb.DeckLive.FormComponent do
  use StrangepathsWeb, :live_component

  alias Strangepaths.Cards

  @impl true
  def update(%{deck: deck} = assigns, socket) do
    changeset = Cards.change_deck(deck)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("validate_new", %{"deck" => deck_params}, socket) do
    aspects = ["Fang", "Claw", "Scale", "Breath"]

    manabalance = %{
      red: String.to_integer(deck_params["red"]),
      green: String.to_integer(deck_params["green"]),
      blue: String.to_integer(deck_params["blue"]),
      white: String.to_integer(deck_params["white"]),
      black: String.to_integer(deck_params["black"])
    }

    manatotal =
      manabalance.red + manabalance.green + manabalance.blue + manabalance.white +
        manabalance.black

    changeset =
      %{socket.assigns.deck | manabalance: manabalance}
      |> Cards.change_new_deck(deck_params)
      |> Map.put(:action, :validate)

    {:noreply,
     assign(socket,
       deck: %{socket.assigns.deck | manabalance: manabalance},
       changeset: changeset,
       aspects: aspects,
       manatotal: manatotal
     )}
  end

  @impl true
  def handle_event("validate_edit", %{"deck" => deck_params}, socket) do
    changeset =
      socket.assigns.deck
      |> Cards.change_deck(deck_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", %{"deck" => deck_params}, socket) do
    save_deck(socket, socket.assigns.action, deck_params)
  end

  # defp save_deck(socket, :edit, deck_params) do
  #  case Cards.update_deck(socket.assigns.deck, deck_params) do
  #    {:ok, _deck} ->
  #      {:noreply,
  #       socket
  #       |> put_flash(:info, "Deck updated successfully")
  #       |> push_redirect(to: socket.assigns.return_to)}
  #
  #    {:error, %Ecto.Changeset{} = changeset} ->
  #      {:noreply, assign(socket, :changeset, changeset)}
  #  end
  # end

  defp save_deck(socket, :new, deck_params) do
    manabalance = %{
      red: String.to_integer(deck_params["red"]),
      green: String.to_integer(deck_params["green"]),
      blue: String.to_integer(deck_params["blue"]),
      white: String.to_integer(deck_params["white"]),
      black: String.to_integer(deck_params["black"])
    }

    IO.inspect(deck_params)

    case Cards.create_deck(Map.put(deck_params, "manabalance", manabalance)) do
      {:ok, _deck} ->
        {:noreply,
         socket
         |> put_flash(:info, "Deck created successfully")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end
end
