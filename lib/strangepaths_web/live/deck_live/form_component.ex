defmodule StrangepathsWeb.DeckLive.FormComponent do
  use StrangepathsWeb, :live_component

  alias Strangepaths.Cards

  @impl true
  def update(%{deck: deck} = assigns, socket) do
    changeset = Cards.change_deck(deck)

    # Get user role to determine which aspects to show
    user_role = if assigns[:current_user], do: assigns.current_user.role, else: :user
    aspects = Cards.list_aspects_for_deck_creation(user_role)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)
     |> assign(:aspects, aspects)
     |> assign(:user_role, user_role)}
  end

  @impl true
  def handle_event("validate_new", %{"deck" => deck_params}, socket) do
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
       changeset: changeset
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

  # Helper function to format aspect options for select dropdown
  # For dragons: shows hierarchy with indentation
  # For users: just shows base aspects
  defp aspect_options_for_select(aspects, :dragon) do
    # Group by parent
    grouped = Enum.group_by(aspects, fn a -> a.parent_aspect_id end)
    base_aspects = grouped[nil] || []

    Enum.flat_map(base_aspects, fn parent ->
      parent_option = [{parent.name, parent.id}]

      child_options =
        (grouped[parent.id] || [])
        |> Enum.map(fn child ->
          {"  └─ #{child.name}", child.id}
        end)

      parent_option ++ child_options
    end)
  end

  defp aspect_options_for_select(aspects, _user_role) do
    Enum.map(aspects, fn aspect -> {aspect.name, aspect.id} end)
  end
end
