defmodule StrangepathsWeb.CardLive.Index do
  use StrangepathsWeb, :live_view

  import StrangepathsWeb.MusicBroadcast

  alias Strangepaths.Cards
  alias Strangepaths.Cards.Card
  alias Strangepaths.Cards.Aspect

  @impl true
  def mount(_params, session, socket) do
    socket = assign_defaults(session, socket)

    # Subscribe to music broadcasts
    subscribe_to_music(socket)

    user_role = if socket.assigns.current_user, do: socket.assigns.current_user.role, else: nil

    {:ok,
     assign(socket,
       cards: nil,
       # Search and filter state
       search_query: "",
       filter_aspect_id: nil,
       filter_show_glorified: false,
       show_filters: false,
       # Aspect management state
       aspects_hierarchy: Cards.list_aspects_with_hierarchy(),
       show_aspect_form: false,
       aspect_form: %{
         "name" => "",
         "parent_aspect_id" => "1",
         "description" => "",
         "unlocked" => false
       },
       editing_aspect: nil,
       user_role: user_role
     )}
  end

  @impl true
  def handle_event(event, params, socket) do
    # Try forwarding music client events first
    case forward_music_client_event(event, params, socket) do
      :not_music_event ->
        # Handle our own events
        handle_card_event(event, params, socket)

      result ->
        result
    end
  end

  # Card management events
  defp handle_card_event("delete", %{"id" => id}, socket) do
    card = Cards.get_card!(id)
    {:ok, _} = Cards.delete_card(card)

    {:noreply, reload_cards(socket)}
  end

  # Search and filter events
  defp handle_card_event("search", %{"search_query" => query}, socket) do
    {:noreply,
     socket
     |> assign(:search_query, query)
     |> reload_cards()}
  end

  defp handle_card_event("toggle_filters", _params, socket) do
    {:noreply, assign(socket, :show_filters, !socket.assigns.show_filters)}
  end

  defp handle_card_event("change_aspect_filter", %{"aspect_id" => aspect_id}, socket) do
    aspect_id =
      if aspect_id == "" || aspect_id == "all", do: nil, else: String.to_integer(aspect_id)

    {:noreply,
     socket
     |> assign(:filter_aspect_id, aspect_id)
     |> reload_cards()}
  end

  defp handle_card_event("toggle_glorified_filter", _params, socket) do
    {:noreply,
     socket
     |> assign(:filter_show_glorified, !socket.assigns.filter_show_glorified)
     |> reload_cards()}
  end

  defp handle_card_event("clear_filters", _params, socket) do
    {:noreply,
     socket
     |> assign(:search_query, "")
     |> assign(:filter_aspect_id, nil)
     |> assign(:filter_show_glorified, true)
     |> reload_cards()}
  end

  # Aspect management events (dragon only)
  defp handle_card_event("toggle_aspect_form", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_aspect_form, !socket.assigns.show_aspect_form)
     |> assign(:editing_aspect, nil)
     |> assign(:aspect_form, %{
       "name" => "",
       "parent_aspect_id" => "1",
       "description" => "",
       "unlocked" => false
     })}
  end

  defp handle_card_event("create_aspect", %{"aspect" => aspect_params}, socket) do
    # Convert string IDs to integers
    params =
      Map.update(aspect_params, "parent_aspect_id", nil, fn v ->
        if v && v != "", do: String.to_integer(v), else: nil
      end)

    params = Map.update(params, "unlocked", false, fn v -> v == "true" || v == true end)

    case Cards.create_aspect(params) do
      {:ok, _aspect} ->
        {:noreply,
         socket
         |> assign(:show_aspect_form, false)
         |> assign(:aspects_hierarchy, Cards.list_aspects_with_hierarchy())
         |> put_flash(:info, "Aspect created successfully")
         |> reload_cards()}

      {:error, changeset} ->
        errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)

        error_msg =
          errors |> Enum.map(fn {k, v} -> "#{k}: #{Enum.join(v, ", ")}" end) |> Enum.join("; ")

        {:noreply, put_flash(socket, :error, "Error creating aspect: #{error_msg}")}
    end
  end

  defp handle_card_event("edit_aspect", %{"aspect-id" => aspect_id_str}, socket) do
    aspect_id = String.to_integer(aspect_id_str)
    aspect = Cards.get_aspect_with_parent(aspect_id)

    {:noreply,
     socket
     |> assign(:editing_aspect, aspect)
     |> assign(:show_aspect_form, true)
     |> assign(:aspect_form, %{
       "name" => aspect.name,
       "parent_aspect_id" => to_string(aspect.parent_aspect_id || ""),
       "description" => aspect.description || "",
       "unlocked" => aspect.unlocked
     })}
  end

  defp handle_card_event(
         "update_aspect",
         %{"aspect" => aspect_params, "aspect-id" => aspect_id_str},
         socket
       ) do
    aspect_id = String.to_integer(aspect_id_str)
    aspect = Strangepaths.Repo.get!(Aspect, aspect_id)

    # Only allow updating name and description, not parent or unlocked status
    params = Map.take(aspect_params, ["name", "description"])

    case Cards.update_aspect(aspect, params) do
      {:ok, _aspect} ->
        {:noreply,
         socket
         |> assign(:show_aspect_form, false)
         |> assign(:editing_aspect, nil)
         |> assign(:aspects_hierarchy, Cards.list_aspects_with_hierarchy())
         |> put_flash(:info, "Aspect updated successfully")
         |> reload_cards()}

      {:error, changeset} ->
        errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)

        error_msg =
          errors |> Enum.map(fn {k, v} -> "#{k}: #{Enum.join(v, ", ")}" end) |> Enum.join("; ")

        {:noreply, put_flash(socket, :error, "Error updating aspect: #{error_msg}")}
    end
  end

  defp handle_card_event("toggle_aspect_lock", %{"aspect-id" => aspect_id_str}, socket) do
    aspect_id = String.to_integer(aspect_id_str)
    aspect = Strangepaths.Repo.get!(Aspect, aspect_id)

    case Cards.toggle_aspect_lock(aspect) do
      {:ok, _aspect} ->
        {:noreply,
         socket
         |> assign(:aspects_hierarchy, Cards.list_aspects_with_hierarchy())
         |> put_flash(:info, "Aspect lock toggled")
         |> reload_cards()}

      {:error, message} when is_binary(message) ->
        {:noreply, put_flash(socket, :error, message)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Error toggling aspect lock")}
    end
  end

  defp handle_card_event("delete_aspect", %{"aspect-id" => aspect_id_str}, socket) do
    aspect_id = String.to_integer(aspect_id_str)
    aspect = Strangepaths.Repo.get!(Aspect, aspect_id)

    case Cards.delete_aspect(aspect) do
      {:ok, _aspect} ->
        {:noreply,
         socket
         |> assign(:aspects_hierarchy, Cards.list_aspects_with_hierarchy())
         |> put_flash(:info, "Aspect deleted")
         |> reload_cards()}

      {:error, message} when is_binary(message) ->
        {:noreply, put_flash(socket, :error, message)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Error deleting aspect")}
    end
  end

  # Card lock/unlock events (dragon only, for Alethic cards)
  defp handle_card_event("toggle_card_lock", %{"card-id" => card_id_str}, socket) do
    card_id = String.to_integer(card_id_str)
    card = Cards.get_card!(card_id)

    case Cards.toggle_card_lock(card) do
      {:ok, _card} ->
        {:noreply,
         socket
         |> put_flash(:info, "Card lock toggled")
         |> reload_cards()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Error toggling card lock")}
    end
  end

  # Helper to reload cards with current filters
  defp reload_cards(socket) do
    cards =
      Cards.search_and_filter_cards(
        socket.assigns.search_query,
        socket.assigns.filter_aspect_id,
        socket.assigns.filter_show_glorified,
        socket.assigns.user_role
      )

    assign(socket, :cards, cards)
  end

  @impl true
  def handle_info(msg, socket) do
    # Forward music broadcasts to the component
    case forward_music_event(msg, socket) do
      :not_music_event ->
        # Handle other non-music events here if needed
        {:noreply, socket}

      result ->
        result
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Card")
    |> assign(:card, Cards.get_card!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Card")
    |> assign(:card, %Card{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "the Dragon's Cosmos")
    |> reload_cards()
  end
end
