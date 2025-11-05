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
      red: 0,
      green: 0,
      blue: 0,
      white: 0,
      black: 0
    }

    changeset =
      %{socket.assigns.deck | manabalance: manabalance}
      |> Cards.change_new_deck(deck_params)
      |> Map.put(:action, :validate)

    {:noreply,
     assign(socket,
       deck: %{socket.assigns.deck | manabalance: manabalance},
       changeset: changeset,
       aspects: aspects
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

  defp save_deck(socket, :new, deck_params) do
    manabalance = %{
      red: 0,
      green: 0,
      blue: 0,
      white: 0,
      black: 0
    }

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
