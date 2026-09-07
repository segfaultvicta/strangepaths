defmodule StrangepathsWeb.CardLive.FormComponent do
  use StrangepathsWeb, :live_component

  alias Strangepaths.Cards

  @impl true
  def update(%{card: card} = assigns, socket) do
    changeset = Cards.change_card(card)

    # Only dragons create cards, so show all aspects without filtering
    aspects_hierarchy = Cards.list_aspects_with_hierarchy()
    sidereal_aspects = Cards.list_sidereal_aspects()

    sub_aspect_ids =
      aspects_hierarchy
      |> Enum.flat_map(fn %{children: children} -> Enum.map(children, & &1.id) end)
      |> MapSet.new()

    is_sub_aspect = not is_nil(card.aspect_id) && MapSet.member?(sub_aspect_ids, card.aspect_id)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)
     |> assign(:aspects_hierarchy, aspects_hierarchy)
     |> assign(:sidereal_aspects, sidereal_aspects)
     |> assign(:sub_aspect_ids, sub_aspect_ids)
     |> assign(:is_sub_aspect, is_sub_aspect)
     |> allow_upload(:cardart, accept: ~w(.png .jpg .jpeg), max_entries: 1)}
  end

  @impl true
  def handle_event("validate", %{"card" => card_params}, socket) do
    # Rebuild the changeset from the submitted params so every field has a
    # server-side value. Without this the form's contents live only in the
    # browser DOM, and any re-render that re-patches the inputs (notably
    # selecting a file for the card-art upload, which re-renders the form to
    # show the chosen filename) wipes everything back to the blank changeset.
    changeset = Cards.change_card(socket.assigns.card, card_params)

    is_sub =
      case Integer.parse(card_params["aspect_id"] || "") do
        {id, ""} -> MapSet.member?(socket.assigns.sub_aspect_ids, id)
        _ -> false
      end

    {:noreply,
     socket
     |> assign(:changeset, changeset)
     |> assign(:is_sub_aspect, is_sub)}
  end

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel_cardart", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :cardart, ref)}
  end

  @impl true
  def handle_event("save", %{"card" => card_params}, socket) do
    save_card(socket, socket.assigns.action, card_params)
  end

  defp save_card(socket, :edit, card_params) do
    # Handle cardart upload if present
    card_params = handle_cardart_upload(socket, card_params)

    case Cards.update_card(socket.assigns.card, card_params) do
      {:ok, _card} ->
        {:noreply,
         socket
         |> put_flash(:info, "Card updated successfully")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp save_card(socket, :new, card_params) do
    # Handle cardart upload if present
    card_params = handle_cardart_upload(socket, card_params)

    case Cards.create_card(card_params) do
      {:ok, _card} ->
        {:noreply,
         socket
         |> put_flash(:info, "Card created successfully")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  defp handle_cardart_upload(socket, card_params) do
    cardart_paths =
      consume_uploaded_entries(socket, :cardart, fn %{path: path}, entry ->
        # Generate unique filename based on card name and timestamp
        filename =
          "#{card_params["name"]}_#{System.system_time(:second)}#{Path.extname(entry.client_name)}"

        dest =
          Path.join([
            :code.priv_dir(:strangepaths),
            "static",
            "uploads",
            filename
          ])

        File.cp!(path, dest)
        {:ok, Routes.static_path(socket, "/uploads/#{filename}")}
      end)

    if length(cardart_paths) > 0 do
      Map.put(card_params, "cardart", List.first(cardart_paths))
    else
      card_params
    end
  end

  def friendly_error(:too_large), do: "Image too large"
  def friendly_error(:too_many_files), do: "Too many files"
  def friendly_error(:not_accepted), do: "Unacceptable file type"
end
